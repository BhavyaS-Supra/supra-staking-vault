'use client';

import { ConnectWallet } from '@/components/ConnectWallet';

export function Nav() {
  return (
    <header className="w-full flex items-center justify-between gap-4 px-6 py-4 border-b border-gray-200 dark:border-gray-800">
      <span className="font-semibold whitespace-nowrap">Supra Staking Vault</span>
      <ConnectWallet />
    </header>
  );
}
