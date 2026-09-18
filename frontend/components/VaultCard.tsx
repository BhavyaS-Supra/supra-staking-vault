'use client';

import { useMemo, useState } from 'react';
import { useAccount, useConnect } from 'wagmi';
import { formatUnits, parseUnits } from 'viem';
import {
  CONTRACTS_CONFIGURED,
  STAKE_TOKEN_DECIMALS,
  STAKE_TOKEN_SYMBOL,
  REWARD_TOKEN_DECIMALS,
  REWARD_TOKEN_SYMBOL,
} from '@/lib/contracts';
import { useApproveStakeToken, useClaimRewards, useDeposit, useVaultReads, useWithdraw } from '@/hooks/useVault';

type Tab = 'deposit' | 'withdraw';

function parseContractError(error: Error): string {
  const msg = error.message ?? String(error);
  if (msg.includes('User rejected')) return 'Transaction rejected.';
  if (msg.includes('InsufficientBalance')) return 'Amount exceeds your staked balance.';
  if (msg.includes('ZeroAmount')) return 'Enter an amount greater than zero.';
  return msg.length > 200 ? msg.slice(0, 200) + '...' : msg;
}

function formatToken(value: bigint | undefined, decimals: number, maxFractionDigits = 4): string {
  if (value === undefined) return '0.0';
  const formatted = Number(formatUnits(value, decimals));
  return formatted.toLocaleString(undefined, { maximumFractionDigits: maxFractionDigits });
}

