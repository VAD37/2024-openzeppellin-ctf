// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ProtocolMath} from "./ProtocolMath.sol";
import {Token, IERC20} from "./Token.sol";
import {Ownable} from "./ManagerAccess.sol";

contract Challenge {
    Token public immutable xyz;
    Token public immutable seth;
    ManagerCloneSimple public immutable manager;

    constructor(Token _xyz, Token _seth, ManagerCloneSimple _manager) {
        xyz = _xyz;
        seth = _seth;
        manager = _manager;
    }

    function isSolved() external view returns (bool) {
        return xyz.balanceOf(address(0xCAFEBABE)) == 250_000_000 ether;
    }
}

contract ManagerCloneDeployer {
    Challenge public challenge;
    Token public sETH;
    ManagerCloneSimple public manager;
    Token public XYZ;

    address public player = address(msg.sender);

    constructor() {
        address system = address(this);
        sETH = new Token(system, "sETH");
        manager = new ManagerCloneSimple(address(sETH));
        XYZ = manager.xyz();
        challenge = new Challenge(XYZ, sETH, manager);
        manager.addCollateralToken(20_000_000_000_000_000 ether, 1 ether);
        sETH.mint(system, 2 ether);
        sETH.approve(address(manager), type(uint256).max);

        manager.manage(2 ether, true, 3395 ether, true);

        manager.updateDebtSignal(3520 ether);

        sETH.mint(player, 6000 ether);
    }
}
contract ChildCollateral {
    ManagerCloneSimple public manager;
    constructor(ManagerCloneSimple _manager) {
        manager = _manager;
    }
    function manage( uint256 collateralDelta, //2 ETH
        bool collateralIncrease, // true
        uint256 debtDelta, // 3395 ether
        bool debtIncrease ) external {
        manager.manage(collateralDelta, collateralIncrease, debtDelta, debtIncrease);
        manager.xyz().transfer(msg.sender, manager.xyz().balanceOf(address(this)));
        manager.sETH().transfer(msg.sender, manager.sETH().balanceOf(address(this)));
    }
}
contract ManagerCloneSimple is Ownable {
    using ProtocolMath for uint256;

    uint256 public constant MIN_DEBT = 3000e18;
    uint256 public constant MIN_CR = 130 * ProtocolMath.ONE / 100; // 130%

    Token public immutable xyz;

    IERC20 public immutable sETH;
    uint256 debtTotalSupply;
    mapping(address => uint256) public debtBalance;
    uint256 collateralTotalSupply;
    mapping(address => uint256) public collateralBalance;
    uint256 debtSignal;// 1.01e18
    uint256 collateralSignal;//2e34
    uint256 price = 2207 ether;

    error NothingToLiquidate();
    error CannotLiquidateLastPosition();
    error RedemptionSpreadOutOfRange();
    error NoCollateralOrDebtChange();
    error InvalidPosition();
    error NewICRLowerThanMCR(uint256 newICR);
    error NetDebtBelowMinimum(uint256 netDebt);
    error FeeExceedsMaxFee(uint256 fee, uint256 amount, uint256 maxFeePercentage);
    error PositionCollateralTokenMismatch();
    error CollateralTokenAlreadyAdded();
    error CollateralTokenNotAdded();
    error SplitLiquidationCollateralCannotBeZero();
    error WrongCollateralParamsForFullRepayment();

    constructor(address _sETH) Ownable(msg.sender) {
        xyz = new Token(address(this), "XYZ");
        sETH = IERC20(_sETH);
    }

    function manage(
        uint256 collateralDelta, //2 ETH = 4414 USD
        bool collateralIncrease, // true
        uint256 debtDelta, // 3395 USD = 4414 / 1.3
        bool debtIncrease //true
    ) external returns (uint256, uint256) {
        if (collateralDelta == 0 && debtDelta == 0) {
            revert NoCollateralOrDebtChange();
        }

        uint256 debtBefore = balanceOfDebt(msg.sender); //share * 1e18/signal
        if (!debtIncrease && (debtDelta == type(uint256).max || (debtBefore != 0 && debtDelta == debtBefore))) {
            if (collateralDelta != 0 || collateralIncrease) {
                revert WrongCollateralParamsForFullRepayment();
            }
            collateralDelta = balanceOfCollateral(msg.sender);
            debtDelta = debtBefore;
        }

        _updateDebt(debtDelta, debtIncrease);
        _updateCollateral(collateralDelta, collateralIncrease);

        uint256 debt = balanceOfDebt(msg.sender); // 3395e18
        uint256 collateral = balanceOfCollateral(msg.sender); //1e2

        if (debt == 0) {
            if (collateral != 0) {
                revert InvalidPosition();
            }
            _closePosition(msg.sender, false);
        } else {
            _checkPosition(debt, collateral);
        }
        return (collateralDelta, debtDelta);
    }

    function liquidate(address liquidatee) external {
        uint256 wholeCollateral = balanceOfCollateral(liquidatee); //@share * 1e18/signal
        uint256 wholeDebt = balanceOfDebt(liquidatee); //@share * 1e18/signal
        //@health == collateral * price / debt
        uint256 health = ProtocolMath._computeHealth(wholeCollateral, wholeDebt, price);

        if (health >= MIN_CR) {
            revert NothingToLiquidate();
        }

        uint256 totalDebt = totalDebtSupply();
        if (wholeDebt == totalDebt) {
            revert CannotLiquidateLastPosition();
        }

        if (!(health <= ProtocolMath.ONE)) {
            xyz.burn(msg.sender, wholeDebt);
            totalDebt -= wholeDebt;
        }

        sETH.transfer(msg.sender, wholeCollateral);

        _closePosition(liquidatee, true);

        _updateSignals(totalDebt);
    }

    function addCollateralToken(uint256 _collateralSignal, uint256 _debtSignal)
        external
        onlyOwner //@debtSignal = 1e18
    {
        collateralSignal = _collateralSignal;//2e34
        debtSignal = _debtSignal;//1e18
    }

    function _updateDebt(uint256 debtDelta, bool debtIncrease) internal {
        if (debtDelta == 0) {
            return;
        }
        if (debtIncrease) {//@first debt. user get 3395 token
            mintDebt(msg.sender, debtDelta);//3395 USD // amount * 1e18/1.01e18
            xyz.mint(msg.sender, debtDelta);//3395 XYZ
        } else {
            burnDebt(msg.sender, debtDelta);//  amount * 1e18 /1.01e18
            xyz.burn(msg.sender, debtDelta);
        }
    }

    function _updateCollateral(uint256 collateralDelta, bool collateralIncrease) internal {
        if (collateralDelta == 0) {
            return;
        }

        if (collateralIncrease) {// 2 ETH
            mintCollateral(msg.sender, collateralDelta); // share = amount * 1e18/2e34 = 1e2 token
            sETH.transferFrom(msg.sender, address(this), collateralDelta);
        } else {
            burnCollateral(msg.sender, collateralDelta);// share = amount * 1e18/2e34 = 1e2 token
            sETH.transfer(msg.sender, collateralDelta);
        }
    }

    function _updateSignals(uint256 totalDebtForCollateral) internal {
        {
            uint256 amount = totalDebtForCollateral;//@totalDebtSupply() = OlddebtTotalSupply * signal / 1e18
            uint256 supply = debtTotalSupply;
            uint256 newSignal = (amount == 0 && supply == 0) ? ProtocolMath.ONE : amount.divUp(supply); //signal = OlddebtTotalSupply * signal /1e18 * 1e18 / AfterdebtTotalSupply
            debtSignal = newSignal;
        }

        {
            uint256 amount = sETH.balanceOf(address(this));
            uint256 supply = collateralTotalSupply;
            uint256 newSignal = (amount == 0 && supply == 0) ? ProtocolMath.ONE : amount.divUp(supply);
            collateralSignal = newSignal;
        }
    }

    function updateDebtSignal(uint256 backingAmount) external onlyOwner {
        uint256 supply = debtTotalSupply;
        uint256 newSignal = (backingAmount == 0 && supply == 0) ? ProtocolMath.ONE : backingAmount.divUp(supply);
        debtSignal = newSignal;
    }

    function _closePosition(address target, bool burn) internal {
        if (burn) {
            burnDebt(target, type(uint256).max);
            burnCollateral(target, type(uint256).max);
        }
    }

    function _checkPosition(uint256 debt, uint256 collateral) internal view {
        if (debt < MIN_DEBT) {//@3000 USD minimum debt
            //@3395e18
            revert NetDebtBelowMinimum(debt);
        }
        uint256 health = ProtocolMath._computeHealth(collateral, debt, price); //health  = collateral * price / debt = 1e2 * 2207e18 / 3395e18

        if (health < MIN_CR) {
            //< 1.3e18
            revert NewICRLowerThanMCR(health);
        }
    }

    receive() external payable {}

    function mintDebt(address account, uint256 amount) internal {//amount == 3395e18
        uint256 value = amount.divUp(debtSignal);// amount * 1e18/1.e18
        debtTotalSupply += value;
        debtBalance[account] += value;
    }

    function burnDebt(address account, uint256 amount) internal {
        uint256 value = amount == type(uint256).max ? debtBalance[account] : amount.divUp(debtSignal);
        debtTotalSupply -= value;
        debtBalance[account] -= value;
    }

    function mintCollateral(address account, uint256 amount) internal {
        uint256 value = amount.divUp(collateralSignal);
        collateralTotalSupply += value;
        collateralBalance[account] += value;
    }

    function burnCollateral(address account, uint256 amount) internal {
        uint256 value = amount == type(uint256).max ? collateralBalance[account] : amount.divUp(collateralSignal);
        collateralTotalSupply -= value;
        collateralBalance[account] -= value;
    }

    function balanceOfDebt(address account) internal view returns (uint256) {
        return debtBalance[account].mulDown(debtSignal);
    }

    function totalDebtSupply() internal view returns (uint256) {
        return debtTotalSupply.mulDown(debtSignal);// share * signal / 1e18
    }

    function balanceOfCollateral(address account) internal view returns (uint256) {
        return collateralBalance[account].mulDown(collateralSignal);// balance = share * signal / 1e18
    }

    function totalCollateralSupply() internal view returns (uint256) {
        return collateralTotalSupply.mulDown(collateralSignal);// balance = share * signal / 1e18
    }
}
