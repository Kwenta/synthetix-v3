import { PerpsMarket, bn, bootstrapMarkets } from '../../integration/bootstrap';
import {
  calculateInterestRate,
  openPosition,
  getQuantoPositionSize,
  ONE_ETHER
} from '../../integration/helpers';
import Wei, { wei } from '@synthetixio/wei';
import { ethers } from 'ethers';
import { fastForwardTo, getTime } from '@synthetixio/core-utils/utils/hardhat/rpc';
import assertBn from '@synthetixio/core-utils/utils/assertions/assert-bignumber';
import assertEvent from '@synthetixio/core-utils/utils/assertions/assert-event';
import { stake } from '@synthetixio/main/test/common';

const _SECONDS_IN_DAY = 24 * 60 * 60;
const _SECONDS_IN_YEAR = 31557600;

const _ETH_PRICE = wei(2000);
const _BTC_PRICE = wei(30_000);
const _ETH_LOCKED_OI_RATIO = wei(1);
const _BTC_LOCKED_OI_RATIO = wei(0.5);

const _TRADER_SIZE = wei(
  getQuantoPositionSize({
    sizeInBaseAsset: bn(20),
    quantoAssetPrice: _ETH_PRICE.toBN(),
  })
);

const _TRADER1_LOCKED_OI = _TRADER_SIZE.mul(_ETH_PRICE).mul(_ETH_LOCKED_OI_RATIO);

const interestRateParams = {
  lowUtilGradient: wei(0.0003),
  gradientBreakpoint: wei(0.75),
  highUtilGradient: wei(0.01),
};

const proportionalTime = (seconds: number) => wei(seconds).div(_SECONDS_IN_YEAR);

const TOLERANCE = bn(0.0001);

