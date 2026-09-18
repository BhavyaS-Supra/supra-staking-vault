Next.js frontend for the Supra Staking Vault, built with viem + wagmi.

## Setup

```bash
pnpm install
cp .env.local.example .env.local
```

Fill in `.env.local` with the addresses printed by the `contracts/script/Deploy*.s.sol` scripts
(vault, stake token, reward token), and the RPC URL/chain ID for whichever network you deployed
to (Supra EVM Devnet by default; set `NEXT_PUBLIC_SUPRA_EVM_CHAIN_ID=11155111` for Sepolia).

```bash
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000).

## What's here

- `app/page.tsx` — the vault page
- `components/VaultCard.tsx` — deposit/withdraw tabs, staked balance, pending rewards, claim, APR
- `components/ConnectWallet.tsx` — StarKey-first wallet connection with a MetaMask fallback and wrong-network handling
- `hooks/useVault.ts` — reads (APR, balances, allowance, pending rewards) and writes (approve, deposit, withdraw, claim)
- `config/chains.ts` / `config/wagmi.ts` — Supra EVM Devnet chain definition and wagmi config
- `lib/abi/*.json` — ABIs exported from the Foundry build (`forge inspect ... abi --json`)

Regenerate the ABIs after changing a contract:

```bash
cd ../contracts
forge inspect src/StakingVault.sol:StakingVault abi --json > ../frontend/lib/abi/StakingVault.json
```
