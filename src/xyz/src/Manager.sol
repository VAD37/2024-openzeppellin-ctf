// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

import {ProtocolMath} from "./helpers/ProtocolMath.sol";
import {ERC20Signal} from "./ERC20Signal.sol";
import {Token} from "./Token.sol";
import {PriceFeed} from "./PriceFeed.sol";
import {console} from "forge-std/Test.sol";

contract Manager is Ownable {
    using SafeERC20 for IERC20;
    using ProtocolMath for uint256;

    uint256 public constant MIN_DEBT = 3000e18;
    uint256 public constant MIN_CR = 130 * ProtocolMath.ONE / 100; // 130%
    uint256 public constant DECAY_FACTOR = 999_027_758_833_783_000;

    Token public immutable xyz;

    mapping(address => IERC20) public positionCollateral;
    mapping(IERC20 => Collateral) public collateralData;

    struct Collateral {
        ERC20Signal protocolCollateralToken;
        ERC20Signal protocolDebtToken;
        PriceFeed priceFeed;
        uint256 operationTime;
        uint256 baseRate;
    }

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

    constructor() Ownable(msg.sender) {
        xyz = new Token(address(this), "XYZ");
    }

    function manage(
        IERC20 token, //sETH
        uint256 collateralDelta, //2 ETH
        bool collateralIncrease, // true
        uint256 debtDelta, // 3395 ether
        bool debtIncrease //true
    ) external returns (uint256, uint256) {
        if (address(collateralData[token].protocolCollateralToken) == address(0)) {
            revert CollateralTokenNotAdded();
        }

        if (positionCollateral[msg.sender] != IERC20(address(0)) && positionCollateral[msg.sender] != token) {
            revert PositionCollateralTokenMismatch();
        }

        if (collateralDelta == 0 && debtDelta == 0) {
            revert NoCollateralOrDebtChange();
        }

        Collateral memory collateralTokenInfo = collateralData[token];
        ERC20Signal protocolCollateralToken = collateralTokenInfo.protocolCollateralToken;
        ERC20Signal protocolDebtToken = collateralTokenInfo.protocolDebtToken;

        uint256 debtBefore = protocolDebtToken.balanceOf(msg.sender); //share * 1e18/signal
        if (!debtIncrease && (debtDelta == type(uint256).max || (debtBefore != 0 && debtDelta == debtBefore))) {
            if (collateralDelta != 0 || collateralIncrease) {
                revert WrongCollateralParamsForFullRepayment();
            }
            collateralDelta = protocolCollateralToken.balanceOf(msg.sender);
            debtDelta = debtBefore;
        }

        _updateDebt(token, protocolDebtToken, debtDelta, debtIncrease);
        _updateCollateral(token, protocolCollateralToken, collateralDelta, collateralIncrease);

        uint256 debt = protocolDebtToken.balanceOf(msg.sender); // 3395e18
        uint256 collateral = protocolCollateralToken.balanceOf(msg.sender); //1e2 //@audit the answer lie at deltaCollateral not same as collateral balance
        console.log("manage debt: %e, debtBalance: %e", debtDelta, debt);//(a * b) / ONE
        console.log("manage collateral: %e, collateralBalance: %e", collateralDelta, collateral);
        if (debt == 0) {
            if (collateral != 0) {
                revert InvalidPosition();
            }
            console.log("debt  0, closing position");
            _closePosition(protocolCollateralToken, protocolDebtToken, msg.sender, false);
        } else {
            console.log("Check Position, debt: %e, coll: %e ", debt, collateral);
            _checkPosition(token, debt, collateral);

            if (debtBefore == 0) {
                positionCollateral[msg.sender] = token;
            }
        }
        return (collateralDelta, debtDelta);
    }

    function liquidate(address liquidatee) external {
        IERC20 token = positionCollateral[liquidatee];

        if (address(token) == address(0)) {
            revert NothingToLiquidate();
        }

        Collateral memory collateralTokenInfo = collateralData[token];
        ERC20Signal protocolCollateralToken = collateralTokenInfo.protocolCollateralToken;
        ERC20Signal protocolDebtToken = collateralTokenInfo.protocolDebtToken;

        uint256 wholeCollateral = protocolCollateralToken.balanceOf(liquidatee);//@share * 1e18/signal
        uint256 wholeDebt = protocolDebtToken.balanceOf(liquidatee); //@share * 1e18/signal

        (uint256 price,) = collateralTokenInfo.priceFeed.fetchPrice();
        uint256 health = ProtocolMath._computeHealth(wholeCollateral, wholeDebt, price);
        console.log("whole debt: %e, whole collateral: %e, health: %e", wholeDebt, wholeCollateral, health);
        if (health >= MIN_CR) {
            revert NothingToLiquidate();
        }

        uint256 totalDebt = protocolDebtToken.totalSupply();
        if (wholeDebt == totalDebt) {
            revert CannotLiquidateLastPosition();
        }
        console.log("whole debt: %e, total debt: %e", wholeDebt, totalDebt);
        if (!(health <= ProtocolMath.ONE)) {
            console.log("health > 1, burn sender debt: %e ", xyz.balanceOf(address(msg.sender)));
            xyz.burn(msg.sender, wholeDebt);
            totalDebt -= wholeDebt;
        }

        token.safeTransfer(msg.sender, wholeCollateral);

        _closePosition(protocolCollateralToken, protocolDebtToken, liquidatee, true);

        _updateSignals(token, protocolCollateralToken, protocolDebtToken, totalDebt);
    }

    function addCollateralToken(IERC20 token, PriceFeed priceFeed, uint256 collateralSignal, uint256 debtSignal)
        external
        onlyOwner //@debtSignal = 1e18
    {
        console.log("add collateral, debt signal: %e, collateral signal: %e", debtSignal, collateralSignal); //1e18
        //@ collateralSignal = 20_000_000_000_000_000e18
        ERC20Signal protocolCollateralToken = new ERC20Signal(
            address(this),
            collateralSignal, //20_000_000_000_000_000e18
            string(bytes.concat("XYZ ", bytes(IERC20Metadata(address(token)).name()), " collateral")),
            string(bytes.concat("xyz", bytes(IERC20Metadata(address(token)).symbol()), "-c"))
        );
        ERC20Signal protocolDebtToken = new ERC20Signal(
            address(this),
            debtSignal, //1e18
            string(bytes.concat("XYZ ", bytes(IERC20Metadata(address(token)).name()), " debt")),
            string(bytes.concat("xyz", bytes(IERC20Metadata(address(token)).symbol()), "-d"))
        );

        if (address(collateralData[token].protocolCollateralToken) != address(0)) {
            revert CollateralTokenAlreadyAdded();
        }

        Collateral memory protocolCollateralTokenInfo;
        protocolCollateralTokenInfo.protocolCollateralToken = protocolCollateralToken;
        protocolCollateralTokenInfo.protocolDebtToken = protocolDebtToken;
        protocolCollateralTokenInfo.priceFeed = priceFeed;

        collateralData[token] = protocolCollateralTokenInfo;
    }

    function _updateDebt(IERC20 token, ERC20Signal protocolDebtToken, uint256 debtDelta, bool debtIncrease) internal {
        if (debtDelta == 0) {
            return;
        }
        uint256 before = protocolDebtToken.RealbalanceOf(msg.sender);
        if (debtIncrease) {
            _decayRate(token);
            protocolDebtToken.mint(msg.sender, debtDelta);
            xyz.mint(msg.sender, debtDelta);
            console.log("Debt mint: %e, Out %e", debtDelta, protocolDebtToken.RealbalanceOf(msg.sender) - before);
        } else {
            protocolDebtToken.burn(msg.sender, debtDelta);
            console.log("Debt burn: %e, Out %e", debtDelta, before - protocolDebtToken.RealbalanceOf(msg.sender));
            xyz.burn(msg.sender, debtDelta);
        }
    }

    function _updateCollateral(
        IERC20 token,
        ERC20Signal protocolCollateralToken,
        uint256 collateralDelta,
        bool collateralIncrease
    ) internal {
        if (collateralDelta == 0) {
            return;
        }
        uint256 before = protocolCollateralToken.RealbalanceOf(msg.sender);
        if (collateralIncrease) {
            protocolCollateralToken.mint(msg.sender, collateralDelta);
            token.safeTransferFrom(msg.sender, address(this), collateralDelta);
            console.log(
                "Collateral mint: %e, Out %e", collateralDelta, protocolCollateralToken.RealbalanceOf(msg.sender) - before
            );
        } else {
            protocolCollateralToken.burn(msg.sender, collateralDelta);
            token.safeTransfer(msg.sender, collateralDelta);
            console.log(
                "Collateral burn: %e, Out %e", collateralDelta, before - protocolCollateralToken.RealbalanceOf(msg.sender)
            );
        }
    }

    function _updateSignals(
        IERC20 token,
        ERC20Signal protocolCollateralToken,
        ERC20Signal protocolDebtToken,
        uint256 totalDebtForCollateral
    ) internal {
        console.log("updateDebtSignals: %e ", totalDebtForCollateral);
        protocolDebtToken.setSignal(totalDebtForCollateral);
        console.log("updateCollateralSignals: %e", token.balanceOf(address(this)) );
        protocolCollateralToken.setSignal(token.balanceOf(address(this)));
    }

    function updateSignal(ERC20Signal token, uint256 signal) external onlyOwner {
        token.setSignal(signal);
    }

    function _closePosition(
        ERC20Signal protocolCollateralToken,
        ERC20Signal protocolDebtToken,
        address position,
        bool burn
    ) internal {
        positionCollateral[position] = IERC20(address(0));
        console.log("closing position: %s", position);
        if (burn) {
            // console.log("burn debt %e, signal: %e", protocolDebtToken.balanceOf(position), protocolDebtToken.signal());
            protocolDebtToken.burn(position, type(uint256).max);
            // console.log("burn collateral %e, signal: %e", protocolCollateralToken.balanceOf(position), protocolCollateralToken.signal());
            protocolCollateralToken.burn(position, type(uint256).max);
        }
    }

    function _decayRate(IERC20 token) internal {
        uint256 decayedRate = _calcDecayedRate(token);
        require(decayedRate <= ProtocolMath.ONE);

        collateralData[token].baseRate = decayedRate;

        _updateOperationTime(token);
    }

    function _updateOperationTime(IERC20 token) internal {
        uint256 pastTime = block.timestamp - collateralData[token].operationTime;

        if (1 minutes <= pastTime) {
            collateralData[token].operationTime = block.timestamp;
        }
    }

    function _calcDecayedRate(IERC20 token) internal view returns (uint256) {
        uint256 pastMinutes = (block.timestamp - collateralData[token].operationTime) / 1 minutes;
        uint256 decay = ProtocolMath._decPow(DECAY_FACTOR, pastMinutes);

        return collateralData[token].baseRate.mulDown(decay);
    }

    function _checkPosition(IERC20 token, uint256 debt, uint256 collateral) internal view {
        if (debt < MIN_DEBT) {
            //@3395e18
            revert NetDebtBelowMinimum(debt);
        } //       uint256 debt = protocolDebtToken.balanceOf(msg.sender);
       // uint256 collateral = protocolCollateralToken.balanceOf(msg.sender);

        (uint256 price,) = collateralData[token].priceFeed.fetchPrice(); //(2207 ether, 0.01 ether)
        uint256 health = ProtocolMath._computeHealth(collateral, debt, price); //health  = collateral * price / debt = 1e2 * 2207e18 / 3395e18

        console.log("debt: %e, collateral %e , health: %e", debt, collateral, health); //1.300147275405007363e18
        // console.log("max debt: %e", collateral * price / MIN_CR);
        if (health < MIN_CR) {
            //< 1.3e18
            revert NewICRLowerThanMCR(health);
        }
    }
    function globalHealth(IERC20 token) external view returns (uint256) {
        Collateral memory collateralTokenInfo = collateralData[token];
        ERC20Signal protocolCollateralToken = collateralTokenInfo.protocolCollateralToken;
        ERC20Signal protocolDebtToken = collateralTokenInfo.protocolDebtToken;
        uint256 debt = protocolDebtToken.totalSupply();
        uint256 collateral = protocolCollateralToken.totalSupply();
        (uint256 price,) = collateralTokenInfo.priceFeed.fetchPrice();
        uint256 health = ProtocolMath._computeHealth(collateral, debt, price);
        return health;
    }
    receive() external payable {}
}
