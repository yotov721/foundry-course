"use client" // run on the client side / in the browser

import { getDefaultConfig } from "@rainbow-me/rainbowkit"
import { anvil, zksync } from "viem/chains" // chains used

// config - what chains to support
export default getDefaultConfig({
  appName: "TSender",
  projectId: process.env.NEXT_PUBLIC_PROJECT_ID!,
  chains: [anvil, zksync],
  ssr: false,
})

