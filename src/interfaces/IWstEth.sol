// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

interface IWstEth {
    function unwrap(uint256 wstEthAmount) external returns (uint256 stEthAmount);
    function wrap(uint256 stEthAmount) external returns (uint256 wstEthAmount);
}
