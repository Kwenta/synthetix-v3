//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {DecimalMath} from "@synthetixio/core-contracts/contracts/utils/DecimalMath.sol";
import {SafeCastI256, SafeCastU256, SafeCastI128} from "@synthetixio/core-contracts/contracts/utils/SafeCast.sol";
import {SettlementStrategy} from "./SettlementStrategy.sol";
import {Position} from "./Position.sol";
import {PerpsMarketConfiguration} from "./PerpsMarketConfiguration.sol";
import {PerpsMarket} from "./PerpsMarket.sol";
import {PerpsPrice} from "./PerpsPrice.sol";
import {PerpsAccount} from "./PerpsAccount.sol";
import {MathUtil} from "../utils/MathUtil.sol";
import {OrderFee} from "./OrderFee.sol";
import {KeeperCosts} from "./KeeperCosts.sol";
import {BaseQuantoPerUSDInt128, BaseQuantoPerUSDInt256, BaseQuantoPerUSDUint256, USDPerBaseUint256, USDPerBaseUint128, USDPerQuantoUint256, USDPerQuantoInt256, USDPerBaseInt256, QuantoUint256, QuantoInt256, USDInt256, USDUint256, InteractionsQuantoUint256, InteractionsQuantoInt256, InteractionsBaseQuantoPerUSDInt256, InteractionsUSDPerBaseUint256, InteractionsBaseQuantoPerUSDInt128, InteractionsUSDUint256, InteractionsUSDPerQuantoUint256, InteractionsBaseQuantoPerUSDUint256, InteractionsUSDInt256, InteractionsUSDPerBaseInt256} from '@kwenta/quanto-dimensions/src/UnitTypes.sol';

/**
 * @title Async order top level data storage
 */
