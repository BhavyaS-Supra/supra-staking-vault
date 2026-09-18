// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title StakingVault
/// @notice A Harvest Finance-style yield vault. Users deposit `stakeToken` and continuously
/// accrue `rewardToken` at a fixed, owner-configurable APR (basis points, of their own staked
/// balance) - not a shared pot split by pool share. Deposits and withdrawals are unlocked at
/// all times; rewards must be funded into the vault by the owner ahead of being claimed.
contract StakingVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    /// @dev Sanity cap on the configurable APR: 1000%.
    uint256 public constant MAX_APR_BPS = 100_000;
    /// @dev Precision used for the internal reward-per-token accumulator.
    uint256 private constant PRECISION = 1e18;

    IERC20 public immutable stakeToken;
    IERC20 public immutable rewardToken;

    /// @notice Current annual reward rate in basis points (e.g. 1_000 = 10% APR).
    uint256 public apr;

    /// @notice Total amount of stakeToken currently deposited in the vault.
    uint256 public totalStaked;

    /// @dev Accumulated reward per staked token, scaled by PRECISION, as of `lastUpdateTime`.
    uint256 public rewardPerTokenStored;
    /// @dev Timestamp `rewardPerTokenStored` was last brought up to date.
    uint256 public lastUpdateTime;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event AprUpdated(uint256 oldAprBps, uint256 newAprBps);
    event RewardsFunded(address indexed funder, uint256 amount);

    error ZeroAmount();
    error InsufficientBalance();
    error AprTooHigh(uint256 requested, uint256 max);

    constructor(address _stakeToken, address _rewardToken, uint256 _initialAprBps, address _owner)
        Ownable(_owner)
    {
        if (_initialAprBps > MAX_APR_BPS) revert AprTooHigh(_initialAprBps, MAX_APR_BPS);
        stakeToken = IERC20(_stakeToken);
        rewardToken = IERC20(_rewardToken);
        apr = _initialAprBps;
        lastUpdateTime = block.timestamp;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /// @notice Deposits `amount` of stakeToken and starts accruing rewards on it immediately.
    function deposit(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        totalStaked += amount;
        balanceOf[msg.sender] += amount;
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    /// @notice Withdraws `amount` of previously staked stakeToken. Callable at any time.
    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        totalStaked -= amount;
        balanceOf[msg.sender] -= amount;
        stakeToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Claims all rewardToken accrued by the caller so far.
    function claimRewards() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardsClaimed(msg.sender, reward);
        }
    }

    /// @notice Withdraws the caller's full staked balance and claims all pending rewards.
    function exit() external {
        withdraw(balanceOf[msg.sender]);
        claimRewards();
    }

    /// @notice Sets the annual reward rate going forward. Past accrual at the old rate is
    /// settled first, so changing the APR never affects rewards already earned.
    function setApr(uint256 newAprBps) external onlyOwner updateReward(address(0)) {
        if (newAprBps > MAX_APR_BPS) revert AprTooHigh(newAprBps, MAX_APR_BPS);
        emit AprUpdated(apr, newAprBps);
        apr = newAprBps;
    }

    /// @notice Pulls `amount` of rewardToken from the caller into the vault's rewards pool.
    /// @dev Caller must have approved this contract for `amount` beforehand.
    function fundRewards(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardsFunded(msg.sender, amount);
    }

    /// @notice Current reward-per-token accumulator, projected up to the current block.
    function rewardPerToken() public view returns (uint256) {
        if (block.timestamp == lastUpdateTime) return rewardPerTokenStored;
        uint256 timeDelta = block.timestamp - lastUpdateTime;
        uint256 increment = (apr * timeDelta * PRECISION) / (SECONDS_PER_YEAR * BPS_DENOMINATOR);
        return rewardPerTokenStored + increment;
    }

    /// @notice Total rewardToken earned by `account` so far, including unclaimed past rewards.
    function earned(address account) public view returns (uint256) {
        uint256 rewardPerTokenDelta = rewardPerToken() - userRewardPerTokenPaid[account];
        return rewards[account] + (balanceOf[account] * rewardPerTokenDelta) / PRECISION;
    }

    /// @notice rewardToken currently held by the vault and available to pay out claims.
    function rewardsPoolBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }
}
