"use client"

import HomeComponent from "@/components/HomeComponent";
import { useAccount } from "wagmi";

export default function Home() {
  const { isConnected } = useAccount();

  return (
    <div>
      {!isConnected ? (
        <div>Please connect your wallet</div>
      ) : (
        <div>
          <HomeComponent />
        </div>
      )}
    </div>
  );
}