library AsyncOrder {
    using DecimalMath for int256;
    using DecimalMath for int128;
    using DecimalMath for uint256;
    using SafeCastI128 for int128;
    using SafeCastI256 for int256;
    using SafeCastU256 for uint256;
    using PerpsMarketConfiguration for PerpsMarketConfiguration.Data;
    using PerpsMarket for PerpsMarket.Data;
    using PerpsAccount for PerpsAccount.Data;
    using KeeperCosts for KeeperCosts.Data;
    using InteractionsQuantoUint256 for QuantoUint256;
    using InteractionsQuantoInt256 for QuantoInt256;
    using InteractionsUSDPerBaseUint256 for USDPerBaseUint256;
    using InteractionsBaseQuantoPerUSDInt128 for BaseQuantoPerUSDInt128;
    using InteractionsBaseQuantoPerUSDInt256 for BaseQuantoPerUSDInt256;
    using InteractionsBaseQuantoPerUSDUint256 for BaseQuantoPerUSDUint256;
    using InteractionsUSDPerQuantoUint256 for USDPerQuantoUint256;
    using InteractionsUSDPerBaseInt256 for USDPerBaseInt256;
    using InteractionsUSDUint256 for USDUint256;
    using InteractionsUSDInt256 for USDInt256;

    /**
     * @notice Thrown when settlement window is not open yet.
     */
    error SettlementWindowNotOpen(uint256 timestamp, uint256 settlementTime);

    /**
     * @notice Thrown when attempting to settle an expired order.
     */
    error SettlementWindowExpired(
        uint256 timestamp,
        uint256 settlementTime,
        uint256 settlementExpiration
    );

    /**
     * @notice Thrown when order does not exist.
     * @dev Order does not exist if the order sizeDelta is 0.
     */
    error OrderNotValid();

    /**
     * @notice Thrown when fill price exceeds the acceptable price set at submission.
     */
    error AcceptablePriceExceeded(USDPerBaseUint256 fillPrice, USDPerBaseUint256 acceptablePrice);

    /**
     * @notice Gets thrown when attempting to cancel an order and price does not exceeds acceptable price.
     */
    error AcceptablePriceNotExceeded(USDPerBaseUint256 fillPrice, USDPerBaseUint256 acceptablePrice);

    /**
     * @notice Gets thrown when pending orders exist and attempts to modify collateral.
     */
    error PendingOrderExists();

    /**
     * @notice Thrown when commiting an order with sizeDelta is zero.
     * @dev Size delta 0 is used to flag a non-valid order since it's a non-update order.
     */
    error ZeroSizeOrder();

    /**
     * @notice Thrown when there's not enough margin to cover the order and settlement costs associated.
     */
    error InsufficientMargin(USDInt256 availableMargin, USDUint256 minMargin);

    struct Data {
        /**
         * @dev Time at which the order was committed.
         */
        uint256 commitmentTime;
        /**
         * @dev Order request details.
         */
        OrderCommitmentRequest request;
    }

    struct OrderCommitmentRequest {
        /**
         * @dev Order market id.
         */
        uint128 marketId;
        /**
         * @dev Order account id.
         */
        uint128 accountId;
        /**
         * @dev Order size delta (of base*quanto/usd units expressed in decimal 18 digits). It can be positive or negative.
         */
        BaseQuantoPerUSDInt128 sizeDelta;
        /**
         * @dev Settlement strategy used for the order.
         */
        uint128 settlementStrategyId;
        /**
         * @dev Acceptable price set at submission.
         */
        USDPerBaseUint256 acceptablePrice;
        /**
         * @dev An optional code provided by frontends to assist with tracking the source of volume and fees.
         */
        bytes32 trackingCode;
        /**
         * @dev Referrer address to send the referrer fees to.
         */
        address referrer;
    }

    /**
     * @notice Updates the order with the commitment request data and settlement time.
     */
    function load(uint128 accountId) internal pure returns (Data storage order) {
        bytes32 s = keccak256(abi.encode("io.synthetix.perps-market.AsyncOrder", accountId));

        assembly {
            order.slot := s
        }
    }

    /**
     * @dev Reverts if order was not committed by checking the sizeDelta.
     * @dev Reverts if order is not in the settlement window.
     */
    function loadValid(
        uint128 accountId
    ) internal view returns (Data storage order, SettlementStrategy.Data storage strategy) {
        order = load(accountId);
        if (order.request.sizeDelta.isZero()) {
            revert OrderNotValid();
        }

        strategy = PerpsMarketConfiguration.loadValidSettlementStrategy(
            order.request.marketId,
            order.request.settlementStrategyId
        );
        checkWithinSettlementWindow(order, strategy);
    }

    /**
     * @dev Updates the order with the new commitment request data and settlement time.
     * @dev Reverts if there's a pending order.
     * @dev Reverts if accont cannot open a new position (due to max allowed reached).
     */
    function updateValid(Data storage self, OrderCommitmentRequest memory newRequest) internal {
        checkPendingOrder(newRequest.accountId);

        PerpsAccount.validateMaxPositions(newRequest.accountId, newRequest.marketId);

        // Replace previous (or empty) order with the commitment request
        self.commitmentTime = block.timestamp;
        self.request = newRequest;
    }

    /**
     * @dev Reverts if there is a pending order.
     * @dev A pending order is one that has a sizeDelta and isn't expired yet.
     */
    function checkPendingOrder(uint128 accountId) internal view returns (Data storage order) {
        order = load(accountId);

        if (!order.request.sizeDelta.isZero()) {
            SettlementStrategy.Data storage strategy = PerpsMarketConfiguration
                .load(order.request.marketId)
                .settlementStrategies[order.request.settlementStrategyId];

            if (!expired(order, strategy)) {
                revert PendingOrderExists();
            }
        }
    }

    /**
     * @notice Resets the order.
     * @dev This function is called after the order is settled.
     * @dev Just setting the sizeDelta to 0 is enough, since is the value checked to identify an active order at settlement time.
     * @dev The rest of the fields will be updated on the next commitment. Not doing it here is more gas efficient.
     */
    function reset(Data storage self) internal {
        self.request.sizeDelta = InteractionsBaseQuantoPerUSDInt128.zero();
    }

    /**
     * @notice Checks if the order window settlement is opened and expired.
     * @dev Reverts if block.timestamp is < settlementTime (not <=, so even if the settlementDelay is set to zero, it will require at least 1 second waiting time)
     * @dev Reverts if block.timestamp is > settlementTime + settlementWindowDuration
     */
    function checkWithinSettlementWindow(
        Data storage self,
        SettlementStrategy.Data storage settlementStrategy
    ) internal view {
        uint256 settlementTime = self.commitmentTime + settlementStrategy.settlementDelay;
        uint256 settlementExpiration = settlementTime + settlementStrategy.settlementWindowDuration;

        if (block.timestamp < settlementTime) {
            revert SettlementWindowNotOpen(block.timestamp, settlementTime);
        }

        if (block.timestamp > settlementExpiration) {
            revert SettlementWindowExpired(block.timestamp, settlementTime, settlementExpiration);
        }
    }

    /**
     * @notice Returns if order is expired or not
     */
    function expired(
        Data storage self,
        SettlementStrategy.Data storage settlementStrategy
    ) internal view returns (bool) {
        uint256 settlementExpiration = self.commitmentTime +
            settlementStrategy.settlementDelay +
            settlementStrategy.settlementWindowDuration;
        return block.timestamp > settlementExpiration;
    }

    /**
     * @dev Struct used internally in validateOrder() to prevent stack too deep error.
     */
    // TODO: check to be sure commented out types can definitely be deleted safely
    // TODO: if they can be deleted safely, delete them
    struct SimulateDataRuntime {
        bool isEligible;
        BaseQuantoPerUSDInt128 sizeDelta;
        uint128 accountId;
        uint128 marketId;
        USDPerBaseUint256 fillPrice;
        USDUint256 orderFees;
        // uint256 availableMargin;
        // uint256 currentLiquidationMargin;
        uint256 accumulatedLiquidationRewards;
        USDUint256 currentLiquidationReward;
        BaseQuantoPerUSDInt128 newPositionSize;
        // uint256 newNotionalValue;
        USDInt256 currentAvailableMargin;
        USDUint256 requiredInitialMargin;
        // uint256 initialRequiredMargin;
        USDUint256 totalRequiredMargin;
        Position.Data newPosition;
        bytes32 trackingCode;
        USDPerQuantoUint256 quantoPrice;
        USDInt256 startingPnl;
    }

    /**
     * @notice Checks if the order request can be settled.
     * @dev it recomputes market funding rate, calculates fill price and fees for the order
     * @dev and with that data it checks that:
     * @dev - the account is eligible for liquidation
     * @dev - the fill price is within the acceptable price range
     * @dev - the position size doesn't exceed market configured limits
     * @dev - the account has enough margin to cover for the fees
     * @dev - the account has enough margin to not be liquidable immediately after the order is settled
     * @dev if the order can be executed, it returns (newPosition, orderFees, fillPrice, oldPosition)
     */
    function validateRequest(
        Data storage order,
        SettlementStrategy.Data storage strategy,
        USDPerBaseUint256 orderPrice
    ) internal returns (Position.Data memory, USDUint256, USDPerBaseUint256, Position.Data storage oldPosition) {
        SimulateDataRuntime memory runtime;
        runtime.sizeDelta = order.request.sizeDelta;
        runtime.accountId = order.request.accountId;
        runtime.marketId = order.request.marketId;

        if (runtime.sizeDelta.isZero()) {
            revert ZeroSizeOrder();
        }

        PerpsAccount.Data storage account = PerpsAccount.load(runtime.accountId);

        (
            runtime.isEligible,
            runtime.currentAvailableMargin,
            runtime.requiredInitialMargin,
            ,
            runtime.currentLiquidationReward
        ) = account.isEligibleForLiquidation(PerpsPrice.Tolerance.DEFAULT);

        if (runtime.isEligible) {
            revert PerpsAccount.AccountLiquidatable(runtime.accountId);
        }

        PerpsMarket.Data storage perpsMarketData = PerpsMarket.load(runtime.marketId);
        perpsMarketData.recomputeFunding(orderPrice);

        PerpsMarketConfiguration.Data storage marketConfig = PerpsMarketConfiguration.load(
            runtime.marketId
        );

        runtime.fillPrice = calculateFillPrice(
            perpsMarketData.skew,
            marketConfig.skewScale,
            runtime.sizeDelta,
            orderPrice
        );

        if (acceptablePriceExceeded(order, runtime.fillPrice)) {
            revert AcceptablePriceExceeded(runtime.fillPrice, order.request.acceptablePrice);
        }

        runtime.quantoPrice = PerpsPrice.getCurrentQuantoPrice(runtime.marketId, PerpsPrice.Tolerance.DEFAULT);

        runtime.orderFees =
            calculateOrderFee(
                runtime.sizeDelta,
                runtime.fillPrice,
                perpsMarketData.skew,
                marketConfig.orderFees
            ).mulDecimalToUSD(runtime.quantoPrice) + settlementRewardCost(strategy);

        oldPosition = PerpsMarket.accountPosition(runtime.marketId, runtime.accountId);
        runtime.newPositionSize = oldPosition.size + runtime.sizeDelta;

        runtime.startingPnl = calculateStartingPnl(
            runtime.fillPrice,
            orderPrice,
            runtime.newPositionSize
        ).mulDecimalToUSD(runtime.quantoPrice.toInt());

        // only account for negative pnl
        runtime.currentAvailableMargin = runtime.currentAvailableMargin + runtime.startingPnl.min(InteractionsUSDInt256.zero());

        if (runtime.currentAvailableMargin < runtime.orderFees.toInt()) {
            revert InsufficientMargin(runtime.currentAvailableMargin, runtime.orderFees);
        }

        PerpsMarket.validatePositionSize(
            perpsMarketData,
            marketConfig.maxMarketSize,
            marketConfig.maxMarketValue,
            orderPrice,
            oldPosition.size,
            runtime.newPositionSize
        );

        runtime.totalRequiredMargin =
            getRequiredMarginWithNewPosition(
                account,
                marketConfig,
                runtime.marketId,
                oldPosition.size,
                runtime.newPositionSize,
                runtime.fillPrice,
                runtime.requiredInitialMargin
            ) +
            runtime.orderFees;

        if (runtime.currentAvailableMargin < runtime.totalRequiredMargin.toInt()) {
            revert InsufficientMargin(runtime.currentAvailableMargin, runtime.totalRequiredMargin);
        }

        runtime.newPosition = Position.Data({
            marketId: runtime.marketId,
            latestInteractionPrice: runtime.fillPrice.to128(),
            latestInteractionFunding: perpsMarketData.lastFundingValue.to128(),
            latestInterestAccrued: 0,
            size: runtime.newPositionSize
        });
        return (runtime.newPosition, runtime.orderFees, runtime.fillPrice, oldPosition);
    }

    /**
     * @notice Checks if the order request can be cancelled.
     * @notice This function doesn't check for liquidation or available margin since the fees to be paid are small and we did that check at commitment less than the settlement window time.
     * @notice it won't check if the order exists since it was already checked when loading the order (loadValid)
     * @dev it calculates fill price the order
     * @dev and with that data it checks that:
     * @dev - settlement window is open
     * @dev - the fill price is outside the acceptable price range
     * @dev if the order can be cancelled, it returns the fillPrice
     */
    function validateCancellation(
        Data storage order,
        SettlementStrategy.Data storage strategy,
        USDPerBaseUint256 orderPrice
    ) internal view returns (USDPerBaseUint256 fillPrice) {
        checkWithinSettlementWindow(order, strategy);

        PerpsMarket.Data storage perpsMarketData = PerpsMarket.load(order.request.marketId);

        PerpsMarketConfiguration.Data storage marketConfig = PerpsMarketConfiguration.load(
            order.request.marketId
        );

        fillPrice = calculateFillPrice(
            perpsMarketData.skew,
            marketConfig.skewScale,
            order.request.sizeDelta,
            orderPrice
        );

        // check if fill price exceeded acceptable price
        if (!acceptablePriceExceeded(order, fillPrice)) {
            revert AcceptablePriceNotExceeded(fillPrice, order.request.acceptablePrice);
        }
    }

    /**
     * @notice Calculates the settlement rewards.
     */
    function settlementRewardCost(
        SettlementStrategy.Data storage strategy
    ) internal view returns (USDUint256) {
        return KeeperCosts.load().getSettlementKeeperCosts() + strategy.settlementReward;
    }

    /**
     * @notice Calculates the order fees.
     */
    function calculateOrderFee(
        BaseQuantoPerUSDInt128 sizeDelta,
        USDPerBaseUint256 fillPrice,
        BaseQuantoPerUSDInt256 marketSkew,
        OrderFee.Data storage orderFeeData
    ) internal view returns (QuantoUint256) {
        QuantoInt256 notionalDiff = sizeDelta.to256().mulDecimalToQuanto(fillPrice.toInt());

        // does this trade keep the skew on one side?
        if ((marketSkew + sizeDelta.to256()).sameSide(marketSkew)) {
            // use a flat maker/taker fee for the entire size depending on whether the skew is increased or reduced.
            //
            // if the order is submitted on the same side as the skew (increasing it) - the taker fee is charged.
            // otherwise if the order is opposite to the skew, the maker fee is charged.

            uint256 staticRate = MathUtil.sameSide(notionalDiff.unwrap(), marketSkew.unwrap())
                ? orderFeeData.takerFee
                : orderFeeData.makerFee;
            return notionalDiff.mulDecimal(staticRate.toInt()).abs();
        }

        // this trade flips the skew.
        //
        // the proportion of size that moves in the direction after the flip should not be considered
        // as a maker (reducing skew) as it's now taking (increasing skew) in the opposite direction. hence,
        // a different fee is applied on the proportion increasing the skew.

        // The proportions are computed as follows:
        // makerSize = abs(marketSkew) => since we are reversing the skew, the maker size is the current skew
        // takerSize = abs(marketSkew + sizeDelta) => since we are reversing the skew, the taker size is the new skew
        //
        // we then multiply the sizes by the fill price to get the notional value of each side, and that times the fee rate for each side

        QuantoUint256 makerFee = marketSkew.abs().mulDecimalToQuanto(fillPrice).mulDecimal(
            orderFeeData.makerFee
        );

        QuantoUint256 takerFee = (marketSkew + sizeDelta.to256()).abs().mulDecimalToQuanto(fillPrice).mulDecimal(
            orderFeeData.takerFee
        );

        return takerFee + makerFee;
    }

    /**
     * @notice Calculates the fill price for an order.
     */
    function calculateFillPrice(
        BaseQuantoPerUSDInt256 skew,
        BaseQuantoPerUSDUint256 skewScale,
        BaseQuantoPerUSDInt128 size,
        USDPerBaseUint256 price
    ) internal pure returns (USDPerBaseUint256) {
        // How is the p/d-adjusted price calculated using an example:
        //
        // price      = $1200 USD (oracle)
        // size       = 100
        // skew       = 0
        // skew_scale = 1,000,000 (1M)
        //
        // Then,
        //
        // pd_before = 0 / 1,000,000
        //           = 0
        // pd_after  = (0 + 100) / 1,000,000
        //           = 100 / 1,000,000
        //           = 0.0001
        //
        // price_before = 1200 * (1 + pd_before)
        //              = 1200 * (1 + 0)
        //              = 1200
        // price_after  = 1200 * (1 + pd_after)
        //              = 1200 * (1 + 0.0001)
        //              = 1200 * (1.0001)
        //              = 1200.12
        // Finally,
        //
        // fill_price = (price_before + price_after) / 2
        //            = (1200 + 1200.12) / 2
        //            = 1200.06
        if (skewScale.isZero()) {
            return price;
        }
        // calculate pd (premium/discount) before and after trade
        int256 pdBefore = skew.divDecimalToDimensionless(skewScale.toInt());
        BaseQuantoPerUSDInt256 newSkew = skew + size.to256();
        int256 pdAfter = newSkew.divDecimalToDimensionless(skewScale.toInt());

        // calculate price before and after trade with pd applied
        USDPerBaseInt256 priceBefore = price.toInt() + (price.toInt().mulDecimal(pdBefore));
        USDPerBaseInt256 priceAfter = price.toInt() + (price.toInt().mulDecimal(pdAfter));

        // the fill price is the average of those prices
        return (priceBefore + priceAfter).toUint().divDecimal(DecimalMath.UNIT * 2);
    }

    struct RequiredMarginWithNewPositionRuntime {
        QuantoUint256 newRequiredMargin;
        QuantoUint256 oldRequiredMargin;
        USDUint256 requiredMarginForNewPosition;
        USDUint256 accumulatedLiquidationRewards;
        uint256 maxNumberOfWindows;
        uint256 numberOfWindows;
        USDUint256 requiredRewardMargin;
    }

    /**
     * @notice Initial pnl of a position after it's opened due to p/d fill price delta.
     */
    function calculateStartingPnl(
        USDPerBaseUint256 fillPrice,
        USDPerBaseUint256 marketPrice,
        BaseQuantoPerUSDInt128 size
    ) internal pure returns (QuantoInt256) {
        return size.to256().mulDecimalToQuanto(marketPrice.toInt() - fillPrice.toInt());
    }

    /**
     * @notice After the required margins are calculated with the old position, this function replaces the
     * old position initial margin with the new position initial margin requirements and returns them.
     * @dev SIP-359: If the position is being reduced, required margin is 0.
     */
    function getRequiredMarginWithNewPosition(
        PerpsAccount.Data storage account,
        PerpsMarketConfiguration.Data storage marketConfig,
        uint128 marketId,
        BaseQuantoPerUSDInt128 oldPositionSize,
        BaseQuantoPerUSDInt128 newPositionSize,
        USDPerBaseUint256 fillPrice,
        USDUint256 currentTotalInitialMargin
    ) internal view returns (USDUint256) {
        RequiredMarginWithNewPositionRuntime memory runtime;

        if (oldPositionSize.isSameSideReducing(newPositionSize)) {
            return InteractionsUSDUint256.zero();
        }

        // get initial margin requirement for the new position
        (, , runtime.newRequiredMargin, ) = marketConfig.calculateRequiredMargins(
            newPositionSize,
            fillPrice
        );

        // get initial margin of old position
        (, , runtime.oldRequiredMargin, ) = marketConfig.calculateRequiredMargins(
            oldPositionSize,
            PerpsPrice.getCurrentPrice(marketId, PerpsPrice.Tolerance.DEFAULT)
        );

        USDPerQuantoUint256 quantoPrice = PerpsPrice.getCurrentQuantoPrice(marketId, PerpsPrice.Tolerance.DEFAULT);

        // remove the old initial margin and add the new initial margin requirement
        // this gets us our total required margin for new position
        runtime.requiredMarginForNewPosition =
            currentTotalInitialMargin +
            runtime.newRequiredMargin.mulDecimalToUSD(quantoPrice) -
            runtime.oldRequiredMargin.mulDecimalToUSD(quantoPrice);

        (runtime.accumulatedLiquidationRewards, runtime.maxNumberOfWindows) = account
            .getKeeperRewardsAndCosts(marketId);
        runtime.accumulatedLiquidationRewards = runtime.accumulatedLiquidationRewards + marketConfig.calculateFlagReward(
            newPositionSize.abs().mulDecimalToQuanto(fillPrice)
        ).mulDecimalToUSD(quantoPrice);

        runtime.numberOfWindows = marketConfig.numberOfLiquidationWindows(
            newPositionSize.abs()
        );
        runtime.maxNumberOfWindows = MathUtil.max(
            runtime.numberOfWindows,
            runtime.maxNumberOfWindows
        );

        runtime.requiredRewardMargin = account.getPossibleLiquidationReward(
            runtime.accumulatedLiquidationRewards,
            runtime.maxNumberOfWindows
        );

        // this is the required margin for the new position (minus any order fees)
        return runtime.requiredMarginForNewPosition + runtime.requiredRewardMargin;
    }

    /**
     * @notice Checks if the fill price exceeds the acceptable price set at submission.
     */
    function acceptablePriceExceeded(
        Data storage order,
        USDPerBaseUint256 fillPrice
    ) internal view returns (bool exceeded) {
        return
            (order.request.sizeDelta.greaterThanZero() && fillPrice > order.request.acceptablePrice) ||
            (order.request.sizeDelta.lessThanZero() && fillPrice < order.request.acceptablePrice);
    }
}
