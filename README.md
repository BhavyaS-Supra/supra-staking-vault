# Supra Staking Vault

A Harvest Finance-style yield vault for Supra EVM (and Ethereum Sepolia). Users deposit an
ERC-20 stake token and continuously earn a reward token at an owner-configurable APR; deposits
and withdrawals are unlocked at all times.

```
supra-staking-vault/
├── contracts/    # Foundry: StakingVault, StakeToken, RewardToken + tests + deploy scripts
└── frontend/     # Next.js + viem + wagmi: connect wallet, deposit/withdraw, claim rewards
```

## Contracts

See [`contracts/README.md`](contracts/README.md). Quick start:

```shell
cd contracts
forge test
```

## Frontend

See [`frontend/README.md`](frontend/README.md). Quick start:

```shell
pnpm install
pnpm --filter frontend dev
```

Fill in `frontend/.env.local` (copy from `frontend/.env.local.example`) with the addresses
printed by the deploy scripts before connecting a wallet.

## How rewards accrue

`StakingVault` tracks a `rewardPerToken` accumulator that increases every second by
`apr * dt / (365 days * 10_000)`, independent of `totalStaked`. Each staker's rewards therefore
scale only with their own balance and the time it was staked — not with how many other users are
in the pool. The owner funds the vault's reward pool by transferring reward tokens in via
`fundRewards`, and can adjust the APR at any time with `setApr`; past accrual is always settled
at the old rate before the new rate takes effect.
