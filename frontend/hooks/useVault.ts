'use client';

import { useEffect } from 'react';
import { useAccount, useReadContract, useReadContracts, useWaitForTransactionReceipt } from 'wagmi';
import { STAKING_VAULT_ADDRESS, STAKE_TOKEN_ADDRESS, CONTRACTS_CONFIGURED } from '@/lib/contracts';
import stakingVaultAbi from '@/lib/abi/StakingVault.json';
import erc20Abi from '@/lib/abi/StakeToken.json';
import { useWriteContractWithGas } from './useWriteContractWithGas';

const REFRESH_INTERVAL_MS = 10_000;

/// Reads the caller's vault position (staked balance, pending rewards) plus vault-wide stats
/// (APR, total staked, rewards pool balance) and the caller's stake-token allowance/balance.
/// Polls on an interval so numbers keep advancing even without a new transaction.
export function useVaultReads() {
  const { address } = useAccount();

  const vault = {
    address: STAKING_VAULT_ADDRESS,
    abi: stakingVaultAbi,
  } as const;

  const { data, refetch, isLoading } = useReadContracts({
    contracts: [
      { ...vault, functionName: 'apr' },
      { ...vault, functionName: 'totalStaked' },
      { ...vault, functionName: 'rewardsPoolBalance' },
      { ...vault, functionName: 'balanceOf', args: address ? [address] : undefined },
      { ...vault, functionName: 'earned', args: address ? [address] : undefined },
    ],
    query: {
      enabled: CONTRACTS_CONFIGURED,
      refetchInterval: REFRESH_INTERVAL_MS,
    },
  });

  const { data: stakeTokenBalance, refetch: refetchStakeBalance } = useReadContract({
    address: STAKE_TOKEN_ADDRESS,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: Boolean(CONTRACTS_CONFIGURED && address) },
  });

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: STAKE_TOKEN_ADDRESS,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && STAKING_VAULT_ADDRESS ? [address, STAKING_VAULT_ADDRESS] : undefined,
    query: { enabled: Boolean(CONTRACTS_CONFIGURED && address) },
  });

  const [apr, totalStaked, rewardsPoolBalance, stakedBalance, pendingRewards] = (data ?? []).map((d) => d?.result);

  function refetchAll() {
    refetch();
    refetchStakeBalance();
    refetchAllowance();
  }

  return {
    apr: apr as bigint | undefined,
    totalStaked: totalStaked as bigint | undefined,
    rewardsPoolBalance: rewardsPoolBalance as bigint | undefined,
    stakedBalance: stakedBalance as bigint | undefined,
    pendingRewards: pendingRewards as bigint | undefined,
    stakeTokenBalance: stakeTokenBalance as bigint | undefined,
    allowance: allowance as bigint | undefined,
    isLoading,
    refetchAll,
  };
}

/// Wraps a single write + its receipt wait, refetching vault reads on confirmation so the UI
/// reflects the new state without a manual refresh.
function useVaultWrite(onSuccessRefetch: () => void) {
  const write = useWriteContractWithGas();
  const receipt = useWaitForTransactionReceipt({ hash: write.data });

  useEffect(() => {
    if (receipt.isSuccess) onSuccessRefetch();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [receipt.isSuccess]);

  return { write, receipt };
}

export function useApproveStakeToken(amount: bigint | undefined, onSuccessRefetch: () => void) {
  const { write, receipt } = useVaultWrite(onSuccessRefetch);

  function approve() {
    if (!STAKE_TOKEN_ADDRESS || !STAKING_VAULT_ADDRESS || amount === undefined) return;
    write.reset();
    write.mutate({
      address: STAKE_TOKEN_ADDRESS,
      abi: erc20Abi,
      functionName: 'approve',
      args: [STAKING_VAULT_ADDRESS, amount],
    });
  }

  return { approve, isPending: write.isPending, isConfirming: receipt.isLoading, isSuccess: receipt.isSuccess, error: write.error };
}

export function useDeposit(onSuccessRefetch: () => void) {
  const { write, receipt } = useVaultWrite(onSuccessRefetch);

  function deposit(amount: bigint) {
    if (!STAKING_VAULT_ADDRESS) return;
    write.reset();
    write.mutate({
      address: STAKING_VAULT_ADDRESS,
      abi: stakingVaultAbi,
      functionName: 'deposit',
      args: [amount],
    });
  }

  return { deposit, isPending: write.isPending, isConfirming: receipt.isLoading, isSuccess: receipt.isSuccess, error: write.error };
}

export function useWithdraw(onSuccessRefetch: () => void) {
  const { write, receipt } = useVaultWrite(onSuccessRefetch);

  function withdraw(amount: bigint) {
    if (!STAKING_VAULT_ADDRESS) return;
    write.reset();
    write.mutate({
      address: STAKING_VAULT_ADDRESS,
      abi: stakingVaultAbi,
      functionName: 'withdraw',
      args: [amount],
    });
  }

  return { withdraw, isPending: write.isPending, isConfirming: receipt.isLoading, isSuccess: receipt.isSuccess, error: write.error };
}

export function useClaimRewards(onSuccessRefetch: () => void) {
  const { write, receipt } = useVaultWrite(onSuccessRefetch);

  function claim() {
    if (!STAKING_VAULT_ADDRESS) return;
    write.reset();
    write.mutate({
      address: STAKING_VAULT_ADDRESS,
      abi: stakingVaultAbi,
      functionName: 'claimRewards',
    });
  }

  return { claim, isPending: write.isPending, isConfirming: receipt.isLoading, isSuccess: receipt.isSuccess, error: write.error };
}
