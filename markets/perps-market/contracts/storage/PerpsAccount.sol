//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {Price} from "@synthetixio/spot-market/contracts/storage/Price.sol";
import {DecimalMath} from "@synthetixio/core-contracts/contracts/utils/DecimalMath.sol";
import {SafeCastI256, SafeCastU256, SafeCastU128} from "@synthetixio/core-contracts/contracts/utils/SafeCast.sol";
import {SetUtil} from "@synthetixio/core-contracts/contracts/utils/SetUtil.sol";
import {ISpotMarketSystem} from "../interfaces/external/ISpotMarketSystem.sol";
import {Position} from "./Position.sol";
import {PerpsMarket} from "./PerpsMarket.sol";
import {MathUtil} from "../utils/MathUtil.sol";
import {PerpsPrice} from "./PerpsPrice.sol";
import {MarketUpdate} from "./MarketUpdate.sol";
import {PerpsMarketFactory} from "./PerpsMarketFactory.sol";
import {GlobalPerpsMarket} from "./GlobalPerpsMarket.sol";
import {InterestRate} from "./InterestRate.sol";
import {GlobalPerpsMarketConfiguration} from "./GlobalPerpsMarketConfiguration.sol";
import {PerpsMarketConfiguration} from "./PerpsMarketConfiguration.sol";
import {KeeperCosts} from "../storage/KeeperCosts.sol";
import {AsyncOrder} from "../storage/AsyncOrder.sol";
import {BaseQuantoPerUSDInt128, BaseQuantoPerUSDUint128, BaseQuantoPerUSDUint256, USDPerBaseUint256, USDPerBaseInt256, USDPerQuantoUint256, USDPerBaseUint128, QuantoUint256, QuantoInt256, USDUint256, USDInt256, InteractionsQuantoUint256, InteractionsUSDPerQuantoUint256, InteractionsQuantoInt256, InteractionsBaseQuantoPerUSDInt128, InteractionsBaseQuantoPerUSDUint256, InteractionsBaseQuantoPerUSDUint128, InteractionsUSDUint256, InteractionsUSDPerBaseUint256, InteractionsUSDPerBaseInt256, InteractionsUSDInt256} from '@kwenta/quanto-dimensions/src/UnitTypes.sol';

uint128 constant SNX_USD_MARKET_ID = 0;

/**
 * @title Data for a single perps market
 */
