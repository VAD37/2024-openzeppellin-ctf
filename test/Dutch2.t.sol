// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "src/Dutch2/src/Challenge.sol";
import "src/Dutch2/src/AuctionManager.sol";
import "src/Dutch2/src/Token.sol";

contract BankerTest is Test {
    using FixedPointMathLib for uint128;
    using SafeTransferLib for ERC20;

    Challenge challenge;
    address player = address(this);
    Token usdc;
    Token weth;
    AuctionManager auction;

    function setUp() public {
        usdc = new Token("USD Coin", "USDC", 6);
        weth = new Token("Wrapped Ethereum", "WETH", 18);

        auction = new AuctionManager();

        usdc.mint(address(auction), 10000 * 1e6);
        weth.mint(address(auction), 100 * 1e18);

        usdc.mint(player, 100 ether);
        weth.mint(player, 100 ether);

        challenge = new Challenge(auction, usdc, weth);

        usdc.approve(address(auction), type(uint256).max);
        weth.approve(address(auction), type(uint256).max);
    }

    function testSolve() public {
        //create bid
        _createNewBid();
    }

    function _createNewBid() internal returns (uint256 id) {
        AuctionManager.Time memory time = AuctionManager.Time({
            start: uint32(block.timestamp),
            end: uint32(block.timestamp + 10),
            startVesting: uint32(block.timestamp + 20),
            endVesting: uint32(block.timestamp + 30),
            cliff: uint128(0) // cliff <= 1e18
        });
        AuctionManager.AuctionParameters memory params = AuctionManager.AuctionParameters({
            tokenBase: address(usdc),
            tokenQuote: address(weth),//This ask for weth in exchange for usdc
            resQuoteBase: 10e18,
            totalBase: 100e6, //@token transferd in for auction
            minBid: 0, // minBid * uint128 / totalBase < resQuoteBase // uint128 = 3.4e38
            merkle: bytes32(0),
            publicKey: Math.Point(0, 0)
        });
        id = auction.create(params, time);
    }
}
