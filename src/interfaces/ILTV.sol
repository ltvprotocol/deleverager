// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

interface ILTV {
    function totalAssets() external view returns (uint256);
    function lendingConnector() external view returns (address);
    function lendingConnectorGetterData() external view returns (bytes memory);
    function maxDeleverageFeeDividend() external view returns (uint16);
    function maxDeleverageFeeDivider() external view returns (uint16);
    function deleverageAndWithdraw(uint256 closeAmountBorrow, uint16 deleverageFeeDividend, uint16 deleverageFeeDivider)
        external;
}