export function VaultCard() {
  const { isConnected } = useAccount();
  const { connect, connectors, isPending: isConnectingWallet } = useConnect();
  const [tab, setTab] = useState<Tab>('deposit');
  const [amount, setAmount] = useState('');

  const {
    apr,
    totalStaked,
    rewardsPoolBalance,
    stakedBalance,
    pendingRewards,
    stakeTokenBalance,
    allowance,
    refetchAll,
  } = useVaultReads();

  const parsedAmount = useMemo(() => {
    if (!amount) return undefined;
    try {
      return parseUnits(amount, STAKE_TOKEN_DECIMALS);
    } catch {
      return undefined;
    }
  }, [amount]);

  const needsApproval = tab === 'deposit' && Boolean(
    parsedAmount && (allowance === undefined || allowance < parsedAmount)
  );

  const approveHook = useApproveStakeToken(parsedAmount, refetchAll);
  const depositHook = useDeposit(() => {
    refetchAll();
    setAmount('');
  });
  const withdrawHook = useWithdraw(() => {
    refetchAll();
    setAmount('');
  });
  const claimHook = useClaimRewards(refetchAll);

  const aprPercent = apr !== undefined ? Number(apr) / 100 : undefined;

  const maxAmount = tab === 'deposit' ? stakeTokenBalance : stakedBalance;
  const exceedsMax = Boolean(parsedAmount !== undefined && maxAmount !== undefined && parsedAmount > maxAmount);

  const errorMessage = depositHook.error
    ? parseContractError(depositHook.error)
    : withdrawHook.error
    ? parseContractError(withdrawHook.error)
    : approveHook.error
    ? parseContractError(approveHook.error)
    : claimHook.error
    ? parseContractError(claimHook.error)
    : null;

  function handleMax() {
    if (maxAmount === undefined) return;
    setAmount(formatUnits(maxAmount, STAKE_TOKEN_DECIMALS));
  }

  function handleConnectWallet() {
    const starkeyConnector = connectors.find((c) => c.id === 'starkey');
    const hasStarKey = typeof window !== 'undefined' && !!window.starkey?.ethereum;
    const connector =
      (hasStarKey && starkeyConnector) || connectors.find((c) => c.id !== 'starkey') || connectors[0];
    if (connector) connect({ connector });
  }

  function handlePrimaryAction() {
    if (!parsedAmount) return;
    if (tab === 'deposit') {
      if (needsApproval) {
        approveHook.approve();
      } else {
        depositHook.deposit(parsedAmount);
      }
    } else {
      withdrawHook.withdraw(parsedAmount);
    }
  }

  if (!CONTRACTS_CONFIGURED) {
    return (
      <div className="w-full max-w-md rounded-2xl border border-gray-200 dark:border-gray-800 p-6 text-sm text-gray-500">
        Contracts haven&apos;t been deployed yet. Run the scripts in <code>contracts/script</code>, then fill in{' '}
        <code>frontend/.env.local</code> (vault/stake token/reward token addresses) to enable the vault UI.
      </div>
    );
  }

  const isBusy =
    approveHook.isPending || approveHook.isConfirming || depositHook.isPending || depositHook.isConfirming ||
    withdrawHook.isPending || withdrawHook.isConfirming;

  let primaryLabel = tab === 'deposit' ? 'Deposit' : 'Withdraw';
  if (tab === 'deposit' && needsApproval) primaryLabel = `Approve ${STAKE_TOKEN_SYMBOL}`;
  if (approveHook.isPending || approveHook.isConfirming) primaryLabel = 'Approving...';
  else if (depositHook.isPending || depositHook.isConfirming) primaryLabel = 'Depositing...';
  else if (withdrawHook.isPending || withdrawHook.isConfirming) primaryLabel = 'Withdrawing...';

  return (
    <div className="w-full max-w-md flex flex-col gap-4">
      <div className="rounded-2xl border border-gray-200 dark:border-gray-800 p-6 flex flex-col gap-4">
        <div className="flex items-center justify-between">
          <div className="flex gap-1 rounded-lg bg-gray-100 dark:bg-gray-900 p-1">
            {(['deposit', 'withdraw'] as Tab[]).map((t) => (
              <button
                key={t}
                onClick={() => {
                  setTab(t);
                  setAmount('');
                }}
                className={`px-3 py-1.5 rounded-md text-sm font-medium capitalize transition-colors ${
                  tab === t
                    ? 'bg-white dark:bg-gray-800 shadow-sm'
                    : 'text-gray-500 hover:text-foreground'
                }`}
              >
                {t}
              </button>
            ))}
          </div>
          <div className="text-xs text-gray-500 flex items-center gap-1">
            APR
            <span className="font-mono font-semibold text-green-600">
              {aprPercent !== undefined ? `${aprPercent}%` : '—'}
            </span>
          </div>
        </div>

        <div className="rounded-xl border border-gray-200 dark:border-gray-800 p-3">
          <div className="flex justify-between text-xs text-gray-500 mb-1">
            <span>{tab === 'deposit' ? 'You deposit' : 'You withdraw'}</span>
            <button onClick={handleMax} className="hover:text-foreground">
              Balance: {formatToken(maxAmount, STAKE_TOKEN_DECIMALS)} {STAKE_TOKEN_SYMBOL}
            </button>
          </div>
          <div className="flex gap-2 items-center">
            <input
              className="flex-1 bg-transparent text-2xl outline-none min-w-0"
              placeholder="0.0"
              inputMode="decimal"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
            />
            <button
              onClick={handleMax}
              className="text-xs font-medium px-2 py-1 rounded bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700"
            >
              MAX
            </button>
            <span className="font-medium text-sm">{STAKE_TOKEN_SYMBOL}</span>
          </div>
        </div>

        {!isConnected ? (
          <button
            onClick={handleConnectWallet}
            disabled={isConnectingWallet}
            className="w-full py-3 rounded-xl bg-blue-600 text-white font-medium disabled:opacity-50 hover:bg-blue-700 transition-colors"
          >
            {isConnectingWallet ? 'Connecting...' : 'Connect wallet to continue'}
          </button>
        ) : (
          <button
            onClick={handlePrimaryAction}
            disabled={!parsedAmount || parsedAmount === 0n || exceedsMax || isBusy}
            className="w-full py-3 rounded-xl bg-blue-600 text-white font-medium disabled:opacity-50 hover:bg-blue-700 transition-colors"
          >
            {exceedsMax ? 'Insufficient balance' : primaryLabel}
          </button>
        )}

        {(depositHook.isSuccess || withdrawHook.isSuccess) && (
          <div className="text-sm text-green-600">
            {tab === 'deposit' ? 'Deposit confirmed.' : 'Withdrawal confirmed.'}
          </div>
        )}
        {errorMessage && <div className="text-sm text-red-500">{errorMessage}</div>}
      </div>

      <div className="rounded-2xl border border-gray-200 dark:border-gray-800 p-6 flex flex-col gap-4">
        <h3 className="text-sm font-semibold text-gray-500">Your position</h3>

        <div className="flex justify-between items-baseline">
          <span className="text-sm text-gray-500">Staked balance</span>
          <span className="font-mono font-medium">
            {formatToken(stakedBalance, STAKE_TOKEN_DECIMALS)} {STAKE_TOKEN_SYMBOL}
          </span>
        </div>

        <div className="flex justify-between items-baseline">
          <span className="text-sm text-gray-500">Pending rewards</span>
          <span className="font-mono font-medium text-green-600">
            {formatToken(pendingRewards, REWARD_TOKEN_DECIMALS, 6)} {REWARD_TOKEN_SYMBOL}
          </span>
        </div>

        <button
          onClick={() => claimHook.claim()}
          disabled={!isConnected || !pendingRewards || pendingRewards === 0n || claimHook.isPending || claimHook.isConfirming}
          className="w-full py-2.5 rounded-xl bg-emerald-600 text-white font-medium disabled:opacity-50 hover:bg-emerald-700 transition-colors"
        >
          {claimHook.isPending || claimHook.isConfirming ? 'Claiming...' : 'Claim rewards'}
        </button>
        {claimHook.isSuccess && <div className="text-sm text-green-600">Rewards claimed.</div>}

        <hr className="border-gray-200 dark:border-gray-800" />

        <div className="flex justify-between items-baseline text-sm">
          <span className="text-gray-500">Total staked (vault)</span>
          <span className="font-mono">{formatToken(totalStaked, STAKE_TOKEN_DECIMALS)} {STAKE_TOKEN_SYMBOL}</span>
        </div>
        <div className="flex justify-between items-baseline text-sm">
          <span className="text-gray-500">Rewards pool balance</span>
          <span className="font-mono">{formatToken(rewardsPoolBalance, REWARD_TOKEN_DECIMALS)} {REWARD_TOKEN_SYMBOL}</span>
        </div>
      </div>
    </div>
  );
}