describe('Position - interest rates', () => {
  const traderAccountIds = [2, 3];
  const trader1AccountId = traderAccountIds[0];
  const trader2AccountId = traderAccountIds[1];

  const {
    systems,
    perpsMarkets,
    synthMarkets,
    superMarketId,
    provider,
    trader1,
    trader2,
    trader3,
    keeper,
    staker,
    poolId,
  } = bootstrapMarkets({
    interestRateParams: {
      lowUtilGradient: interestRateParams.lowUtilGradient.toBN(),
      gradientBreakpoint: interestRateParams.gradientBreakpoint.toBN(),
      highUtilGradient: interestRateParams.highUtilGradient.toBN(),
    },
    synthMarkets: [
      {
        name: 'Ether',
        token: 'sETH',
        buyPrice: _ETH_PRICE.toBN(),
        sellPrice: _ETH_PRICE.toBN(),
      },
    ],
    perpsMarkets: [
      {
        lockedOiRatioD18: _ETH_LOCKED_OI_RATIO.toBN(),
        requestedMarketId: 25,
        name: 'Ether',
        token: 'snxETH',
        price: _ETH_PRICE.toBN(),
        quanto: {
          name: 'Ether',
          token: 'ETH',
          price: _ETH_PRICE.toBN(),
          quantoSynthMarketIndex: 0,
        },
      },
      {
        lockedOiRatioD18: _BTC_LOCKED_OI_RATIO.toBN(),
        requestedMarketId: 50,
        name: 'Bitcoin',
        token: 'snxBTC',
        price: _BTC_PRICE.toBN(),
        quanto: {
          name: 'Ether',
          token: 'ETH',
          price: _ETH_PRICE.toBN(),
          quantoSynthMarketIndex: 0,
        },
      },
    ],
    traderAccountIds
  });

  let ethMarket: PerpsMarket, btcMarket: PerpsMarket;

  // this is so that the creditCapacityD18 for the perps market is the same as in the non-quanto tests
  // as this test includes a synth market, the creditCapacityD18 is split between the two markets
  // halving the amount of credit available to the perps market, which effects the expected interest
  before('stake some extra collateral in the core pool', async () => {
    const delegateAmount = bn(1000);
    await stake(
      { Core: systems().Core, CollateralMock: systems().CollateralMock },
      poolId,
      trader1AccountId,
      trader3(),
      delegateAmount
    );
  });

  before('identify actors', async () => {
    ethMarket = perpsMarkets()[0];
    btcMarket = perpsMarkets()[1];
  });

  before('trader1 buys 25 sETH', async () => {
    const ethSpotMarketId = synthMarkets()[0].marketId();
    const usdAmount = bn(50_000);
    const minAmountReceived = bn(25);
    const referrer = ethers.constants.AddressZero;
    await systems()
      .SpotMarket.connect(trader1())
      .buy(ethSpotMarketId, usdAmount, minAmountReceived, referrer);
  });

  before('trader2 buys 100 sETH', async () => {
    const ethSpotMarketId = synthMarkets()[0].marketId();
    const usdAmount = bn(200_000);
    const minAmountReceived = bn(100);
    const referrer = ethers.constants.AddressZero;
    await systems()
      .SpotMarket.connect(trader2())
      .buy(ethSpotMarketId, usdAmount, minAmountReceived, referrer);
  });

  before('add collateral to margin', async () => {
    const ethSpotMarketId = synthMarkets()[0].marketId();
    await synthMarkets()[0]
      .synth()
      .connect(trader1())
      .approve(systems().PerpsMarket.address, ethers.constants.MaxUint256);
    await systems().PerpsMarket.connect(trader1()).modifyCollateral(trader1AccountId, ethSpotMarketId, bn(25));
    await synthMarkets()[0]
      .synth()
      .connect(trader2())
      .approve(systems().PerpsMarket.address, ethers.constants.MaxUint256);
    await systems().PerpsMarket.connect(trader2()).modifyCollateral(trader2AccountId, ethSpotMarketId, bn(100));
  });

  const checkMarketInterestRate = () => {
    let currentInterestRate: Wei;
    it('has correct interest rate', async () => {
      const withdrawableUsd = wei(await systems().Core.getWithdrawableMarketUsd(superMarketId()));
      const totalCollateralValue = wei(await systems().PerpsMarket.totalGlobalCollateralValue());
      const delegatedCollateral = withdrawableUsd.sub(totalCollateralValue);
      const minCredit = wei(await systems().PerpsMarket.minimumCredit(superMarketId()));

      const utilRate = minCredit.div(delegatedCollateral);
      currentInterestRate = calculateInterestRate(utilRate, interestRateParams);
      assertBn.near(
        await systems().PerpsMarket.interestRate(),
        currentInterestRate.toBN(),
        TOLERANCE
      );
      const { rate: expectedUtilizationRate } = await systems().PerpsMarket.utilizationRate();
      assertBn.near(expectedUtilizationRate, utilRate.toBN(), TOLERANCE);
    });

    return {
      currentInterestRate: () => currentInterestRate,
    };
  };

  let trader1OpenPositionTime: number, trader2OpenPositionTime: number;
  // trader 1
  before('open 20 eth position', async () => {
    ({ settleTime: trader1OpenPositionTime } = await openPosition({
      systems,
      provider,
      trader: trader1(),
      accountId: trader1AccountId,
      keeper: keeper(),
      marketId: ethMarket.marketId(),
      sizeDelta: _TRADER_SIZE.toBN(),
      settlementStrategyId: ethMarket.strategyId(),
      price: _ETH_PRICE.toBN(),
    }));
  });

  checkMarketInterestRate();

  let trader1InterestAccumulated: Wei = wei(0),
    lastTimeInterestAccrued: number;

  describe('a day passes by', () => {
    before('fast forward time', async () => {
      await fastForwardTo(trader1OpenPositionTime + _SECONDS_IN_DAY, provider());
    });

    describe('check trader 1 interest', () => {
      it('has correct interest rate', async () => {
        const { owedInterest } = await systems().PerpsMarket.getOpenPosition(
          trader1AccountId,
          ethMarket.marketId()
        );
        const expectedInterest = _TRADER1_LOCKED_OI
          .mul(wei(await systems().PerpsMarket.interestRate()))
          .mul(proportionalTime(_SECONDS_IN_DAY));
        trader1InterestAccumulated = trader1InterestAccumulated.add(owedInterest);
        lastTimeInterestAccrued = trader1OpenPositionTime + _SECONDS_IN_DAY;
        assertBn.near(owedInterest, expectedInterest.toBN(), TOLERANCE);
      });
    });
  });

  let newPositionSize = 0;
  [
    { size: -10, time: _SECONDS_IN_DAY },
    { size: 115, time: _SECONDS_IN_DAY },
    { size: -70, time: _SECONDS_IN_DAY * 0.25 },
    { size: -25, time: _SECONDS_IN_DAY * 2 },
    { size: 5, time: _SECONDS_IN_DAY * 0.1 },
  ].forEach(({ size, time }) => {
    describe('new trader enters', () => {
      let previousMarketInterestRate: Wei, settleTrader2Txn: ethers.ContractTransaction;
      before('identify interest rate', async () => {
        previousMarketInterestRate = wei(await systems().PerpsMarket.interestRate());
      });

      before('trader2 changes OI', async () => {
        newPositionSize += size / 2_000;
        ({ settleTime: trader2OpenPositionTime, settleTx: settleTrader2Txn } = await openPosition({
          systems,
          provider,
          trader: trader2(),
          accountId: 3,
          keeper: keeper(),
          marketId: btcMarket.marketId(),
          sizeDelta: getQuantoPositionSize({
            sizeInBaseAsset: bn(size),
            quantoAssetPrice: _ETH_PRICE.toBN(),
          }),
          settlementStrategyId: btcMarket.strategyId(),
          price: _BTC_PRICE.toBN(),
        }));

        await assertEvent(settleTrader2Txn, 'InterestCharged(3', systems().PerpsMarket);
      });

      before('accumulate trader 1 interest', async () => {
        const timeSinceLastAccrued = trader2OpenPositionTime - lastTimeInterestAccrued;
        // track interest accrued during new order
        const newInterestAccrued = _TRADER1_LOCKED_OI
          .mul(previousMarketInterestRate)
          .mul(proportionalTime(timeSinceLastAccrued));
        trader1InterestAccumulated = trader1InterestAccumulated.add(newInterestAccrued);
      });

      checkMarketInterestRate();
    });

    describe(`${time} seconds pass`, () => {
      let normalizedTime: Wei;
      before('fast forward time', async () => {
        await fastForwardTo(trader2OpenPositionTime + time, provider());

        const blockTime = await getTime(provider());
        lastTimeInterestAccrued = blockTime;
        normalizedTime = proportionalTime(blockTime - trader2OpenPositionTime);
      });

      it('accrued correct interest for trader 1', async () => {
        const { owedInterest } = await systems().PerpsMarket.getOpenPosition(
          trader1AccountId,
          ethMarket.marketId()
        );

        const newInterestAccrued = _TRADER1_LOCKED_OI
          .mul(wei(await systems().PerpsMarket.interestRate()))
          .mul(normalizedTime);
        trader1InterestAccumulated = trader1InterestAccumulated.add(newInterestAccrued);
        assertBn.near(owedInterest, trader1InterestAccumulated.toBN(), TOLERANCE);
      });

      it('accrued correct interest for trader 2', async () => {
        const { owedInterest } = await systems().PerpsMarket.getOpenPosition(
          trader2AccountId,
          btcMarket.marketId()
        );

        const trader2Oi = wei(Math.abs(newPositionSize)).mul(_BTC_PRICE).mul(_BTC_LOCKED_OI_RATIO);

        const expectedTrader2Interest = trader2Oi
          .mul(wei(await systems().PerpsMarket.interestRate()))
          .mul(normalizedTime);
        assertBn.near(owedInterest, expectedTrader2Interest.toBN(), TOLERANCE.div(10));
      });
    });
  });

  describe('change delegated collateral and manual update', () => {
    let previousMarketInterestRate: Wei, marketUpdateTime: number;
    before('identify interest rate', async () => {
      previousMarketInterestRate = wei(await systems().PerpsMarket.interestRate());
    });

    before('undelegate 10%', async () => {
      const currentCollateralAmount = await systems().Core.getPositionCollateral(
        1,
        1,
        systems().CollateralMock.address
      );
      // current assumption = 1000 collateral at $2000 price == $2M delegated collateral value
      await systems()
        .Core.connect(staker())
        .delegateCollateral(
          1,
          1,
          systems().CollateralMock.address,
          wei(currentCollateralAmount).mul(wei(0.9)).toBN(),
          ONE_ETHER
        );
    });

    let updateTxn: ethers.providers.TransactionResponse;
    before('call manual update', async () => {
      updateTxn = await systems().PerpsMarket.updateInterestRate();
      marketUpdateTime = await getTime(provider());
    });

    before('accumulate trader 1 interest', async () => {
      const timeSinceLastAccrued = marketUpdateTime - lastTimeInterestAccrued;
      // track interest accrued during new order
      const newInterestAccrued = _TRADER1_LOCKED_OI
        .mul(previousMarketInterestRate)
        .mul(proportionalTime(timeSinceLastAccrued));
      trader1InterestAccumulated = trader1InterestAccumulated.add(newInterestAccrued);
    });

    const { currentInterestRate } = checkMarketInterestRate();

    it('emits event', async () => {
      await assertEvent(
        updateTxn,
        `InterestRateUpdated(${superMarketId()}, ${currentInterestRate().toString(
          undefined,
          true
        )})`,
        systems().PerpsMarket
      );
    });

    describe('check trader interest after day passes', () => {
      let normalizedTime: Wei;
      before('fast forward time', async () => {
        await fastForwardTo(marketUpdateTime + _SECONDS_IN_DAY * 50, provider());

        const blockTime = await getTime(provider());
        lastTimeInterestAccrued = blockTime;
        normalizedTime = proportionalTime(blockTime - marketUpdateTime);
      });

      it('accrued correct interest for trader 1', async () => {
        const { owedInterest } = await systems().PerpsMarket.getOpenPosition(
          2,
          ethMarket.marketId()
        );

        const newInterestAccrued = _TRADER1_LOCKED_OI
          .mul(wei(await systems().PerpsMarket.interestRate()))
          .mul(normalizedTime);
        trader1InterestAccumulated = trader1InterestAccumulated.add(newInterestAccrued);
        assertBn.near(owedInterest, trader1InterestAccumulated.toBN(), TOLERANCE);
      });
    });
  });
});
