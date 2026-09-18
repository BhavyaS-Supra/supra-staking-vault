// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {StakingVault} from "../src/StakingVault.sol";
import {StakeToken} from "../src/StakeToken.sol";
import {RewardToken} from "../src/RewardToken.sol";

/// @notice Deploys StakeToken, RewardToken and StakingVault to the Supra EVM devnet, then funds
/// the vault's rewards pool from the deployer. Run with:
///   forge script script/DeploySupraDevnet.s.sol --rpc-url supra_evm_devnet --broadcast --private-key $PRIVATE_KEY
contract DeploySupraDevnet is Script {
    /// @dev Initial APR in basis points (1_000 = 10%). Override with INITIAL_APR_BPS env var.
    uint256 internal constant DEFAULT_APR_BPS = 1_000;
    uint256 internal constant STAKE_TOKEN_SUPPLY = 1_000_000 ether;
    uint256 internal constant REWARD_TOKEN_SUPPLY = 1_000_000 ether;
    uint256 internal constant REWARD_FUND_AMOUNT = 100_000 ether;

    function run() external returns (StakeToken stakeToken, RewardToken rewardToken, StakingVault vault) {
        uint256 aprBps = vm.envOr("INITIAL_APR_BPS", DEFAULT_APR_BPS);
        address deployer = msg.sender;

        vm.startBroadcast();

        stakeToken = new StakeToken(deployer, STAKE_TOKEN_SUPPLY);
        console.log("StakeToken deployed to:", address(stakeToken));

        rewardToken = new RewardToken(deployer, REWARD_TOKEN_SUPPLY);
        console.log("RewardToken deployed to:", address(rewardToken));

        vault = new StakingVault(address(stakeToken), address(rewardToken), aprBps, deployer);
        console.log("StakingVault deployed to:", address(vault));
        console.log("Initial APR (bps):", aprBps);

        rewardToken.approve(address(vault), REWARD_FUND_AMOUNT);
        vault.fundRewards(REWARD_FUND_AMOUNT);
        console.log("Funded rewards pool with:", REWARD_FUND_AMOUNT);

        vm.stopBroadcast();

        console.log("---");
        console.log("SupraScan MultiVM explorer: https://multivm.suprascan.io/address/", address(vault));
    }
}
