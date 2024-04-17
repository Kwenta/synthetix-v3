//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {INodeModule} from "@synthetixio/oracle-manager/contracts/interfaces/INodeModule.sol";
import {NodeOutput} from "@synthetixio/oracle-manager/contracts/storage/NodeOutput.sol";
import {SafeCastI256} from "@synthetixio/core-contracts/contracts/utils/SafeCast.sol";
import {PerpsMarketFactory} from "./PerpsMarketFactory.sol";
import {PerpsMarketConfiguration} from "./PerpsMarketConfiguration.sol";
import {USDPerBaseUint256, USDPerQuantoUint256} from '@kwenta/quanto-dimensions/src/UnitTypes.sol';

/**
 * @title Price storage for a specific synth market.
 */
library PerpsPrice {
    using SafeCastI256 for int256;

    enum Tolerance {
        DEFAULT,
        STRICT
    }

    struct Data {
        /**
         * @dev the price feed id for the market.  this node is processed using the oracle manager which returns the price.
         * @dev the staleness tolerance is provided as a runtime argument to this feed for processing.
         */
        bytes32 feedId;
        /**
         * @dev strict tolerance in seconds, mainly utilized for liquidations.
         */
        uint256 strictStalenessTolerance;
    }

    function load(uint128 marketId) internal pure returns (Data storage price) {
        bytes32 s = keccak256(abi.encode("io.synthetix.perps-market.Price", marketId));
        assembly {
            price.slot := s
        }
    }

    function getCurrentPrice(
        uint128 marketId,
        Tolerance priceTolerance
    ) internal view returns (USDPerBaseUint256 price) {
        return USDPerBaseUint256.wrap(_getCurrentPrice(marketId, priceTolerance, false));
    }

    function getCurrentQuantoPrice(
        uint128 marketId,
        Tolerance priceTolerance
    ) internal view returns (USDPerQuantoUint256 price) {
        return USDPerQuantoUint256.wrap(_getCurrentPrice(marketId, priceTolerance, true));
    }

    function _getCurrentPrice(
        uint128 marketId,
        Tolerance priceTolerance,
        bool isQuanto
    ) internal view returns (uint256 price) {
        Data storage self = load(marketId);

        bytes32 feedId;
        if (isQuanto) {
            PerpsMarketConfiguration.Data storage config = PerpsMarketConfiguration.load(marketId);
            uint128 quantoSynthMarketId = config.quantoSynthMarketId;

            /// @dev if the quantoSynthMarketId is not set, the base asset is USD, which has a price of 1 USD per USD
            if (quantoSynthMarketId == 0) {
                return 1 ether;
            }

            /// @dev we use the sellFeedId as it is the oracle manager node id used for all non-buy transactions
            /// @dev and the quanto price is always use to convert the quanto asset to USD which is analagous to selling
            (, bytes32 sellFeedId,) = PerpsMarketFactory.load().spotMarket.getPriceData(config.quantoSynthMarketId);
            feedId = sellFeedId;
        } else {
            feedId = self.feedId;
        }

        PerpsMarketFactory.Data storage factory = PerpsMarketFactory.load();
        NodeOutput.Data memory output;
        if (priceTolerance == Tolerance.STRICT) {
            bytes32[] memory runtimeKeys = new bytes32[](1);
            bytes32[] memory runtimeValues = new bytes32[](1);
            runtimeKeys[0] = bytes32("stalenessTolerance");
            runtimeValues[0] = bytes32(self.strictStalenessTolerance);
            output = INodeModule(factory.oracle).processWithRuntime(
                feedId,
                runtimeKeys,
                runtimeValues
            );
        } else {
            output = INodeModule(factory.oracle).process(feedId);
        }

        return output.price.toUint();
    }

    function update(Data storage self, bytes32 feedId, uint256 strictStalenessTolerance) internal {
        self.feedId = feedId;
        self.strictStalenessTolerance = strictStalenessTolerance;
    }
}
