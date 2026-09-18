import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { headers } from "next/headers";
import { cookieToInitialState } from "wagmi";
import { config } from "@/config/wagmi";
import { Providers } from "@/components/providers";
import { Nav } from "@/components/Nav";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Supra Staking Vault",
  description: "Deposit, earn APR-based rewards, and withdraw anytime on Supra EVM",
};

export default async function RootLayout({ children }: LayoutProps<"/">) {
  const initialState = cookieToInitialState(config, (await headers()).get("cookie"));

  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <Providers initialState={initialState}>
          <div className="flex flex-col flex-1 bg-zinc-50 dark:bg-black">
            <Nav />
            <main className="flex flex-1 w-full flex-col items-center py-16 px-4">{children}</main>
          </div>
        </Providers>
      </body>
    </html>
  );
}
