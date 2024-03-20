//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {ERC2771Context} from "@synthetixio/core-contracts/contracts/utils/ERC2771Context.sol";
import {FeatureFlag} from "@synthetixio/core-modules/contracts/storage/FeatureFlag.sol";
import {DecimalMath} from "@synthetixio/core-contracts/contracts/utils/DecimalMath.sol";
import {MathUtil} from "../utils/MathUtil.sol";
import {Flags} from "../utils/Flags.sol";
import {SafeCastU256} from "@synthetixio/core-contracts/contracts/utils/SafeCast.sol";
import {SetUtil} from "@synthetixio/core-contracts/contracts/utils/SetUtil.sol";
import {ILiquidationModule} from "../interfaces/ILiquidationModule.sol";
import {PerpsAccount} from "../storage/PerpsAccount.sol";
import {PerpsMarket} from "../storage/PerpsMarket.sol";
import {PerpsPrice} from "../storage/PerpsPrice.sol";
import {PerpsMarketFactory} from "../storage/PerpsMarketFactory.sol";
import {GlobalPerpsMarketConfiguration} from "../storage/GlobalPerpsMarketConfiguration.sol";
import {PerpsMarketConfiguration} from "../storage/PerpsMarketConfiguration.sol";
import {GlobalPerpsMarket} from "../storage/GlobalPerpsMarket.sol";
import {MarketUpdate} from "../storage/MarketUpdate.sol";
import {IMarketEvents} from "../interfaces/IMarketEvents.sol";
import {KeeperCosts} from "../storage/KeeperCosts.sol";
import {QuantoUint256, USDUint256, USDInt256, USDPerBaseUint256, USDPerQuantoUint256, BaseQuantoPerUSDInt128, BaseQuantoPerUSDUint128, BaseQuantoPerUSDUint256, InteractionsBaseQuantoPerUSDUint128, InteractionsBaseQuantoPerUSDUint256, InteractionsUSDUint256, InteractionsQuantoUint256} from '@kwenta/quanto-dimensions/src/UnitTypes.sol';

/**
 * @title Module for liquidating accounts.
 * @dev See ILiquidationModule.
 */
