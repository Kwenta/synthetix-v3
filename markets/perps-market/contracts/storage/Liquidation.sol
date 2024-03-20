//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {BaseQuantoPerUSDUint128} from '@kwenta/quanto-dimensions/src/UnitTypes.sol';

/**
 * @title Liquidation data used for determining max liquidation amounts
 */
library Liquidation {
    struct Data {
        /**
         * @dev Accumulated amount for this corresponding timestamp
         */
        BaseQuantoPerUSDUint128 amount;
        /**
         * @dev timestamp of the accumulated liqudation amount
         */
        uint256 timestamp;
    }
}
