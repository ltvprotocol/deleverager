// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

interface ILendingConnector {
    function getRealBorrowAssets(bool isRoundingUp, bytes calldata data) external view returns (uint256);
}
