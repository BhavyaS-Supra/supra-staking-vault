// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {StakingVault} from "../src/StakingVault.sol";
import {StakeToken} from "../src/StakeToken.sol";
import {RewardToken} from "../src/RewardToken.sol";

contract StakingVaultTest is Test {
    StakingVault public vault;
    StakeToken public stakeToken;
    RewardToken public rewardToken;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public constant INITIAL_APR_BPS = 1_000; // 10%
    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        vm.startPrank(owner);
        stakeToken = new StakeToken(owner, INITIAL_SUPPLY);
        rewardToken = new RewardToken(owner, INITIAL_SUPPLY);
        vault = new StakingVault(address(stakeToken), address(rewardToken), INITIAL_APR_BPS, owner);

        // Fund the rewards pool generously so claim tests aren't gated on pool size.
        rewardToken.approve(address(vault), INITIAL_SUPPLY);
        vault.fundRewards(100_000 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        stakeToken.mint(alice, 10_000 ether);
        stakeToken.mint(bob, 10_000 ether);
        vm.stopPrank();

        vm.prank(alice);
        stakeToken.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        stakeToken.approve(address(vault), type(uint256).max);
    }

    // ---------------------------------------------------------------------
    // Deployment
    // ---------------------------------------------------------------------

    function test_Constructor_SetsState() public view {
        assertEq(address(vault.stakeToken()), address(stakeToken));
        assertEq(address(vault.rewardToken()), address(rewardToken));
        assertEq(vault.apr(), INITIAL_APR_BPS);
        assertEq(vault.owner(), owner);
        assertEq(vault.totalStaked(), 0);
    }

    function test_RevertWhen_ConstructorAprTooHigh() public {
        uint256 maxApr = vault.MAX_APR_BPS();
        vm.expectRevert(abi.encodeWithSelector(StakingVault.AprTooHigh.selector, maxApr + 1, maxApr));
        new StakingVault(address(stakeToken), address(rewardToken), maxApr + 1, owner);
    }

    // ---------------------------------------------------------------------
    // Deposit
    // ---------------------------------------------------------------------

    function test_Deposit_UpdatesBalancesAndTotalStaked() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);

        assertEq(vault.balanceOf(alice), 1_000 ether);
        assertEq(vault.totalStaked(), 1_000 ether);
        assertEq(stakeToken.balanceOf(address(vault)), 1_000 ether);
        assertEq(stakeToken.balanceOf(alice), 9_000 ether);
    }

    function test_Deposit_EmitsEvent() public {
        vm.expectEmit(true, false, false, true, address(vault));
        emit StakingVault.Deposited(alice, 1_000 ether);
        vm.prank(alice);
        vault.deposit(1_000 ether);
    }

    function test_Deposit_MultipleUsers() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        vm.prank(bob);
        vault.deposit(2_000 ether);

        assertEq(vault.balanceOf(alice), 1_000 ether);
        assertEq(vault.balanceOf(bob), 2_000 ether);
        assertEq(vault.totalStaked(), 3_000 ether);
    }

    function test_RevertWhen_DepositZero() public {
        vm.prank(alice);
        vm.expectRevert(StakingVault.ZeroAmount.selector);
        vault.deposit(0);
    }

    function test_RevertWhen_DepositWithoutApproval() public {
        vm.prank(alice);
        stakeToken.approve(address(vault), 0);
        vm.prank(alice);
        vm.expectRevert();
        vault.deposit(1_000 ether);
    }

    function testFuzz_Deposit(uint256 amount) public {
        amount = bound(amount, 1, 10_000 ether);
        vm.prank(alice);
        vault.deposit(amount);
        assertEq(vault.balanceOf(alice), amount);
        assertEq(vault.totalStaked(), amount);
    }

    // ---------------------------------------------------------------------
    // Withdraw
    // ---------------------------------------------------------------------

    function test_Withdraw_UpdatesBalancesAndTotalStaked() public {
        vm.startPrank(alice);
        vault.deposit(1_000 ether);
        vault.withdraw(400 ether);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 600 ether);
        assertEq(vault.totalStaked(), 600 ether);
        assertEq(stakeToken.balanceOf(alice), 9_400 ether);
    }

    function test_Withdraw_EmitsEvent() public {
        vm.startPrank(alice);
        vault.deposit(1_000 ether);
        vm.expectEmit(true, false, false, true, address(vault));
        emit StakingVault.Withdrawn(alice, 400 ether);
        vault.withdraw(400 ether);
        vm.stopPrank();
    }

    function test_Withdraw_FullBalance_AnyTime() public {
        vm.startPrank(alice);
        vault.deposit(1_000 ether);
        skip(1 days);
        vault.withdraw(1_000 ether);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.totalStaked(), 0);
    }

    function test_RevertWhen_WithdrawZero() public {
        vm.prank(alice);
        vm.expectRevert(StakingVault.ZeroAmount.selector);
        vault.withdraw(0);
    }

    function test_RevertWhen_WithdrawMoreThanBalance() public {
        vm.startPrank(alice);
        vault.deposit(1_000 ether);
        vm.expectRevert(StakingVault.InsufficientBalance.selector);
        vault.withdraw(1_001 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawWithNoDeposit() public {
        vm.prank(alice);
        vm.expectRevert(StakingVault.InsufficientBalance.selector);
        vault.withdraw(1 ether);
    }

    // ---------------------------------------------------------------------
    // Reward accrual
    // ---------------------------------------------------------------------

    function test_Earned_AccruesLinearlyOverOneYear() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);

        skip(SECONDS_PER_YEAR());

        // 10% APR of 1,000 ether over exactly one year = 100 ether.
        assertApproxEqAbs(vault.earned(alice), 100 ether, 1);
    }

    function test_Earned_ZeroImmediatelyAfterDeposit() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        assertEq(vault.earned(alice), 0);
    }

    function test_Earned_ProportionalToStakeAndTime() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        vm.prank(bob);
        vault.deposit(3_000 ether);

        skip(SECONDS_PER_YEAR());

        assertApproxEqAbs(vault.earned(alice), 100 ether, 1);
        assertApproxEqAbs(vault.earned(bob), 300 ether, 1);
    }

    function test_Earned_IndependentPerUser_LateDepositEarnsLess() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);

        skip(SECONDS_PER_YEAR() / 2);

        vm.prank(bob);
        vault.deposit(1_000 ether);

        skip(SECONDS_PER_YEAR() / 2);

        // Alice staked the full year: ~100 ether. Bob staked only the second half: ~50 ether.
        assertApproxEqAbs(vault.earned(alice), 100 ether, 1);
        assertApproxEqAbs(vault.earned(bob), 50 ether, 1);
    }

    function test_Earned_UnaffectedByOtherUsersDepositingOrWithdrawing() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);

        skip(SECONDS_PER_YEAR() / 2);
        uint256 aliceEarnedBefore = vault.earned(alice);

        vm.startPrank(bob);
        vault.deposit(5_000 ether);
        vault.withdraw(5_000 ether);
        vm.stopPrank();

        assertEq(vault.earned(alice), aliceEarnedBefore);
    }

    function test_WithdrawPartial_PreservesAccruedRewards() public {
        vm.startPrank(alice);
        vault.deposit(1_000 ether);
        skip(SECONDS_PER_YEAR());
        vault.withdraw(400 ether);
        vm.stopPrank();

        // Rewards earned before the withdrawal must not be lost.
        assertApproxEqAbs(vault.earned(alice), 100 ether, 1);
    }

    // ---------------------------------------------------------------------
    // claimRewards
    // ---------------------------------------------------------------------

    function test_ClaimRewards_TransfersRewardTokenAndZeroesPending() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        skip(SECONDS_PER_YEAR());

        uint256 earnedBefore = vault.earned(alice);
        vm.prank(alice);
        vault.claimRewards();

        assertEq(rewardToken.balanceOf(alice), earnedBefore);
        assertEq(vault.earned(alice), 0);
        assertEq(vault.rewards(alice), 0);
    }

    function test_ClaimRewards_EmitsEvent() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        skip(SECONDS_PER_YEAR());

        uint256 earnedBefore = vault.earned(alice);
        vm.expectEmit(true, false, false, true, address(vault));
        emit StakingVault.RewardsClaimed(alice, earnedBefore);
        vm.prank(alice);
        vault.claimRewards();
    }

    function test_ClaimRewards_NoopWhenNothingEarned() public {
        vm.prank(alice);
        vault.claimRewards();
        assertEq(rewardToken.balanceOf(alice), 0);
    }

    function test_ClaimRewards_ThenContinuesAccruing() public {
        vm.startPrank(alice);
        vault.deposit(1_000 ether);
        skip(SECONDS_PER_YEAR());
        vault.claimRewards();
        skip(SECONDS_PER_YEAR());
        vm.stopPrank();

        assertApproxEqAbs(vault.earned(alice), 100 ether, 1);
    }

    function test_RevertWhen_ClaimRewards_PoolUnderfunded() public {
        vm.prank(owner);
        StakingVault thinVault = new StakingVault(address(stakeToken), address(rewardToken), INITIAL_APR_BPS, owner);

        vm.prank(alice);
        stakeToken.approve(address(thinVault), type(uint256).max);
        vm.prank(alice);
        thinVault.deposit(1_000 ether);

        skip(SECONDS_PER_YEAR());

        vm.prank(alice);
        vm.expectRevert();
        thinVault.claimRewards();
    }

    // ---------------------------------------------------------------------
    // exit
    // ---------------------------------------------------------------------

    function test_Exit_WithdrawsAllAndClaims() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        skip(SECONDS_PER_YEAR());

        vm.prank(alice);
        vault.exit();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(stakeToken.balanceOf(alice), 10_000 ether);
        assertApproxEqAbs(rewardToken.balanceOf(alice), 100 ether, 1);
    }

    // ---------------------------------------------------------------------
    // setApr
    // ---------------------------------------------------------------------

    function test_SetApr_UpdatesRateGoingForward() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        skip(SECONDS_PER_YEAR() / 2);

        vm.prank(owner);
        vault.setApr(2_000); // 20% APR

        skip(SECONDS_PER_YEAR() / 2);

        // First half year at 10% (~50 ether) + second half year at 20% (~100 ether) = ~150 ether.
        assertApproxEqAbs(vault.earned(alice), 150 ether, 1);
    }

    function test_SetApr_EmitsEvent() public {
        vm.expectEmit(false, false, false, true, address(vault));
        emit StakingVault.AprUpdated(INITIAL_APR_BPS, 2_000);
        vm.prank(owner);
        vault.setApr(2_000);
    }

    function test_RevertWhen_SetApr_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.setApr(2_000);
    }

    function test_RevertWhen_SetApr_ExceedsMax() public {
        uint256 maxApr = vault.MAX_APR_BPS();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StakingVault.AprTooHigh.selector, maxApr + 1, maxApr));
        vault.setApr(maxApr + 1);
    }

    function test_SetApr_ToZero_StopsAccrual() public {
        vm.prank(alice);
        vault.deposit(1_000 ether);
        vm.prank(owner);
        vault.setApr(0);

        skip(SECONDS_PER_YEAR());

        assertEq(vault.earned(alice), 0);
    }

    // ---------------------------------------------------------------------
    // fundRewards
    // ---------------------------------------------------------------------

    function test_FundRewards_TransfersIntoVault() public {
        uint256 poolBefore = vault.rewardsPoolBalance();

        vm.startPrank(owner);
        rewardToken.approve(address(vault), 5_000 ether);
        vault.fundRewards(5_000 ether);
        vm.stopPrank();

        assertEq(vault.rewardsPoolBalance(), poolBefore + 5_000 ether);
    }

    function test_FundRewards_EmitsEvent() public {
        vm.startPrank(owner);
        rewardToken.approve(address(vault), 5_000 ether);
        vm.expectEmit(true, false, false, true, address(vault));
        emit StakingVault.RewardsFunded(owner, 5_000 ether);
        vault.fundRewards(5_000 ether);
        vm.stopPrank();
    }

    function test_FundRewards_CallableByAnyone() public {
        vm.prank(owner);
        rewardToken.mint(alice, 100 ether);
        vm.startPrank(alice);
        rewardToken.approve(address(vault), 100 ether);
        vault.fundRewards(100 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_FundRewardsZero() public {
        vm.prank(owner);
        vm.expectRevert(StakingVault.ZeroAmount.selector);
        vault.fundRewards(0);
    }

    // ---------------------------------------------------------------------
    // helpers
    // ---------------------------------------------------------------------

    function SECONDS_PER_YEAR() internal view returns (uint256) {
        return vault.SECONDS_PER_YEAR();
    }
}
