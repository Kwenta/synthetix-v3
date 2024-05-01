//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;
import {BaseQuantoPerUSDInt128, BaseQuantoPerUSDInt256,  BaseQuantoPerUSDUint256, USDPerBaseUint256} from '@kwenta/quanto-dimensions/src/UnitTypes.sol';

/**
 * @title Perps market module
 */
interface IPerpsMarketModule {
    /**
     * @notice Market Summary structured data.
     */
    struct MarketSummary {
        // @dev Skew of the market in units of native asse
        BaseQuantoPerUSDInt256 skew;
        // @dev Size of the market in units of native asset
        BaseQuantoPerUSDUint256 size;
        // @dev Max open interest of the market in units of quanto*base/usd
        BaseQuantoPerUSDUint256 maxOpenInterest;
        // @dev Current funding rate of the market
        int256 currentFundingRate;
        // @dev Current funding velocity of the market
        int256 currentFundingVelocity;
        // @dev Index price of the market
        USDPerBaseUint256 indexPrice;
    }

    /**
     * @notice Gets a market metadata.
     * @param marketId Id of the market.
     * @return name Name of the market.
     * @return symbol Symbol of the market.
     */
    function metadata(
        uint128 marketId
    ) external view returns (string memory name, string memory symbol);

    /**
     * @notice Gets a market's skew.
     * @param marketId Id of the market.
     * @return skew Skew of the market.
     */
    function skew(uint128 marketId) external view returns (BaseQuantoPerUSDInt256);

    /**
     * @notice Gets a market's size.
     * @param marketId Id of the market.
     * @return size Size of the market.
     */
    function size(uint128 marketId) external view returns (BaseQuantoPerUSDUint256);

    /**
     * @notice Gets a market's max open interest.
     * @param marketId Id of the market.
     * @return maxOpenInterest Max open interest of the market.
     */
    function maxOpenInterest(uint128 marketId) external view returns (BaseQuantoPerUSDUint256);

    /**
     * @notice Gets a market's current funding rate.
     * @param marketId Id of the market.
     * @return currentFundingRate Current funding rate of the market.
     */
    function currentFundingRate(uint128 marketId) external view returns (int256);

    /**
     * @notice Gets a market's current funding velocity.
     * @param marketId Id of the market.
     * @return currentFundingVelocity Current funding velocity of the market.
     */
    function currentFundingVelocity(uint128 marketId) external view returns (int256);

    /**
     * @notice Gets a market's index price.
     * @param marketId Id of the market.
     * @return indexPrice Index price of the market.
     */
    function indexPrice(uint128 marketId) external view returns (USDPerBaseUint256);

    /**
     * @notice Gets a market's fill price for a specific order size and index price.
     * @param marketId Id of the market.
     * @param orderSize Order size.
     * @param price Index price.
     * @return price Fill price.
     */
    function fillPrice(
        uint128 marketId,
        BaseQuantoPerUSDInt128 orderSize,
        USDPerBaseUint256 price
    ) external view returns (USDPerBaseUint256);

    /**
     * @notice Given a marketId return a market's summary details in one call.
     * @param marketId Id of the market.
     * @return summary Market summary (see MarketSummary).
     */
    function getMarketSummary(
        uint128 marketId
    ) external view returns (MarketSummary memory summary);
}
