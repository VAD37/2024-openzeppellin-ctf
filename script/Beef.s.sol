// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Script, console} from "forge-std/Script.sol";

import "src/Beef/src/Challenge.sol";



contract BeefScript is Script {
    uint256 privateKey = 0x1fe4eec2a51fecb47ba936411a6d375e10e6bc0c3a9883aff0838889e2829ca9;
    address target = 0xb780EEB8e65e7aF93c475e2c131cd21854d6b7E8;
    VmSafe.Wallet wallet;


    Challenge challenge;

    function setUp() public {
        wallet = vm.createWallet(privateKey);

        challenge = Challenge(target);

    }

    function run() external {
    
        vm.startBroadcast(privateKey);

// the target have 2 ETH and approve 100 token to the contract
        vm.stopBroadcast();
    }
// 0xa5d6a55a36bbef4863c1fA2b0A3d20fD68225775
// beef = 0xAb71F57c1374FF36aeDd47C30809aF788bb4f3eb
// public address 0xa5d6a55a36bbef4863c1fA2b0A3d20fD68225775
}



// 0x000000000000000000000000a5d6a55a36bbef4863c1fa2b0a3d20fd68225775
// 0x000000000000000000000000ab71f57c1374ff36aedd47c30809af788bb4f3eb

//Transfer(address,address,uint256) mint
//0x0000000000000000000000000000000000000000000000000000000000000000
//0x000000000000000000000000a5d6a55a36bbef4863c1fa2b0a3d20fd68225775
//0x0000000000000000000000000000000000000000000000000000000000000064

//Approval(address,address,uint256) approve
//0x000000000000000000000000a5d6a55a36bbef4863c1fa2b0a3d20fd68225775
//0x000000000000000000000000ab71f57c1374ff36aedd47c30809af788bb4f3eb
//0x64