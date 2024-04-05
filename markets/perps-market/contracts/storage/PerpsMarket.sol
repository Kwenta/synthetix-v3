//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {ERC2771Context} from "@synthetixio/core-contracts/contracts/utils/ERC2771Context.sol";
import {DecimalMath} from "@synthetixio/core-contracts/contracts/utils/DecimalMath.sol";
import {SafeCastU256, SafeCastI256, SafeCastU128} from "@synthetixio/core-contracts/contracts/utils/SafeCast.sol";
import {Position} from "./Position.sol";
import {AsyncOrder} from "./AsyncOrder.sol";
import {PerpsMarketConfiguration} from "./PerpsMarketConfiguration.sol";
import {MarketUpdate} from "./MarketUpdate.sol";
import {MathUtil} from "../utils/MathUtil.sol";
import {PerpsPrice} from "./PerpsPrice.sol";
import {Liquidation} from "./Liquidation.sol";
import {KeeperCosts} from "./KeeperCosts.sol";
import {InterestRate} from "./InterestRate.sol";
import {BaseQuantoPerUSDInt256, BaseQuantoPerUSDUint128, USDPerBaseUint256, USDPerBaseInt256, USDPerBaseUint128, USDPerQuantoUint256, QuantoInt256, BaseQuantoPerUSDUint256, QuantoUint256, BaseQuantoPerUSDInt128, USDUint256, USDInt256, InteractionsBaseQuantoPerUSDInt128, InteractionsBaseQuantoPerUSDUint256, InteractionsQuantoUint256, InteractionsBaseQuantoPerUSDInt256, InteractionsBaseQuantoPerUSDUint128, InteractionsUSDPerBaseUint256, InteractionsQuantoInt256, InteractionsUSDPerQuantoUint256, InteractionsUSDPerBaseInt256, InteractionsUSDPerBaseUint128} from '@kwenta/quanto-dimensions/src/UnitTypes.sol';

/**
 * @title Data for a single perps market
 */
