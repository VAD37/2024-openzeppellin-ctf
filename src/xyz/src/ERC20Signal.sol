// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

import {ManagerAccess} from "./helpers/ManagerAccess.sol";
import {ProtocolMath} from "./helpers/ProtocolMath.sol";
import {console} from "forge-std/Test.sol";

contract ERC20Signal is ERC20, ManagerAccess {
    using ProtocolMath for uint256;

    uint256 public signal;

    constructor(address _manager, uint256 _signal, string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        ManagerAccess(_manager)
    {
        signal = _signal;
    }

    function mint(address to, uint256 amount) external onlyManager {
        _mint(to, amount.divUp(signal));//@ amount * 1e18 /2e34 . this mean mint 1e16 does not give any token
    }

    function burn(address from, uint256 amount) external onlyManager {
        uint256 value = amount == type(uint256).max ? ERC20.balanceOf(from) : amount.divUp(signal);
        _burn(from, value);
    }

    function setSignal(uint256 backingAmount) external onlyManager {
        uint256 supply = ERC20.totalSupply();
        uint256 newSignal = (backingAmount == 0 && supply == 0) ? ProtocolMath.ONE : backingAmount.divUp(supply);
        console.log("newSignal: %e, backing: %e, supply: %e", newSignal, backingAmount, supply);// collateralSignal = totalETH * 1e18 / totalShare
        signal = newSignal;//@signal = (totalDebt - burnDebt)
    }

    function totalSupply() public view override returns (uint256) {
        return ERC20.totalSupply().mulDown(signal);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return ERC20.balanceOf(account).mulDown(signal);
    }

    function RealbalanceOf(address account) public view returns (uint256) {
        return ERC20.balanceOf(account);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert();
    }

    function allowance(address, address) public view virtual override returns (uint256) {
        revert();
    }

    function approve(address, uint256) public virtual override returns (bool) {
        revert();
    }

    function transferFrom(address, address, uint256) public virtual override returns (bool) {
        revert();
    }

    function increaseAllowance(address, uint256) public virtual returns (bool) {
        revert();
    }

    function decreaseAllowance(address, uint256) public virtual returns (bool) {
        revert();
    }
}
