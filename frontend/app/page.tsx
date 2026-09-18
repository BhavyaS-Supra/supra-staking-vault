import { VaultCard } from "@/components/VaultCard";

export default function Home() {
  return (
    <div className="w-full flex flex-col items-center gap-2">
      <div className="w-full max-w-md mb-2">
        <h1 className="text-xl font-semibold">Staking Vault</h1>
        <p className="text-sm text-gray-500">
          Deposit sSTK, earn sRWD continuously at the current APR, withdraw anytime.
        </p>
      </div>
      <VaultCard />
    </div>
  );
}
