// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ManagerClone.sol";

contract EchindaTest {
    Challenge challenge;
    Token sETH;
    ManagerCloneDeployer deployer;
    ManagerCloneSimple manager;
    Token XYZ;

    address player = address(msg.sender);
    address liquidator;
    uint256 price = 2207 ether;
    uint256 constant MIN_DEBT = 3000e18;
    uint256 constant MIN_CR = 130 * ProtocolMath.ONE / 100; // 130%

    event AssertionFailed(string message);

    uint256 counter;
    address[] targets;

    constructor() {
        deployer = new ManagerCloneDeployer();
        challenge = deployer.challenge();
        sETH = deployer.sETH();
        manager = deployer.manager();
        XYZ = deployer.XYZ();
        liquidator = address(msg.sender);

        targets = new address[](10);
        targets[0] = address(deployer);
        targets[1] = address(0xCAFEBABE);
        targets[2] = address(this);
        targets[3] = address(0x10000);
        counter = 4;
        XYZ.approve(address(manager), type(uint256).max);
        sETH.approve(address(manager), type(uint256).max);
    }

    //Fix for fast echidna discover value. only use value from 0->100%
    function _fix(uint256 value, uint256 max) internal pure returns (uint256) {
        uint256 perc = value % 10001;
        return max * perc / 10000;
    }

    function manage(
        uint256 collateralDelta, //2 ETH
        bool collateralIncrease, // true
        uint256 debtDelta, // 3395 ether
        bool debtIncrease //true
    ) external {
        collateralDelta = _fix(collateralDelta, sETH.balanceOf(address(this)));        
        debtDelta = _fix(debtDelta, 1.02e25);
        manager.manage(collateralDelta, collateralIncrease, debtDelta, debtIncrease);
        _victory();
    }

    function createChildDebt(uint256 amount) external {
        require(counter < 10, "Max child debt");
        amount = _fix(amount, sETH.balanceOf(address(this)));
        ChildCollateral child = new ChildCollateral(manager);
        sETH.transfer(address(child), amount);
        uint maxDebt = amount * price / MIN_CR;
        child.manage(amount,true,maxDebt,true);
        targets[counter++] = address(child);
    }

    function _checkLiquidation() internal {
        if (manager.debtBalance(address(deployer)) == 0) {
            emit AssertionFailed("Liquidation successful");
        }
    }

    function _victory() internal {
        //goal 2.5e26
        if (XYZ.balanceOf(address(this)) > 1.02e25) {
            emit AssertionFailed("Print Money 1");
        }
    }

    function liquidate(uint8 arrayIndex) external {
        arrayIndex %= 11;
        manager.liquidate(targets[arrayIndex]);
    }

    function donateETH(uint256 amount) external {
        amount = _fix(amount, 6000 ether);
        sETH.transfer(address(manager), amount);
    }

    // function transferMysETH(uint8 array, uint256 amount) external {
    //     array %= 11;
    //     sETH.transfer(targets[array], amount);
    // }

    // function transferMyXYZ(uint8 array, uint256 amount) external {
    //     array %= 11;
    //     XYZ.transfer(targets[array], amount);
    // }

    // function test_liquidate() public {
    //     uint256 inputDebt = 3521e18;
    //     uint256 inputCollateral = 30e18;
    //     manager.manage(inputCollateral, true, inputDebt, true);
    //     manager.liquidate(address(deployer));
    //     _checkLiquidation();
    // }
}