contract LiquidationModule is ILiquidationModule, IMarketEvents {
    using DecimalMath for uint256;
    using SafeCastU256 for uint256;
    using SetUtil for SetUtil.UintSet;
    using PerpsAccount for PerpsAccount.Data;
    using PerpsMarketConfiguration for PerpsMarketConfiguration.Data;
    using PerpsMarketFactory for PerpsMarketFactory.Data;
    using PerpsMarket for PerpsMarket.Data;
    using GlobalPerpsMarketConfiguration for GlobalPerpsMarketConfiguration.Data;
    using KeeperCosts for KeeperCosts.Data;
    using InteractionsBaseQuantoPerUSDUint128 for BaseQuantoPerUSDUint128;
    using InteractionsBaseQuantoPerUSDUint256 for BaseQuantoPerUSDUint256;
    using InteractionsQuantoUint256 for QuantoUint256;

    /**
     * @inheritdoc ILiquidationModule
     */
    function liquidate(uint128 accountId) external override returns (USDUint256 liquidationReward) {
        FeatureFlag.ensureAccessToFeature(Flags.PERPS_SYSTEM);

        SetUtil.UintSet storage liquidatableAccounts = GlobalPerpsMarket
            .load()
            .liquidatableAccounts;
        PerpsAccount.Data storage account = PerpsAccount.load(accountId);
        if (!liquidatableAccounts.contains(accountId)) {
            (
                bool isEligible,
                USDInt256 availableMargin,
                ,
                USDUint256 requiredMaintenaceMargin,
                USDUint256 expectedLiquidationReward
            ) = account.isEligibleForLiquidation(PerpsPrice.Tolerance.STRICT);

            if (isEligible) {
                (USDUint256 flagCost, USDUint256 marginCollected) = account.flagForLiquidation();

                emit AccountFlaggedForLiquidation(
                    accountId,
                    availableMargin,
                    requiredMaintenaceMargin,
                    expectedLiquidationReward,
                    flagCost
                );

                liquidationReward = _liquidateAccount(account, flagCost, marginCollected, true);
            } else {
                revert NotEligibleForLiquidation(accountId);
            }
        } else {
            liquidationReward = _liquidateAccount(account, InteractionsUSDUint256.zero(), InteractionsUSDUint256.zero(), false);
        }
    }

    /**
     * @inheritdoc ILiquidationModule
     */
    function liquidateFlagged(
        uint256 maxNumberOfAccounts
    ) external override returns (USDUint256 liquidationReward) {
        FeatureFlag.ensureAccessToFeature(Flags.PERPS_SYSTEM);

        uint256[] memory liquidatableAccounts = GlobalPerpsMarket
            .load()
            .liquidatableAccounts
            .values();

        uint256 numberOfAccountsToLiquidate = MathUtil.min(
            maxNumberOfAccounts,
            liquidatableAccounts.length
        );

        for (uint256 i = 0; i < numberOfAccountsToLiquidate; i++) {
            uint128 accountId = liquidatableAccounts[i].to128();
            liquidationReward = liquidationReward + _liquidateAccount(PerpsAccount.load(accountId), InteractionsUSDUint256.zero(), InteractionsUSDUint256.zero(), false);
        }
    }

    /**
     * @inheritdoc ILiquidationModule
     */
    function liquidateFlaggedAccounts(
        uint128[] calldata accountIds
    ) external override returns (USDUint256 liquidationReward) {
        FeatureFlag.ensureAccessToFeature(Flags.PERPS_SYSTEM);

        SetUtil.UintSet storage liquidatableAccounts = GlobalPerpsMarket
            .load()
            .liquidatableAccounts;

        for (uint256 i = 0; i < accountIds.length; i++) {
            uint128 accountId = accountIds[i];
            if (!liquidatableAccounts.contains(accountId)) {
                continue;
            }

            liquidationReward = liquidationReward + _liquidateAccount(PerpsAccount.load(accountId), InteractionsUSDUint256.zero(), InteractionsUSDUint256.zero(), false);
        }
    }

    /**
     * @inheritdoc ILiquidationModule
     */
    function flaggedAccounts() external view override returns (uint256[] memory accountIds) {
        return GlobalPerpsMarket.load().liquidatableAccounts.values();
    }

    /**
     * @inheritdoc ILiquidationModule
     */
    function canLiquidate(uint128 accountId) external view override returns (bool isEligible) {
        (isEligible, , , , ) = PerpsAccount.load(accountId).isEligibleForLiquidation(
            PerpsPrice.Tolerance.DEFAULT
        );
    }

    /**
     * @inheritdoc ILiquidationModule
     */
    function liquidationCapacity(
        uint128 marketId
    )
        external
        view
        override
        returns (
            BaseQuantoPerUSDUint256 capacity,
            BaseQuantoPerUSDUint256 maxLiquidationInWindow,
            uint256 latestLiquidationTimestamp
        )
    {
        return
            PerpsMarket.load(marketId).currentLiquidationCapacity(
                PerpsMarketConfiguration.load(marketId)
            );
    }

    struct LiquidateAccountRuntime {
        uint128 accountId;
        USDUint256 totalFlaggingRewards;
        BaseQuantoPerUSDUint256 totalLiquidated;
        bool accountFullyLiquidated;
        USDUint256 totalLiquidationCost;
        USDPerBaseUint256 price;
        uint128 positionMarketId;
        uint256 loopIterator; // stack too deep to the extreme
    }

    /**
     * @dev liquidates an account
     */
    function _liquidateAccount(
        PerpsAccount.Data storage account,
        USDUint256 costOfFlagExecution,
        USDUint256 totalCollateralValue,
        bool positionFlagged
    ) internal returns (USDUint256 keeperLiquidationReward) {
        LiquidateAccountRuntime memory runtime;
        runtime.accountId = account.id;
        uint256[] memory openPositionMarketIds = account.openPositionMarketIds.values();

        for (
            runtime.loopIterator = 0;
            runtime.loopIterator < openPositionMarketIds.length;
            runtime.loopIterator++
        ) {
            runtime.positionMarketId = openPositionMarketIds[runtime.loopIterator].to128();
            runtime.price = PerpsPrice.getCurrentPrice(
                runtime.positionMarketId,
                PerpsPrice.Tolerance.STRICT
            );

            (
                BaseQuantoPerUSDUint128 amountLiquidated,
                BaseQuantoPerUSDInt128 newPositionSize,
                BaseQuantoPerUSDInt128 sizeDelta,
                BaseQuantoPerUSDUint128 oldPositionAbsSize,
                MarketUpdate.Data memory marketUpdateData
            ) = account.liquidatePosition(runtime.positionMarketId, runtime.price);

            // endorsed liquidators do not get flag rewards
            if (
                ERC2771Context._msgSender() !=
                PerpsMarketConfiguration.load(runtime.positionMarketId).endorsedLiquidator
            ) {
                USDPerQuantoUint256 quantoPrice = PerpsPrice.getCurrentQuantoPrice(
                    runtime.positionMarketId,
                    PerpsPrice.Tolerance.DEFAULT
                );
                // using oldPositionAbsSize to calculate flag reward
                runtime.totalFlaggingRewards = runtime.totalFlaggingRewards + PerpsMarketConfiguration
                    .load(runtime.positionMarketId)
                    .calculateFlagReward(oldPositionAbsSize.to256().mulDecimalToQuanto(runtime.price)).mulDecimalToUSD(quantoPrice);
            }

            if (amountLiquidated.unwrap() == 0) {
                continue;
            }

            runtime.totalLiquidated = runtime.totalLiquidated + amountLiquidated.to256();

            emit MarketUpdated(
                runtime.positionMarketId,
                runtime.price,
                marketUpdateData.skew,
                marketUpdateData.size,
                sizeDelta,
                marketUpdateData.currentFundingRate,
                marketUpdateData.currentFundingVelocity,
                marketUpdateData.interestRate
            );

            emit PositionLiquidated(
                runtime.accountId,
                runtime.positionMarketId,
                amountLiquidated.unwrap(),
                newPositionSize.unwrap()
            );
        }

        runtime.totalLiquidationCost =
            KeeperCosts.load().getLiquidateKeeperCosts() +
            costOfFlagExecution;
        if (positionFlagged || runtime.totalLiquidated.unwrap() > 0) {
            keeperLiquidationReward = _processLiquidationRewards(
                positionFlagged ? runtime.totalFlaggingRewards : InteractionsUSDUint256.zero(),
                runtime.totalLiquidationCost,
                totalCollateralValue
            );
            runtime.accountFullyLiquidated = account.openPositionMarketIds.length() == 0;
            if (runtime.accountFullyLiquidated) {
                GlobalPerpsMarket.load().liquidatableAccounts.remove(runtime.accountId);
            }
        }

        emit AccountLiquidationAttempt(
            runtime.accountId,
            keeperLiquidationReward.unwrap(),
            runtime.accountFullyLiquidated
        );
    }

    /**
     * @dev process the accumulated liquidation rewards
     */
    function _processLiquidationRewards(
        USDUint256 keeperRewards,
        USDUint256 costOfExecutionInUsd,
        USDUint256 availableMarginInUsd
    ) private returns (USDUint256 reward) {
        if ((keeperRewards + costOfExecutionInUsd).isZero()) {
            return InteractionsUSDUint256.zero();
        }
        // pay out liquidation rewards
        reward = GlobalPerpsMarketConfiguration.load().keeperReward(
            keeperRewards,
            costOfExecutionInUsd,
            availableMarginInUsd
        );
        if (reward > InteractionsUSDUint256.zero()) {
            PerpsMarketFactory.load().withdrawMarketUsd(ERC2771Context._msgSender(), reward);
        }
    }
}