library PerpsAccount {
    using SetUtil for SetUtil.UintSet;
    using SafeCastI256 for int256;
    using SafeCastU128 for uint128;
    using SafeCastU256 for uint256;
    using Position for Position.Data;
    using PerpsPrice for PerpsPrice.Data;
    using PerpsMarket for PerpsMarket.Data;
    using PerpsMarketConfiguration for PerpsMarketConfiguration.Data;
    using PerpsMarketFactory for PerpsMarketFactory.Data;
    using GlobalPerpsMarket for GlobalPerpsMarket.Data;
    using GlobalPerpsMarketConfiguration for GlobalPerpsMarketConfiguration.Data;
    using DecimalMath for int256;
    using DecimalMath for uint256;
    using KeeperCosts for KeeperCosts.Data;
    using AsyncOrder for AsyncOrder.Data;
    using InteractionsUSDInt256 for USDInt256;
    using InteractionsUSDUint256 for USDUint256;
    using InteractionsQuantoUint256 for QuantoUint256;
    using InteractionsUSDPerQuantoUint256 for USDPerQuantoUint256;
    using InteractionsQuantoInt256 for QuantoInt256;
    using InteractionsBaseQuantoPerUSDInt128 for BaseQuantoPerUSDInt128;
    using InteractionsBaseQuantoPerUSDUint128 for BaseQuantoPerUSDUint128;
    using InteractionsBaseQuantoPerUSDUint256 for BaseQuantoPerUSDUint256;
    using InteractionsUSDPerBaseUint256 for USDPerBaseUint256;
    using InteractionsUSDPerBaseInt256 for USDPerBaseInt256;

    struct Data {
        // @dev synth marketId => amount
        mapping(uint128 => uint256) collateralAmounts;
        // @dev account Id
        uint128 id;
        // @dev set of active collateral types. By active we mean collateral types that have a non-zero amount
        SetUtil.UintSet activeCollateralTypes;
        // @dev set of open position market ids
        SetUtil.UintSet openPositionMarketIds;
    }

    error InsufficientCollateralAvailableForWithdraw(
        USDUint256 availableUsdDenominated,
        USDUint256 requiredUsdDenominated
    );

    error InsufficientSynthCollateral(
        uint128 synthMarketId,
        uint256 collateralAmount,
        uint256 withdrawAmount
    );

    error InsufficientAccountMargin(uint256 leftover);

    error AccountLiquidatable(uint128 accountId);

    error MaxPositionsPerAccountReached(uint128 maxPositionsPerAccount);

    error MaxCollateralsPerAccountReached(uint128 maxCollateralsPerAccount);

    function load(uint128 id) internal pure returns (Data storage account) {
        bytes32 s = keccak256(abi.encode("io.synthetix.perps-market.Account", id));

        assembly {
            account.slot := s
        }
    }

    /**
        @notice allows us to update the account id in case it needs to be
     */
    function create(uint128 id) internal returns (Data storage account) {
        account = load(id);
        if (account.id == 0) {
            account.id = id;
        }
    }

    function validateMaxPositions(uint128 accountId, uint128 marketId) internal view {
        if (PerpsMarket.accountPosition(marketId, accountId).size.isZero()) {
            uint128 maxPositionsPerAccount = GlobalPerpsMarketConfiguration
                .load()
                .maxPositionsPerAccount;
            if (maxPositionsPerAccount <= load(accountId).openPositionMarketIds.length()) {
                revert MaxPositionsPerAccountReached(maxPositionsPerAccount);
            }
        }
    }

    function validateMaxCollaterals(uint128 accountId, uint128 synthMarketId) internal view {
        Data storage account = load(accountId);

        if (account.collateralAmounts[synthMarketId] == 0) {
            uint128 maxCollateralsPerAccount = GlobalPerpsMarketConfiguration
                .load()
                .maxCollateralsPerAccount;
            if (maxCollateralsPerAccount <= account.activeCollateralTypes.length()) {
                revert MaxCollateralsPerAccountReached(maxCollateralsPerAccount);
            }
        }
    }

    function isEligibleForLiquidation(
        Data storage self,
        PerpsPrice.Tolerance stalenessTolerance
    )
        internal
        view
        returns (
            bool isEligible,
            USDInt256 availableMargin,
            USDUint256 requiredInitialMargin,
            USDUint256 requiredMaintenanceMargin,
            USDUint256 liquidationReward
        )
    {
        availableMargin = getAvailableMargin(self, stalenessTolerance);

        (
            requiredInitialMargin,
            requiredMaintenanceMargin,
            liquidationReward
        ) = getAccountRequiredMargins(self, stalenessTolerance);
        isEligible = (requiredMaintenanceMargin + liquidationReward).toInt() > availableMargin;
    }

    function flagForLiquidation(
        Data storage self
    ) internal returns (USDUint256 flagKeeperCost, USDUint256 marginCollected) {
        SetUtil.UintSet storage liquidatableAccounts = GlobalPerpsMarket
            .load()
            .liquidatableAccounts;

        if (!liquidatableAccounts.contains(self.id)) {
            flagKeeperCost = KeeperCosts.load().getFlagKeeperCosts(self.id);
            liquidatableAccounts.add(self.id);
            marginCollected = convertAllCollateralToUsd(self);
            AsyncOrder.load(self.id).reset();
        }
    }

    function updateOpenPositions(
        Data storage self,
        uint256 positionMarketId,
        BaseQuantoPerUSDInt128 size
    ) internal {
        if (size.isZero() && self.openPositionMarketIds.contains(positionMarketId)) {
            self.openPositionMarketIds.remove(positionMarketId);
        } else if (!self.openPositionMarketIds.contains(positionMarketId)) {
            self.openPositionMarketIds.add(positionMarketId);
        }
    }

    function updateCollateralAmount(
        Data storage self,
        uint128 synthMarketId,
        int256 amountDelta
    ) internal returns (uint256 collateralAmount) {
        collateralAmount = (self.collateralAmounts[synthMarketId].toInt() + amountDelta).toUint();
        self.collateralAmounts[synthMarketId] = collateralAmount;

        bool isActiveCollateral = self.activeCollateralTypes.contains(synthMarketId);
        if (collateralAmount > 0 && !isActiveCollateral) {
            self.activeCollateralTypes.add(synthMarketId);
        } else if (collateralAmount == 0 && isActiveCollateral) {
            self.activeCollateralTypes.remove(synthMarketId);
        }

        // always update global values when account collateral is changed
        GlobalPerpsMarket.load().updateCollateralAmount(synthMarketId, amountDelta);
    }

    /**
     * @notice This function validates you have enough margin to withdraw without being liquidated.
     * @dev    This is done by checking your collateral value against your initial maintenance value.
     * @dev    It also checks the synth collateral for this account is enough to cover the withdrawal amount.
     * @dev    All price checks are not checking strict staleness tolerance.
     */
    function validateWithdrawableAmount(
        Data storage self,
        uint128 synthMarketId,
        uint256 amountToWithdraw,
        ISpotMarketSystem spotMarket
    ) internal view returns (USDUint256 availableWithdrawableCollateralUsd) {
        uint256 collateralAmount = self.collateralAmounts[synthMarketId];
        if (collateralAmount < amountToWithdraw) {
            revert InsufficientSynthCollateral(synthMarketId, collateralAmount, amountToWithdraw);
        }

        (
            bool isEligible,
            USDInt256 availableMargin,
            USDUint256 initialRequiredMargin,
            ,
            USDUint256 liquidationReward
        ) = isEligibleForLiquidation(self, PerpsPrice.Tolerance.STRICT);

        if (isEligible) {
            revert AccountLiquidatable(self.id);
        }

        USDUint256 requiredMargin = initialRequiredMargin + liquidationReward;
        // availableMargin can be assumed to be positive since we check for isEligible for liquidation prior
        availableWithdrawableCollateralUsd = availableMargin.toUint() - requiredMargin;

        uint256 amountToWithdrawUsd;
        if (synthMarketId == SNX_USD_MARKET_ID) {
            amountToWithdrawUsd = amountToWithdraw;
        } else {
            (amountToWithdrawUsd, ) = spotMarket.quoteSellExactIn(
                synthMarketId,
                amountToWithdraw,
                Price.Tolerance.DEFAULT
            );
        }

        if (USDUint256.wrap(amountToWithdrawUsd) > availableWithdrawableCollateralUsd) {
            revert InsufficientCollateralAvailableForWithdraw(
                availableWithdrawableCollateralUsd,
                USDUint256.wrap(amountToWithdrawUsd)
            );
        }
    }

    function getTotalCollateralValue(
        Data storage self,
        PerpsPrice.Tolerance stalenessTolerance
    ) internal view returns (USDUint256) {
        USDUint256 totalCollateralValue;
        ISpotMarketSystem spotMarket = PerpsMarketFactory.load().spotMarket;
        for (uint256 i = 1; i <= self.activeCollateralTypes.length(); i++) {
            uint128 synthMarketId = self.activeCollateralTypes.valueAt(i).to128();
            uint256 amount = self.collateralAmounts[synthMarketId];

            uint256 amountToAdd;
            if (synthMarketId == SNX_USD_MARKET_ID) {
                amountToAdd = amount;
            } else {
                (amountToAdd, ) = spotMarket.quoteSellExactIn(
                    synthMarketId,
                    amount,
                    Price.Tolerance(uint256(stalenessTolerance)) // solhint-disable-line numcast/safe-cast
                );
            }
            totalCollateralValue = totalCollateralValue + USDUint256.wrap(amountToAdd);
        }
        return totalCollateralValue;
    }

    function getAccountPnl(
        Data storage self,
        PerpsPrice.Tolerance stalenessTolerance
    ) internal view returns (USDInt256 totalPnl) {
        for (uint256 i = 1; i <= self.openPositionMarketIds.length(); i++) {
            uint128 marketId = self.openPositionMarketIds.valueAt(i).to128();

            Position.Data storage position = PerpsMarket.load(marketId).positions[self.id];
            (QuantoInt256 pnl, , , , , ) = position.getPnl(
                PerpsPrice.getCurrentPrice(marketId, stalenessTolerance)
            );

            USDPerQuantoUint256 quantoPrice = PerpsPrice.getCurrentQuantoPrice(marketId, stalenessTolerance);
            USDInt256 usdPnl = pnl.mulDecimalToUSD(quantoPrice.toInt());

            totalPnl = totalPnl + usdPnl;
        }
    }

    function getAvailableMargin(
        Data storage self,
        PerpsPrice.Tolerance stalenessTolerance
    ) internal view returns (USDInt256) {
        USDUint256 totalCollateralValue = getTotalCollateralValue(self, stalenessTolerance);
        USDInt256 accountPnl = getAccountPnl(self, stalenessTolerance);

        return totalCollateralValue.toInt() + accountPnl;
    }

    function getTotalNotionalOpenInterest(
        Data storage self
    ) internal view returns (USDUint256 totalAccountOpenInterest) {
        for (uint256 i = 1; i <= self.openPositionMarketIds.length(); i++) {
            uint128 marketId = self.openPositionMarketIds.valueAt(i).to128();

            Position.Data storage position = PerpsMarket.load(marketId).positions[self.id];
            QuantoUint256 openInterest = position.getNotionalValue(
                PerpsPrice.getCurrentPrice(marketId, PerpsPrice.Tolerance.DEFAULT)
            );

            USDPerQuantoUint256 quantoPrice = PerpsPrice.getCurrentQuantoPrice(marketId, PerpsPrice.Tolerance.DEFAULT);
            USDUint256 usdValue = openInterest.mulDecimalToUSD(quantoPrice);

            totalAccountOpenInterest = totalAccountOpenInterest + usdValue;
        }
    }

    /**
     * @notice  This function returns the required margins for an account
     * @dev The initial required margin is used to determine withdrawal amount and when opening positions
     * @dev The maintenance margin is used to determine when to liquidate a position
     * @dev Returns USD
     */
    function getAccountRequiredMargins(
        Data storage self,
        PerpsPrice.Tolerance stalenessTolerance
    )
        internal
        view
        returns (
            USDUint256 initialMargin,
            USDUint256 maintenanceMargin,
            USDUint256 possibleLiquidationReward
        )
    {
        uint256 openPositionMarketIdsLength = self.openPositionMarketIds.length();
        if (openPositionMarketIdsLength == 0) {
            return (InteractionsUSDUint256.zero(), InteractionsUSDUint256.zero(), InteractionsUSDUint256.zero());
        }

        // use separate accounting for liquidation rewards so we can compare against global min/max liquidation reward values
        for (uint256 i = 1; i <= openPositionMarketIdsLength; i++) {
            uint128 marketId = self.openPositionMarketIds.valueAt(i).to128();
            Position.Data storage position = PerpsMarket.load(marketId).positions[self.id];
            PerpsMarketConfiguration.Data storage marketConfig = PerpsMarketConfiguration.load(
                marketId
            );
            (, , QuantoUint256 positionInitialMargin, QuantoUint256 positionMaintenanceMargin) = marketConfig
                .calculateRequiredMargins(
                    position.size,
                    PerpsPrice.getCurrentPrice(marketId, stalenessTolerance)
                );

            USDPerQuantoUint256 quantoPrice = PerpsPrice.getCurrentQuantoPrice(marketId, stalenessTolerance);
            maintenanceMargin = maintenanceMargin + positionMaintenanceMargin.mulDecimalToUSD(quantoPrice);
            initialMargin = initialMargin + positionInitialMargin.mulDecimalToUSD(quantoPrice);
        }

        (
            USDUint256 accumulatedLiquidationRewards,
            uint256 maxNumberOfWindows
        ) = getKeeperRewardsAndCosts(self, 0);
        possibleLiquidationReward = getPossibleLiquidationReward(
            self,
            accumulatedLiquidationRewards,
            maxNumberOfWindows
        );

        return (initialMargin, maintenanceMargin, possibleLiquidationReward);
    }

    function getKeeperRewardsAndCosts(
        Data storage self,
        uint128 skipMarketId
    ) internal view returns (USDUint256 accumulatedLiquidationRewards, uint256 maxNumberOfWindows) {
        // use separate accounting for liquidation rewards so we can compare against global min/max liquidation reward values
        for (uint256 i = 1; i <= self.openPositionMarketIds.length(); i++) {
            uint128 marketId = self.openPositionMarketIds.valueAt(i).to128();
            if (marketId == skipMarketId) continue;
            Position.Data storage position = PerpsMarket.load(marketId).positions[self.id];
            PerpsMarketConfiguration.Data storage marketConfig = PerpsMarketConfiguration.load(
                marketId
            );

            uint256 numberOfWindows = marketConfig.numberOfLiquidationWindows(
                position.size.abs()
            );

            QuantoUint256 flagReward = marketConfig.calculateFlagReward(
                position.size.abs().mulDecimalToQuanto(
                    PerpsPrice.getCurrentPrice(marketId, PerpsPrice.Tolerance.DEFAULT)
                )
            );
            USDPerQuantoUint256 quantoPrice = PerpsPrice.getCurrentQuantoPrice(marketId, PerpsPrice.Tolerance.DEFAULT);
            accumulatedLiquidationRewards = accumulatedLiquidationRewards + flagReward.mulDecimalToUSD(quantoPrice);

            maxNumberOfWindows = MathUtil.max(numberOfWindows, maxNumberOfWindows);
        }
    }

    function getPossibleLiquidationReward(
        Data storage self,
        USDUint256 accumulatedLiquidationRewards,
        uint256 numOfWindows
    ) internal view returns (USDUint256 possibleLiquidationReward) {
        GlobalPerpsMarketConfiguration.Data storage globalConfig = GlobalPerpsMarketConfiguration
            .load();
        KeeperCosts.Data storage keeperCosts = KeeperCosts.load();
        USDUint256 costOfFlagging = keeperCosts.getFlagKeeperCosts(self.id);
        USDUint256 costOfLiquidation = keeperCosts.getLiquidateKeeperCosts();
        USDUint256 liquidateAndFlagCost = globalConfig.keeperReward(
            accumulatedLiquidationRewards,
            costOfFlagging,
            getTotalCollateralValue(self, PerpsPrice.Tolerance.DEFAULT)
        );
        USDUint256 liquidateWindowsCosts = numOfWindows == 0
            ? InteractionsUSDUint256.zero()
            : globalConfig.keeperReward(InteractionsUSDUint256.zero(), costOfLiquidation, InteractionsUSDUint256.zero()).mul(numOfWindows - 1);

        possibleLiquidationReward = liquidateAndFlagCost + liquidateWindowsCosts;
    }

    function convertAllCollateralToUsd(
        Data storage self
    ) internal returns (USDUint256 totalConvertedCollateral) {
        PerpsMarketFactory.Data storage factory = PerpsMarketFactory.load();
        uint256[] memory activeCollateralTypes = self.activeCollateralTypes.values();

        // 1. withdraw all collateral from synthetix
        // 2. sell all collateral for snxUSD
        // 3. deposit snxUSD into synthetix
        for (uint256 i = 0; i < activeCollateralTypes.length; i++) {
            uint128 synthMarketId = activeCollateralTypes[i].to128();
            if (synthMarketId == SNX_USD_MARKET_ID) {
                totalConvertedCollateral = totalConvertedCollateral + USDUint256.wrap(self.collateralAmounts[synthMarketId]);
                updateCollateralAmount(
                    self,
                    synthMarketId,
                    -(self.collateralAmounts[synthMarketId].toInt())
                );
            } else {
                totalConvertedCollateral = totalConvertedCollateral + _deductAllSynth(self, factory, synthMarketId);
            }
        }
    }

    /**
     * @notice  This function deducts snxUSD from an account
     * @dev It uses the synth deduction priority to determine which synth to deduct from first
     * @dev if the synth is not snxUSD it will sell the synth for snxUSD
     * @dev Returns two arrays with the synth ids and amounts deducted
     */
    function deductFromAccount(
        Data storage self,
        USDUint256 amount
    ) internal returns (uint128[] memory deductedSynthIds, uint256[] memory deductedAmount) {
        uint256 leftoverAmount = amount.unwrap();
        uint128[] storage synthDeductionPriority = GlobalPerpsMarketConfiguration
            .load()
            .synthDeductionPriority;
        PerpsMarketFactory.Data storage factory = PerpsMarketFactory.load();
        ISpotMarketSystem spotMarket = factory.spotMarket;

        deductedSynthIds = new uint128[](synthDeductionPriority.length);
        deductedAmount = new uint256[](synthDeductionPriority.length);

        for (uint256 i = 0; i < synthDeductionPriority.length; i++) {
            uint128 synthMarketId = synthDeductionPriority[i];
            uint256 availableAmount = self.collateralAmounts[synthMarketId];
            if (availableAmount == 0) {
                continue;
            }
            deductedSynthIds[i] = synthMarketId;

            if (synthMarketId == SNX_USD_MARKET_ID) {
                // snxUSD
                if (availableAmount >= leftoverAmount) {
                    deductedAmount[i] = leftoverAmount;
                    updateCollateralAmount(self, synthMarketId, -(leftoverAmount.toInt()));
                    leftoverAmount = 0;
                    break;
                } else {
                    deductedAmount[i] = availableAmount;
                    updateCollateralAmount(self, synthMarketId, -(availableAmount.toInt()));
                    leftoverAmount -= availableAmount;
                }
            } else {
                (uint256 synthAmountRequired, ) = spotMarket.quoteSellExactOut(
                    synthMarketId,
                    leftoverAmount,
                    Price.Tolerance.STRICT
                );

                address synthToken = factory.spotMarket.getSynth(synthMarketId);

                if (availableAmount >= synthAmountRequired) {
                    factory.synthetix.withdrawMarketCollateral(
                        factory.perpsMarketId,
                        synthToken,
                        synthAmountRequired
                    );

                    (uint256 amountToDeduct, ) = spotMarket.sellExactOut(
                        synthMarketId,
                        leftoverAmount,
                        type(uint256).max,
                        address(0)
                    );

                    factory.depositMarketUsd(USDUint256.wrap(leftoverAmount));

                    deductedAmount[i] = amountToDeduct;
                    updateCollateralAmount(self, synthMarketId, -(amountToDeduct.toInt()));
                    leftoverAmount = 0;
                    break;
                } else {
                    factory.synthetix.withdrawMarketCollateral(
                        factory.perpsMarketId,
                        synthToken,
                        availableAmount
                    );

                    (uint256 amountToDeductUsd, ) = spotMarket.sellExactIn(
                        synthMarketId,
                        availableAmount,
                        0,
                        address(0)
                    );

                    factory.depositMarketUsd(USDUint256.wrap(amountToDeductUsd));

                    deductedAmount[i] = availableAmount;
                    updateCollateralAmount(self, synthMarketId, -(availableAmount.toInt()));
                    leftoverAmount -= amountToDeductUsd;
                }
            }
        }

        if (leftoverAmount > 0) {
            revert InsufficientAccountMargin(leftoverAmount);
        }
    }

    function liquidatePosition(
        Data storage self,
        uint128 marketId,
        USDPerBaseUint256 price
    )
        internal
        returns (
            BaseQuantoPerUSDUint128 amountToLiquidate,
            BaseQuantoPerUSDInt128 newPositionSize,
            BaseQuantoPerUSDInt128 sizeDelta,
            BaseQuantoPerUSDUint128 oldPositionAbsSize,
            MarketUpdate.Data memory marketUpdateData
        )
    {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        Position.Data storage position = perpsMarket.positions[self.id];

        perpsMarket.recomputeFunding(price);

        BaseQuantoPerUSDInt128 oldPositionSize = position.size;
        oldPositionAbsSize = oldPositionSize.abs128();
        amountToLiquidate = perpsMarket.maxLiquidatableAmount(oldPositionAbsSize);

        if (amountToLiquidate.isZero()) {
            return (InteractionsBaseQuantoPerUSDUint128.zero(), oldPositionSize, InteractionsBaseQuantoPerUSDInt128.zero(), oldPositionAbsSize, marketUpdateData);
        }

        BaseQuantoPerUSDInt128 amtToLiquidationInt = amountToLiquidate.toInt();
        // reduce position size
        newPositionSize = oldPositionSize.greaterThanZero()
            ? oldPositionSize - amtToLiquidationInt
            : oldPositionSize + amtToLiquidationInt;

        // create new position in case of partial liquidation
        Position.Data memory newPosition;
        if (!newPositionSize.isZero()) {
            newPosition = Position.Data({
                marketId: marketId,
                latestInteractionPrice: price.to128(),
                latestInteractionFunding: perpsMarket.lastFundingValue.to128(),
                latestInterestAccrued: 0,
                size: newPositionSize
            });
        }

        // update position markets
        updateOpenPositions(self, marketId, newPositionSize);

        // update market data
        // TODO: ensure stuff going in here is correct
        marketUpdateData = perpsMarket.updatePositionData(self.id, newPosition);
        sizeDelta = newPositionSize - oldPositionSize;

        return (
            amountToLiquidate,
            newPositionSize,
            sizeDelta,
            oldPositionAbsSize,
            marketUpdateData
        );
    }

    function _deductAllSynth(
        Data storage self,
        PerpsMarketFactory.Data storage factory,
        uint128 synthMarketId
    ) private returns (USDUint256 amountUsd) {
        uint256 amount = self.collateralAmounts[synthMarketId];
        address synth = factory.spotMarket.getSynth(synthMarketId);

        // 1. withdraw collateral from market manager
        factory.synthetix.withdrawMarketCollateral(factory.perpsMarketId, synth, amount);

        // 2. sell collateral for snxUSD
        (uint256 amountUsdUnwrapped, ) = PerpsMarketFactory.load().spotMarket.sellExactIn(
            synthMarketId,
            amount,
            0,
            address(0)
        );
        amountUsd = USDUint256.wrap(amountUsdUnwrapped);

        // 3. deposit snxUSD into market manager
        factory.depositMarketUsd(amountUsd);

        // 4. update account collateral amount
        updateCollateralAmount(self, synthMarketId, -(amount.toInt()));
    }
}
