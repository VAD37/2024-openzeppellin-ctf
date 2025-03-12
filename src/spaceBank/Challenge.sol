// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "src/spaceBank/SpaceBank.sol";

contract Challenge {
    SpaceBank public immutable SPACEBANK;

    constructor(SpaceBank spacebank) {
        SPACEBANK = spacebank;
    }

    function isSolved() external view returns (bool) {
        return SPACEBANK.exploded();
    }
}
