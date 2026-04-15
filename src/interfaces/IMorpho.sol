// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

interface IMorpho {
    function flashLoan(address token, uint256 amount, bytes calldata data) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 amount, bytes calldata data) external;
}
