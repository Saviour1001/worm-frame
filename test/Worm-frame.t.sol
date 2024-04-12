// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {WormFrame} from "../src/Worm-frame.sol";
import "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract WormFrameTest is WormholeRelayerBasicTest {
    WormFrame public frameSource;
    WormFrame public frameTarget;

    ERC20Mock public token;

    function setUpSource() public override {
        frameSource = new WormFrame(address(relayerSource), address(tokenBridgeSource), address(wormholeSource));

        token = createAndAttestToken(sourceChain);
    }

    function setUpTarget() public override {
        frameTarget = new WormFrame(address(relayerTarget), address(tokenBridgeTarget), address(wormholeTarget));
    }

    function testGetOwner() public {
        assertEq(address(frameSource.owner()), address(this));
    }

    function testSetFrameFee() public {
        uint256 commonFrameFee = 100;
        uint16[] memory chainIds = new uint16[](1);
        uint256[] memory fees = new uint256[](1);
        chainIds[0] = targetChain;
        fees[0] = 200;

        frameSource.setFrameFee(commonFrameFee, chainIds, fees);

        assertEq(frameSource.commonFrameFee(), commonFrameFee);
        assertEq(frameSource.chainFrameFee(targetChain), fees[0]);
    }

    function testEstimateFees() public {
        uint256 commonFrameFee = 100;
        uint16[] memory chainIds = new uint16[](1);
        uint256[] memory fees = new uint256[](1);
        chainIds[0] = targetChain;
        fees[0] = 200;

        frameSource.setFrameFee(commonFrameFee, chainIds, fees);

        uint256 nativeFee = frameSource.estimateFees(targetChain);
        uint256 expected = frameSource.quoteCrossChainDeposit(targetChain) + commonFrameFee + fees[0];
        assertEq(nativeFee, expected);
    }

    function testRemoteNativeDeposit() public {
        uint256 amount = 19e17;

        vm.selectFork(targetFork);
        address recipient = 0x1234567890123456789012345678901234567890;

        vm.selectFork(sourceFork);
        uint256 cost = frameSource.estimateFees(targetChain);

        address wethAddress = address(tokenBridgeSource.WETH());

        vm.recordLogs();
        frameSource.sendNativeCrossChainDeposit{value: cost + amount}(
            targetChain, address(frameTarget), recipient, amount
        );
        performDelivery();

        vm.selectFork(targetFork);
        address wormholeWrappedToken = tokenBridgeTarget.wrappedAsset(sourceChain, toWormholeFormat(wethAddress));
        assertEq(IERC20(wormholeWrappedToken).balanceOf(recipient), amount);

    }


    function testUseWormframe() public {

        testSetFrameFee();
        uint256 amount = 19e17;

        vm.selectFork(targetFork);
        address recipient = 0x1234567890123456789012345678901234567890;

       


        vm.selectFork(sourceFork);
        uint256 cost = frameSource.estimateFees(targetChain);

        console.log("cost", cost);

        address wethAddress = address(tokenBridgeSource.WETH());

        vm.recordLogs();
        
        WormFrame.SendInfo[] memory sendInfos = new WormFrame.SendInfo[](1);
        sendInfos[0] = WormFrame.SendInfo({
            targetChainId: targetChain,
            amount: amount
        });
        
        // console.log("Before sending balance", IERC20(wormholeWrappedToken).balanceOf(recipient));
        frameSource.useWormframe{value: cost + amount}(sendInfos, recipient, address(frameTarget));
        
        
        
        performDelivery();
        
        vm.selectFork(targetFork);
        address wormholeWrappedToken = tokenBridgeTarget.wrappedAsset(sourceChain, toWormholeFormat(wethAddress));
        assertEq(IERC20(wormholeWrappedToken).balanceOf(recipient), amount);

        console.log("After sending balance", IERC20(wormholeWrappedToken).balanceOf(recipient));
    }

   

}
