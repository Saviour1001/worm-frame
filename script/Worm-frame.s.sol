// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

contract WormFrameScript is Script {
    function setUp() public {}

    function run() public {
        // uint privateKey = vm.evmUint("PRIVATE_KEY");
        vm.startBroadcast();

        vm.stopBroadcast();
    }
}
