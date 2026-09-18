// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RewardTokenTest is Test {
    RewardToken public token;
    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");

    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        vm.prank(owner);
        token = new RewardToken(owner, INITIAL_SUPPLY);
    }

    function test_Constructor_MintsInitialSupplyToOwner() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.owner(), owner);
        assertEq(token.name(), "Supra Reward Token");
        assertEq(token.symbol(), "sRWD");
    }

    function test_Mint_OwnerCanMint() public {
        vm.prank(owner);
        token.mint(alice, 500 ether);
        assertEq(token.balanceOf(alice), 500 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 500 ether);
    }

    function test_RevertWhen_Mint_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.mint(alice, 500 ether);
    }

    function test_Transfer() public {
        vm.prank(owner);
        token.transfer(alice, 100 ether);
        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - 100 ether);
    }

    function testFuzz_Mint(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max - INITIAL_SUPPLY);
        vm.prank(owner);
        token.mint(alice, amount);
        assertEq(token.balanceOf(alice), amount);
    }
}