library PerpsMarket {
    using DecimalMath for int256;
    using DecimalMath for uint256;
    using SafeCastI256 for int256;
    using SafeCastU256 for uint256;
    using SafeCastU128 for uint128;
    using InteractionsBaseQuantoPerUSDInt256 for BaseQuantoPerUSDInt256;
    using InteractionsBaseQuantoPerUSDInt128 for BaseQuantoPerUSDInt128;
    using InteractionsBaseQuantoPerUSDUint256 for BaseQuantoPerUSDUint256;
    using InteractionsBaseQuantoPerUSDUint128 for BaseQuantoPerUSDUint128;
    using InteractionsUSDPerQuantoUint256 for USDPerQuantoUint256;
    using InteractionsUSDPerBaseUint256 for USDPerBaseUint256;
    using InteractionsUSDPerBaseUint128 for USDPerBaseUint128;
    using InteractionsUSDPerBaseInt256 for USDPerBaseInt256;
    using InteractionsQuantoUint256 for QuantoUint256;
    using InteractionsQuantoInt256 for QuantoInt256;
    using Position for Position.Data;
    using PerpsMarketConfiguration for PerpsMarketConfiguration.Data;

    /**
     * @notice Thrown when attempting to create a market that already exists or invalid id was passed in
     */
    error InvalidMarket(uint128 marketId);

    /**
     * @notice Thrown when attempting to load a market without a configured price feed
     */
    error PriceFeedNotSet(uint128 marketId);

    /**
     * @notice Thrown when attempting to load a market without a configured keeper costs
     */
    error KeeperCostsNotSet();

    struct Data {
        string name;
        string symbol;
        uint128 id;
        BaseQuantoPerUSDInt256 skew;
        BaseQuantoPerUSDUint256 size;
        int256 lastFundingRate;
        USDPerBaseInt256 lastFundingValue;
        uint256 lastFundingTime;
        // solhint-disable-next-line var-name-mixedcase
        uint128 __unused_1;
        // solhint-disable-next-line var-name-mixedcase
        uint128 __unused_2;
        // debt calculation
        // accumulates total notional size of the market including accrued funding until the last time any position changed
        QuantoInt256 debtCorrectionAccumulator;
        // accountId => asyncOrder
        mapping(uint256 => AsyncOrder.Data) asyncOrders;
        // accountId => position
        mapping(uint256 => Position.Data) positions;
        // liquidation amounts
        Liquidation.Data[] liquidationData;
    }

    function load(uint128 marketId) internal pure returns (Data storage market) {
        bytes32 s = keccak256(abi.encode("io.synthetix.perps-market.PerpsMarket", marketId));

        assembly {
            market.slot := s
        }
    }

    function createValid(
        uint128 id,
        string memory name,
        string memory symbol
    ) internal returns (Data storage market) {
        if (id == 0 || load(id).id == id) {
            revert InvalidMarket(id);
        }

        market = load(id);

        market.id = id;
        market.name = name;
        market.symbol = symbol;
    }

    /**
     * @dev Reverts if the market does not exist with appropriate error. Otherwise, returns the market.
     */
    function loadValid(uint128 marketId) internal view returns (Data storage market) {
        market = load(marketId);
        if (market.id == 0) {
            revert InvalidMarket(marketId);
        }

        if (PerpsPrice.load(marketId).feedId == "") {
            revert PriceFeedNotSet(marketId);
        }

        if (KeeperCosts.load().keeperCostNodeId == "") {
            revert KeeperCostsNotSet();
        }
    }

    /**
     * @dev Returns the max amount of liquidation that can occur based on the market configuration
     * @notice Based on the configured liquidation window, a trader can only be liquidated for a certain
     *   amount within that window.  If the amount requested is greater than the amount allowed, the
     *   smaller amount is returned.  The function also updates its accounting to ensure the results on
     *   subsequent liquidations work appropriately.
     */
    function maxLiquidatableAmount(
        Data storage self,
        BaseQuantoPerUSDUint128 requestedLiquidationAmount
    ) internal returns (BaseQuantoPerUSDUint128 liquidatableAmount) {
        PerpsMarketConfiguration.Data storage marketConfig = PerpsMarketConfiguration.load(self.id);

        // if endorsedLiquidator is configured and is the sender, allow full liquidation
        if (ERC2771Context._msgSender() == marketConfig.endorsedLiquidator) {
            _updateLiquidationData(self, requestedLiquidationAmount);
            return requestedLiquidationAmount;
        }

        (
            BaseQuantoPerUSDUint256 liquidationCapacity,
            BaseQuantoPerUSDUint256 maxLiquidationInWindow,
            uint256 latestLiquidationTimestamp
        ) = currentLiquidationCapacity(self, marketConfig);

        // this would only occur if there was a misconfiguration (like skew scale not being set)
        // or the max liquidation window not being set etc.
        // in this case, return the entire requested liquidation amount
        if (maxLiquidationInWindow.isZero()) {
            return requestedLiquidationAmount;
        }

        uint256 maxLiquidationPd = marketConfig.maxLiquidationPd;
        // if liquidation capacity exists, update accordingly
        if (!liquidationCapacity.isZero()) {
            liquidatableAmount = liquidationCapacity.to128().min128(requestedLiquidationAmount);
        } else if (
            maxLiquidationPd != 0 &&
            // only allow this if the last update was not in the current block
            latestLiquidationTimestamp != block.timestamp
        ) {
            /**
                if capacity is at 0, but the market is under configured liquidation p/d,
                another block of liquidation becomes allowable.
             */
            uint256 currentPd = self.skew.abs().divDecimalToDimensionless(marketConfig.skewScale);
            if (currentPd < maxLiquidationPd) {
                liquidatableAmount = maxLiquidationInWindow.to128().min128(requestedLiquidationAmount);
            }
        }

        if (liquidatableAmount.greaterThanZero()) {
            _updateLiquidationData(self, liquidatableAmount);
        }
    }

    function _updateLiquidationData(Data storage self, BaseQuantoPerUSDUint128 liquidationAmount) private {
        uint256 liquidationDataLength = self.liquidationData.length;
        uint256 currentTimestamp = liquidationDataLength == 0
            ? 0
            : self.liquidationData[liquidationDataLength - 1].timestamp;

        if (currentTimestamp == block.timestamp) {
            Liquidation.Data storage liquidationData = self.liquidationData[liquidationDataLength - 1];
            liquidationData.amount = liquidationData.amount + liquidationAmount;
        } else {
            self.liquidationData.push(
                Liquidation.Data({amount: liquidationAmount, timestamp: block.timestamp})
            );
        }
    }

    /**
     * @dev Returns the current liquidation capacity for the market
     * @notice This function sums up the liquidation amounts in the current liquidation window
     * and returns the capacity left.
     */
    function currentLiquidationCapacity(
        Data storage self,
        PerpsMarketConfiguration.Data storage marketConfig
    )
        internal
        view
        returns (
            BaseQuantoPerUSDUint256 capacity,
            BaseQuantoPerUSDUint256 maxLiquidationInWindow,
            uint256 latestLiquidationTimestamp
        )
    {
        maxLiquidationInWindow = marketConfig.maxLiquidationAmountInWindow();
        BaseQuantoPerUSDUint256 accumulatedLiquidationAmounts;
        uint256 liquidationDataLength = self.liquidationData.length;
        if (liquidationDataLength == 0) return (maxLiquidationInWindow, maxLiquidationInWindow, 0);

        uint256 currentIndex = liquidationDataLength - 1;
        latestLiquidationTimestamp = self.liquidationData[currentIndex].timestamp;
        uint256 windowStartTimestamp = block.timestamp - marketConfig.maxSecondsInLiquidationWindow;

        while (self.liquidationData[currentIndex].timestamp > windowStartTimestamp) {
            Liquidation.Data storage liquidationData = self.liquidationData[currentIndex];
            accumulatedLiquidationAmounts = accumulatedLiquidationAmounts + liquidationData.amount.to256();

            if (currentIndex == 0) break;
            currentIndex--;
        }
        BaseQuantoPerUSDInt256 availableLiquidationCapacity = maxLiquidationInWindow.toInt() -
            accumulatedLiquidationAmounts.toInt();
        capacity = availableLiquidationCapacity.max(InteractionsBaseQuantoPerUSDInt256.zero()).toUint();
    }

    struct PositionDataRuntime {
        USDPerBaseUint256 currentPrice;
        BaseQuantoPerUSDInt256 sizeDelta;
        QuantoInt256 fundingDelta;
        QuantoInt256 notionalDelta;
    }

    /**
     * @dev Use this function to update both market/position size/skew.
     * @dev Size and skew should not be updated directly.
     * @dev The return value is used to emit a MarketUpdated event.
     */
    function updatePositionData(
        Data storage self,
        uint128 accountId,
        Position.Data memory newPosition
    ) internal returns (MarketUpdate.Data memory) {
        PositionDataRuntime memory runtime;
        Position.Data storage oldPosition = self.positions[accountId];

        self.size =
            (self.size + newPosition.size.abs()) -
            oldPosition.size.abs();
        self.skew = self.skew + newPosition.size.to256() - oldPosition.size.to256();

        runtime.currentPrice = newPosition.latestInteractionPrice.to256();
        (, QuantoInt256 pricePnl, , QuantoInt256 fundingPnl, , ) = oldPosition.getPnl(runtime.currentPrice);

        runtime.sizeDelta = (newPosition.size - oldPosition.size).to256();
        runtime.fundingDelta = calculateNextFunding(self, runtime.currentPrice).mulDecimalToQuanto(
            runtime.sizeDelta
        );
        runtime.notionalDelta = runtime.currentPrice.toInt().mulDecimalToQuanto(runtime.sizeDelta);

        // update the market debt correction accumulator before losing oldPosition details
        // by adding the new updated notional (old - new size) plus old position pnl
        self.debtCorrectionAccumulator =
            self.debtCorrectionAccumulator +
            runtime.fundingDelta +
            runtime.notionalDelta +
            pricePnl +
            fundingPnl;

        // update position to new position
        // Note: once market interest rate is updated, the current accrued interest is saved
        // to figure out the unrealized interest for the position
        (uint128 interestRate, uint256 currentInterestAccrued) = InterestRate.update();
        oldPosition.update(newPosition, currentInterestAccrued);

        return
            MarketUpdate.Data(
                self.id,
                interestRate,
                self.skew,
                self.size,
                self.lastFundingRate,
                currentFundingVelocity(self)
            );
    }

    function recomputeFunding(
        Data storage self,
        USDPerBaseUint256 price
    ) internal returns (int256 fundingRate, USDPerBaseInt256 fundingValue) {
        fundingRate = currentFundingRate(self);
        fundingValue = calculateNextFunding(self, price);

        self.lastFundingRate = fundingRate;
        self.lastFundingValue = fundingValue;
        self.lastFundingTime = block.timestamp;

        return (fundingRate, fundingValue);
    }

    function calculateNextFunding(
        Data storage self,
        USDPerBaseUint256 price
    ) internal view returns (USDPerBaseInt256 nextFunding) {
        nextFunding = self.lastFundingValue + unrecordedFunding(self, price);
    }

    function unrecordedFunding(Data storage self, USDPerBaseUint256 price) internal view returns (USDPerBaseInt256) {
        int256 fundingRate = currentFundingRate(self);
        // note the minus sign: funding flows in the opposite direction to the skew.
        int256 avgFundingRate = -(self.lastFundingRate + fundingRate).divDecimal(
            (DecimalMath.UNIT * 2).toInt()
        );

        return price.toInt().mulDecimal(avgFundingRate.mulDecimal(proportionalElapsed(self)));
    }

    function currentFundingRate(Data storage self) internal view returns (int256) {
        // calculations:
        //  - velocity          = proportional_skew * max_funding_velocity
        //  - proportional_skew = skew / skew_scale
        //
        // example:
        //  - prev_funding_rate     = 0
        //  - prev_velocity         = 0.0025
        //  - time_delta            = 29,000s
        //  - max_funding_velocity  = 0.025 (2.5%)
        //  - skew                  = 300
        //  - skew_scale            = 10,000
        //
        // note: prev_velocity just refs to the velocity _before_ modifying the market skew.
        //
        // funding_rate = prev_funding_rate + prev_velocity * (time_delta / seconds_in_day)
        // funding_rate = 0 + 0.0025 * (29,000 / 86,400)
        //              = 0 + 0.0025 * 0.33564815
        //              = 0.00083912
        return
            self.lastFundingRate +
            (currentFundingVelocity(self).mulDecimal(proportionalElapsed(self)));
    }

    function currentFundingVelocity(Data storage self) internal view returns (int256) {
        PerpsMarketConfiguration.Data storage marketConfig = PerpsMarketConfiguration.load(self.id);
        int256 maxFundingVelocity = marketConfig.maxFundingVelocity.toInt();
        BaseQuantoPerUSDInt256 skewScale = marketConfig.skewScale.toInt();
        // Avoid a panic due to div by zero. Return 0 immediately.
        if (skewScale.isZero()) {
            return 0;
        }
        // Ensures the proportionalSkew is between -1 and 1.
        int256 pSkew = self.skew.divDecimalToDimensionless(skewScale);
        int256 pSkewBounded = MathUtil.min(
            MathUtil.max(-(DecimalMath.UNIT).toInt(), pSkew),
            (DecimalMath.UNIT).toInt()
        );
        return pSkewBounded.mulDecimal(maxFundingVelocity);
    }

    function proportionalElapsed(Data storage self) internal view returns (int256) {
        // even though timestamps here are not D18, divDecimal multiplies by 1e18 to preserve decimals into D18
        return (block.timestamp - self.lastFundingTime).divDecimal(1 days).toInt();
    }

    function validatePositionSize(
        Data storage self,
        BaseQuantoPerUSDUint256 maxSize,
        QuantoUint256 maxValue,
        USDPerBaseUint256 price,
        BaseQuantoPerUSDInt128 oldSize,
        BaseQuantoPerUSDInt128 newSize
    ) internal view {
        // Allow users to reduce an order no matter the market conditions.
        bool isReducingInterest = oldSize.isSameSideReducing(newSize);
        if (!isReducingInterest) {
            BaseQuantoPerUSDInt256 newSkew = self.skew - oldSize.to256() + newSize.to256();

            BaseQuantoPerUSDInt256 newMarketSize = self.size.toInt() -
                oldSize.abs().toInt() +
                newSize.abs().toInt();

            BaseQuantoPerUSDInt256 newSideSize;
            if (newSize.greaterThanZero()) {
                // long case: marketSize + skew
                //            = (|longSize| + |shortSize|) + (longSize + shortSize)
                //            = 2 * longSize
                newSideSize = newMarketSize + newSkew;
            } else {
                // short case: marketSize - skew
                //            = (|longSize| + |shortSize|) - (longSize + shortSize)
                //            = 2 * -shortSize
                newSideSize = newMarketSize - newSkew;
            }

            // newSideSize still includes an extra factor of 2 here, so we will divide by 2 in the actual condition
            if (maxSize < newSideSize.div(2).abs()) {
                revert PerpsMarketConfiguration.MaxOpenInterestReached(
                    self.id,
                    maxSize,
                    newSideSize.div(2)
                );
            }

            // same check but with value (size * price)
            // note that if maxValue param is set to 0, this validation is skipped
            if (maxValue.greaterThanZero() && maxValue < newSideSize.div(2).abs().mulDecimalToQuanto(price)) {
                revert PerpsMarketConfiguration.MaxUSDOpenInterestReached(
                    self.id,
                    maxValue,
                    newSideSize.div(2),
                    price
                );
            }
        }
    }

    /**
     * @dev Returns the market debt incurred by all positions
     * @notice  Market debt is the sum of all position sizes multiplied by the price, and old positions pnl that is included in the debt correction accumulator.
     */
    function marketDebt(Data storage self, USDPerBaseUint256 price) internal view returns (USDInt256) {
        // all positions sizes multiplied by the price is equivalent to skew times price
        // and the debt correction accumulator is the  sum of all positions pnl
        QuantoInt256 positionPnl = self.skew.mulDecimalToQuanto(price.toInt());
        QuantoInt256 fundingPnl = self.skew.mulDecimalToQuanto(calculateNextFunding(self, price));

        return (positionPnl + fundingPnl - self.debtCorrectionAccumulator)
            .mulDecimalToUSD(PerpsPrice.getCurrentQuantoPrice(self.id, PerpsPrice.Tolerance.DEFAULT).toInt());
    }

    function requiredCredit(uint128 marketId) internal view returns (USDUint256) {
        return
            PerpsMarket
                .load(marketId)
                .size
                .mulDecimalToQuanto(PerpsPrice.getCurrentPrice(marketId, PerpsPrice.Tolerance.DEFAULT))
                .mulDecimalToUSD(PerpsPrice.getCurrentQuantoPrice(marketId, PerpsPrice.Tolerance.DEFAULT))
                .mulDecimal(PerpsMarketConfiguration.load(marketId).lockedOiRatioD18);
    }

    function accountPosition(
        uint128 marketId,
        uint128 accountId
    ) internal view returns (Position.Data storage position) {
        position = load(marketId).positions[accountId];
    }
}
