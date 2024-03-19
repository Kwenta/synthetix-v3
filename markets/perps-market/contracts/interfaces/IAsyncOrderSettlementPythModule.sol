//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {Position} from "../storage/Position.sol";
import {MarketUpdate} from "../storage/MarketUpdate.sol";
import {BaseQuantoPerUSDInt128, USDPerBaseUint256, USDUint256, QuantoUint256, QuantoInt256} from '@kwenta/quanto-dimensions/src/UnitTypes.sol';

interface IAsyncOrderSettlementPythModule {
    /**
     * @notice Gets fired when a new order is settled.
     * @param marketId Id of the market used for the trade.
     * @param accountId Id of the account used for the trade.
     * @param fillPrice Price at which the order was settled.
     * @param pnl Pnl of the previous closed position.
     * @param accruedFunding Accrued funding of the previous closed position.
     * @param sizeDelta Size delta from order.
     * @param newSize New size of the position after settlement.
     * @param totalFees Amount of fees collected by the protocol.
     * @param referralFees Amount of fees collected by the referrer.
     * @param collectedFees Amount of fees collected by fee collector.
     * @param settlementReward reward to sender for settling order.
     * @param trackingCode Optional code for integrator tracking purposes.
     * @param settler address of the settler of the order.
     */
    event OrderSettled(
        uint128 indexed marketId,
        uint128 indexed accountId,
        USDPerBaseUint256 fillPrice,
        QuantoInt256 pnl,
        QuantoInt256 accruedFunding,
        BaseQuantoPerUSDInt128 sizeDelta,
        BaseQuantoPerUSDInt128 newSize,
        USDUint256 totalFees,
        USDUint256 referralFees,
        USDUint256 collectedFees,
        USDUint256 settlementReward,
        bytes32 indexed trackingCode,
        address settler
    );

    /**
     * @notice Gets fired after order settles and includes the interest charged to the account.
     * @param accountId Id of the account used for the trade.
     * @param interest interest charges
     */
    event InterestCharged(uint128 indexed accountId, QuantoUint256 interest);

    // only used due to stack too deep during settlement
    struct SettleOrderRuntime {
        uint128 marketId;
        uint128 accountId;
        BaseQuantoPerUSDInt128 sizeDelta;
        QuantoInt256 pnl;
        QuantoUint256 chargedInterest;
        QuantoInt256 accruedFunding;
        QuantoUint256 pnlUint;
        USDUint256 amountToDeduct;
        USDUint256 settlementReward;
        USDPerBaseUint256 fillPrice;
        USDUint256 totalFees;
        USDUint256 referralFees;
        USDUint256 feeCollectorFees;
        Position.Data newPosition;
        MarketUpdate.Data updateData;
        uint256 synthDeductionIterator;
        uint128[] deductedSynthIds;
        uint256[] deductedAmount;
    }

    /**
     * @notice Settles an offchain order using the offchain retrieved data from pyth.
     * @param accountId The account id to settle the order
     */
    function settleOrder(uint128 accountId) external;
}
