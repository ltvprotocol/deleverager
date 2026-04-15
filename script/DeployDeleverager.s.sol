// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import {Deleverager} from "../src/Deleverager.sol";
import {console} from "forge-std/console.sol";

contract DeployDeleveragerScript is Script {
    function run() external {
        address ltvAddress = vm.envAddress("LTV_ADDRESS");

        vm.startBroadcast();
        Deleverager deleverager = new Deleverager(ltvAddress);
        vm.stopBroadcast();
        console.log("Deleverager deployed at:", address(deleverager));
    }
}
