import { ethers } from 'ethers';
import { bn, bootstrapMarkets } from '../../integration/bootstrap';
import { depositCollateral, openPosition, getQuantoPositionSize } from '../../integration/helpers';
import { SynthMarkets } from '@synthetixio/spot-market/test/common';
import assertBn from '@synthetixio/core-utils/utils/assertions/assert-bignumber';
import assertEvent from '@synthetixio/core-utils/utils/assertions/assert-event';

describe('Keeper Rewards - Multiple Collaterals', () => {
  // Account and Market Identifiers
  const accountIds = [2, 3];
  const linkMarketId = 30;
  const quantoSynthMarketIndex = 0;

  // Market Prices
  const btcPrice = bn(10_000);
  const ethPrice = bn(1_000);
  const linkPrice = bn(5_000);

  // Skew Scales
  const ethSkewScale = bn(100_000);
  const linkSkewScale = bn(200_000);

  // Margin and Funding Parameters
  const ethMaxFundingVelocity = bn(10);
  const linkMaxFundingVelocity = bn(20);

  const KeeperCosts = {
    settlementCost: 1111,
    flagCost: 3333,
    liquidateCost: 5555,
  };
  const {
    systems,
    perpsMarkets,
    synthMarkets,
    provider,
    trader1,
    keeperCostOracleNode,
    keeper,
    owner,
  } = bootstrapMarkets({
    synthMarkets: [
      {
        name: 'Bitcoin',
        token: 'snxBTC',
        buyPrice: btcPrice,
        sellPrice: btcPrice,
      },
      {
        name: 'Ethereum',
        token: 'snxETH',
        buyPrice: ethPrice,
        sellPrice: ethPrice,
      },
    ],
    perpsMarkets: [
      {
        requestedMarketId: 25,
        name: 'Ether',
        token: 'snxETH',
        price: ethPrice,
        fundingParams: { skewScale: ethSkewScale, maxFundingVelocity: ethMaxFundingVelocity },
        quanto: {
          name: 'Bitcoin',
          token: 'BTC',
          price: btcPrice,
          quantoSynthMarketIndex: quantoSynthMarketIndex,
        },
      },
      {
        requestedMarketId: linkMarketId,
        name: 'Link',
        token: 'snxLINK',
        price: linkPrice,
        fundingParams: { skewScale: linkSkewScale, maxFundingVelocity: linkMaxFundingVelocity },
      },
    ],
    traderAccountIds: accountIds,
  });
  let ethMarketId: ethers.BigNumber;
  let ethSettlementStrategyId: ethers.BigNumber;
  let btcSynth: SynthMarkets[number];
  let ethSynth: SynthMarkets[number];
  let liquidateTxn: ethers.providers.TransactionResponse;

  before('identify actors', async () => {
    ethMarketId = perpsMarkets()[0].marketId();
    ethSettlementStrategyId = perpsMarkets()[0].strategyId();
    btcSynth = synthMarkets()[0];
    ethSynth = synthMarkets()[1];
  });

  const collateralsTestCase = [
    {
      name: 'multiple collaterals',
      collateralData: {
        systems,
        trader: trader1,
        accountId: () => 2,
        collaterals: [
          {
            snxUSDAmount: () => bn(10_000),
          },
          {
            synthMarket: () => btcSynth,
            snxUSDAmount: () => bn(1_000),
          },
          {
            synthMarket: () => ethSynth,
            snxUSDAmount: () => bn(1_000),
          },
        ],
      },
    },
  ];

  before('set keeper costs', async () => {
    await keeperCostOracleNode()
      .connect(owner())
      .setCosts(KeeperCosts.settlementCost, KeeperCosts.flagCost, KeeperCosts.liquidateCost);
  });

  before('set minLiquidationRewardUsd, maxLiquidationRewardUsd - uncapped', async () => {
    await systems().PerpsMarket.setKeeperRewardGuards(1, 0, bn(10), bn(0.005));
  });

  before('set liquidation reward ratio', async () => {
    const initialMarginFraction = bn(0);
    const maintenanceMarginScalar = bn(0);
    const minimumInitialMarginRatio = bn(0);
    const liquidationRewardRatio = bn(0.05); // 100 * 0.05 = 5
    const minimumPositionMargin = bn(0);
    await systems()
      .PerpsMarket.connect(owner())
      .setLiquidationParameters(
        ethMarketId,
        initialMarginFraction,
        maintenanceMarginScalar,
        minimumInitialMarginRatio,
        liquidationRewardRatio,
        minimumPositionMargin
      );
  });

  before('add collateral', async () => {
    await depositCollateral(collateralsTestCase[0].collateralData);
  });

  before('open position', async () => {
    const quantoPositionSize = getQuantoPositionSize({
      sizeInBaseAsset: bn(100),
      quantoAssetPrice: btcPrice,
    });
    await openPosition({
      systems,
      provider,
      trader: trader1(),
      accountId: 2,
      keeper: keeper(),
      marketId: ethMarketId,
      sizeDelta: quantoPositionSize,
      settlementStrategyId: ethSettlementStrategyId,
      price: ethPrice,
    });
  });

  before('lower price to liquidation', async () => {
    await perpsMarkets()[0].aggregator().mockSetCurrentPrice(bn(1));
  });

  let initialKeeperBalance: ethers.BigNumber;
  before('call liquidate', async () => {
    initialKeeperBalance = await systems().USD.balanceOf(await keeper().getAddress());
  });

  before('liquidate account', async () => {
    liquidateTxn = await systems().PerpsMarket.connect(keeper()).liquidate(2);
  });

  it('emits position liquidated event', async () => {
    await assertEvent(
      liquidateTxn,
      `PositionLiquidated(2, 25, ${bn(0.01)}, 0)`,
      systems().PerpsMarket
    );
  });

  it('emits account liquidated event', async () => {
    // 1 position, snxUSD collateral + 2 synth collateral
    const expected = bn(5).add(KeeperCosts.flagCost * 3 + KeeperCosts.liquidateCost);

    await assertEvent(
      liquidateTxn,
      `AccountLiquidationAttempt(2, ${expected}, true)`, // not capped
      systems().PerpsMarket
    );
  });

  it('keeper gets paid', async () => {
    const keeperBalance = await systems().USD.balanceOf(await keeper().getAddress());
    const expected = bn(5).add(KeeperCosts.flagCost * 3 + KeeperCosts.liquidateCost);
    assertBn.equal(keeperBalance, initialKeeperBalance.add(expected));
  });
});
