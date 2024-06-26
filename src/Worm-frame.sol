// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-solidity-sdk/WormholeRelayerSDK.sol";
import "wormhole-solidity-sdk/interfaces/IERC20.sol";
import "wormhole-solidity-sdk/interfaces/IWETH.sol";
import "forge-std/console.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract WormFrame is TokenSender, TokenReceiver, Ownable {
    uint256 constant GAS_LIMIT = 250_000;

    constructor(address _wormholeRelayer, address _tokenBridge, address _wormhole)
        TokenBase(_wormholeRelayer, _tokenBridge, _wormhole)
        Ownable()
    {}

    struct SendInfo {
        uint16 targetChainId;
        uint256 amount;
    }

    uint256 public commonFrameFee;
    mapping(uint16 => uint256) public chainFrameFee;

    function estimateFees(uint16 targetChainID) public view returns (uint256 nativeFee) {
        nativeFee = quoteCrossChainDeposit(targetChainID);
        nativeFee += chainFrameFee[targetChainID] + commonFrameFee;
    }

    function setFrameFee(uint256 _commonFrameFee, uint16[] calldata chainIds, uint256[] calldata fees)
        external
        onlyOwner
    {
        commonFrameFee = _commonFrameFee;
        for (uint256 i = 0; i < chainIds.length; i++) {
            chainFrameFee[chainIds[i]] = fees[i];
        }
    }

    function useWormframe(SendInfo[] calldata sendInfos, address receiver, address targetToken) public payable {
        uint256 totalFee;
        uint256 totalAmount; 

        for (uint256 i = 0; i < sendInfos.length; i++) {
            SendInfo calldata sendInfo = sendInfos[i];
            totalFee += estimateFees(sendInfo.targetChainId);
            totalAmount += sendInfo.amount;
        }

        console.log("totalFee from the contract", totalFee);  
        console.log("totalAmount from the contract", totalAmount);

        require(msg.value == totalFee + totalAmount, "msg.value must be totalFee + totalAmount");

        for (uint256 i = 0; i < sendInfos.length; i++) {
            SendInfo calldata sendInfo = sendInfos[i];
            sendNativeCrossChainDeposit(sendInfo.targetChainId, targetToken , receiver, sendInfo.amount);
        }

    }

    // wormhole internal functions

    function quoteCrossChainDeposit(uint16 targetChain) public view returns (uint256 cost) {
        // Cost of delivering token and payload to targetChain
        uint256 deliveryCost;
        (deliveryCost,) = wormholeRelayer.quoteEVMDeliveryPrice(targetChain, 0, GAS_LIMIT);

        // Total cost: delivery cost + cost of publishing the 'sending token' wormhole message
        cost = deliveryCost + wormhole.messageFee();
    }

    function sendNativeCrossChainDeposit(
        uint16 targetChain,
        address targetHelloToken,
        address recipient,
        uint256 amount
    ) public payable returns (uint256 cost) {
        console.log("targetChain", targetChain);
        console.log("targetHelloToken", targetHelloToken);
        console.log("recipient", recipient);
        console.log("amount", amount);

        cost = estimateFees(targetChain);
        require(msg.value == cost + amount, "msg.value must be quoteCrossChainDeposit(targetChain) + amount");

        IWETH wrappedNativeToken = tokenBridge.WETH();
        wrappedNativeToken.deposit{value: amount}();

        bytes memory payload = abi.encode(recipient);
        sendTokenWithPayloadToEvm(
            targetChain,
            targetHelloToken, // address (on targetChain) to send token and payload to
            payload,
            0, // receiver value
            GAS_LIMIT,
            address(wrappedNativeToken), // address of IERC20 token contract
            amount
        );
    }

    function receivePayloadAndTokens(
        bytes memory payload,
        TokenReceived[] memory receivedTokens,
        bytes32, // sourceAddress
        uint16,
        bytes32 // deliveryHash
    ) internal override onlyWormholeRelayer {
        require(receivedTokens.length == 1, "Expected 1 token transfers");

        address recipient = abi.decode(payload, (address));

        IERC20(receivedTokens[0].tokenAddress).transfer(recipient, receivedTokens[0].amount);
    }


    function withdraw(address token, uint256 amount) external onlyOwner {
        bool s;
        if (token == address(0)) {
            (s, ) = msg.sender.call{value: amount}("");
        } else {
            (s, ) = token.call(
                abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    msg.sender,
                    amount
                )
            );
        }
        require(s, "Withdraw Failed");
    }

}
