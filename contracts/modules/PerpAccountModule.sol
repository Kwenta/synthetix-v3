//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {Account} from "@synthetixio/main/contracts/storage/Account.sol";
import {PerpMarket} from "../storage/PerpMarket.sol";
import {Position} from "../storage/Position.sol";
import {Margin} from "../storage/Margin.sol";
import {PerpMarketConfiguration} from "../storage/PerpMarketConfiguration.sol";
import "../interfaces/IPerpAccountModule.sol";

contract PerpAccountModule is IPerpAccountModule {
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;

    /**
     * @inheritdoc IPerpAccountModule
     */
    function getAccountDigest(
        uint128 accountId,
        uint128 marketId
    ) external view returns (IPerpAccountModule.AccountDigest memory digest) {
        Account.exists(accountId);
        PerpMarket.Data storage market = PerpMarket.exists(marketId);

        Margin.GlobalData storage globalMarginConfig = Margin.load();
        Margin.Data storage accountMargin = Margin.load(accountId, marketId);

        uint256 length = globalMarginConfig.supportedAddresses.length;
        IPerpAccountModule.DepositedCollateral[] memory collateral = new DepositedCollateral[](length);

        for (uint256 i = 0; i < length; ) {
            address collateralType = globalMarginConfig.supportedAddresses[i];
            collateral[i] = IPerpAccountModule.DepositedCollateral(
                collateralType,
                accountMargin.collaterals[collateralType],
                Margin.getOraclePrice(collateralType)
            );
            unchecked {
                i++;
            }
        }

        Position.Data storage position = market.positions[accountId];
        digest = IPerpAccountModule.AccountDigest(
            collateral,
            Margin.getNotionalValueUsd(accountId, marketId),
            market.orders[accountId],
            position,
            position.getHealthFactor(
                market,
                Margin.getMarginUsd(accountId, market),
                market.getOraclePrice(),
                PerpMarketConfiguration.load(marketId)
            )
        );
    }

    /**
     * @inheritdoc IPerpAccountModule
     */
    function getPositionDigest(
        uint128 accountId,
        uint128 marketId
    ) external view returns (IPerpAccountModule.PositionDigest memory digest) {
        // TODO: Implement me
    }
}
