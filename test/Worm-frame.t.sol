// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import {WormFrame} from "../src/Worm-frame.sol";

import "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract WormFrameTest is WormholeRelayerBasicTest {
    WormFrame public helloSource;
    WormFrame public helloTarget;

    ERC20Mock public token;

    function setUpSource() public override {
        helloSource = new WormFrame(
            address(relayerSource),
            address(tokenBridgeSource),
            address(wormholeSource)
        );

        token = createAndAttestToken(sourceChain);
    }

    function setUpTarget() public override {
        helloTarget = new WormFrame(
            address(relayerTarget),
            address(tokenBridgeTarget),
            address(wormholeTarget)
        );
    }

    function testRemoteNativeDeposit() public {
        uint256 amount = 19e17;

        vm.selectFork(targetFork);
        address recipient = 0x1234567890123456789012345678901234567890;

        vm.selectFork(sourceFork);
        uint256 cost = helloSource.quoteCrossChainDeposit(targetChain);

        address wethAddress = address(tokenBridgeSource.WETH());

        vm.recordLogs();
        helloSource.sendNativeCrossChainDeposit{value: cost + amount}(
            targetChain, address(helloTarget), recipient, amount
        );
        performDelivery();

        vm.selectFork(targetFork);
        address wormholeWrappedToken = tokenBridgeTarget.wrappedAsset(sourceChain, toWormholeFormat(wethAddress));
        assertEq(IERC20(wormholeWrappedToken).balanceOf(recipient), amount);


        console.log("cost", cost);
        console.log("amount", amount);
        console.log("targetChain", targetChain);
        console.log("helloTarget", address(helloTarget));
        console.log("balance after briding", IERC20(wormholeWrappedToken).balanceOf(recipient));
        

        console.log("recipient", recipient);

    }
}
