# Staking Vault Contracts

Foundry project for the Harvest Finance-style staking vault.

- `src/StakingVault.sol` — deposit/withdraw/claimRewards, owner-configurable APR (basis points), pull-based reward funding
- `src/StakeToken.sol` — mintable test ERC-20 staked into the vault
- `src/RewardToken.sol` — mintable ERC-20 distributed as yield

## Usage

```shell
# Build
forge build

# Test (44 tests: unit, fuzz, event, and revert coverage)
forge test

# Test with traces
forge test -vvvv

# Gas report
forge test --gas-report
```

## Deploying

Copy `.env.example` to `.env` and fill in `PRIVATE_KEY` plus the RPC URL for your target network.

```shell
# Ethereum Sepolia
forge script script/DeploySepolia.s.sol --rpc-url sepolia --broadcast --private-key $PRIVATE_KEY

# Supra EVM Devnet
forge script script/DeploySupraDevnet.s.sol --rpc-url supra_evm_devnet --broadcast --private-key $PRIVATE_KEY
```

Each script deploys `StakeToken`, `RewardToken`, and `StakingVault` (10% initial APR by default,
override with the `INITIAL_APR_BPS` env var), then funds the vault's rewards pool with 100,000
reward tokens from the deployer. Copy the three logged addresses into `frontend/.env.local`.

## Exporting ABIs

```shell
forge inspect src/StakingVault.sol:StakingVault abi --json > ../frontend/lib/abi/StakingVault.json
forge inspect src/StakeToken.sol:StakeToken abi --json > ../frontend/lib/abi/StakeToken.json
forge inspect src/RewardToken.sol:RewardToken abi --json > ../frontend/lib/abi/RewardToken.json
```
