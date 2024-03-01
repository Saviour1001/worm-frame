// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-solidity-sdk/WormholeRelayerSDK.sol";
import "wormhole-solidity-sdk/interfaces/IERC20.sol";
import "wormhole-solidity-sdk/interfaces/IWETH.sol";
import "forge-std/console.sol";

contract WormFrame is TokenSender, TokenReceiver {
    uint256 constant GAS_LIMIT = 250_000;

    constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    ) TokenBase(_wormholeRelayer, _tokenBridge, _wormhole) {}

    string constant avalanche_testnet_relayer =
        "0xA3cF45939bD6260bcFe3D66bc73d60f19e49a8BB";
    string constant celo_testnet_relayer =
        "0x306B68267Deb7c5DfCDa3619E22E9Ca39C374f84";

    struct SendInfo {
        uint16 targetChainId;
        uint256 amount;
    }

    uint256 commonFrameFee;
    mapping(uint16 => uint256) chainFrameFee;

    function estimateFees(
        uint16 targetChainID
    ) public view returns (uint256 nativeFee) {
        nativeFee = quoteCrossChainDeposit(targetChainID);
        nativeFee += chainFrameFee[targetChainID] + commonFrameFee;
    }

    function setFrameFee(
        uint256 _commonFrameFee,
        uint16[] calldata chainIds,
        uint256[] calldata fees
    ) external {
        commonFrameFee = _commonFrameFee;
        for (uint i = 0; i < chainIds.length; i++) {
            chainFrameFee[chainIds[i]] = fees[i];
        }
    }

    // wormhole internal function

    function quoteCrossChainDeposit(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        // Cost of delivering token and payload to targetChain
        uint256 deliveryCost;
        (deliveryCost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );

        // Total cost: delivery cost + cost of publishing the 'sending token' wormhole message
        cost = deliveryCost + wormhole.messageFee();
    }

    function sendNativeCrossChainDeposit(
        uint16 targetChain,
        address targetHelloToken,
        address recipient,
        uint256 amount
    ) internal {
        console.log("targetChain", targetChain);
        console.log("targetHelloToken", targetHelloToken);
        console.log("recipient", recipient);
        console.log("amount", amount);

        uint256 cost = quoteCrossChainDeposit(targetChain);
        require(
            msg.value == cost + amount,
            "msg.value must be quoteCrossChainDeposit(targetChain) + amount"
        );

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

        IERC20(receivedTokens[0].tokenAddress).transfer(
            recipient,
            receivedTokens[0].amount
        );
    }
}
