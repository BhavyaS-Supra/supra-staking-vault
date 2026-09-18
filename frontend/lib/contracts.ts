import type { Address } from 'viem';

function readAddress(envVar: string | undefined): Address | undefined {
  if (!envVar) return undefined;
  return envVar as Address;
}

export const STAKING_VAULT_ADDRESS = readAddress(process.env.NEXT_PUBLIC_STAKING_VAULT_ADDRESS);
export const STAKE_TOKEN_ADDRESS = readAddress(process.env.NEXT_PUBLIC_STAKE_TOKEN_ADDRESS);
export const REWARD_TOKEN_ADDRESS = readAddress(process.env.NEXT_PUBLIC_REWARD_TOKEN_ADDRESS);

export const CONTRACTS_CONFIGURED = Boolean(
  STAKING_VAULT_ADDRESS && STAKE_TOKEN_ADDRESS && REWARD_TOKEN_ADDRESS
);

export const STAKE_TOKEN_SYMBOL = process.env.NEXT_PUBLIC_STAKE_TOKEN_SYMBOL || 'sSTK';
export const REWARD_TOKEN_SYMBOL = process.env.NEXT_PUBLIC_REWARD_TOKEN_SYMBOL || 'sRWD';
export const STAKE_TOKEN_DECIMALS = Number(process.env.NEXT_PUBLIC_STAKE_TOKEN_DECIMALS) || 18;
export const REWARD_TOKEN_DECIMALS = Number(process.env.NEXT_PUBLIC_REWARD_TOKEN_DECIMALS) || 18;
