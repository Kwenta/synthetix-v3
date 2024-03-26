//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {BaseQuantoPerUSDInt256, BaseQuantoPerUSDUint256} from "@kwenta/quanto-dimensions/src/UnitTypes.sol";

/**
 * @title MarketUpdateData
 */
library MarketUpdate {
    // this data struct returns the data required to emit a MarketUpdated event
    struct Data {
        uint128 marketId;
        uint128 interestRate;
        BaseQuantoPerUSDInt256 skew;
        BaseQuantoPerUSDUint256 size;
        int256 currentFundingRate;
        int256 currentFundingVelocity;
    }
}
