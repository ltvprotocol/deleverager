// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import {Deleverager} from "../src/Deleverager.sol";
import {console} from "forge-std/console.sol";

address constant EMERGENCY_DELEVERAGER = 0x029B9362b5Ee78A673848eb025b533856dD8DDAA;

contract DeployDeleveragerScript is Script {
    function run() external {
        address ltvAddress = vm.envAddress("LTV_ADDRESS");

        vm.startBroadcast();
        Deleverager deleverager = new Deleverager{salt: ""}(ltvAddress, EMERGENCY_DELEVERAGER);
        vm.stopBroadcast();
        console.log("Deleverager deployed at:", address(deleverager));
    }
}
