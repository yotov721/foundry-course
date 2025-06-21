import {
    createWalletClient,
    createPublicClient,
    custom,
    parseEther,
    defineChain,
    formatEther,
    type PublicClient,
    type WalletClient,
    type Chain,
    type Transport,
  } from "viem";

  import "viem/window";
  import { contractAddress, abi } from "./constants";

  const connectButton = document.getElementById("connectButton") as HTMLButtonElement;
  const fundButton = document.getElementById("fundButton") as HTMLButtonElement;
  const ethAmountInput = document.getElementById("ethAmount") as HTMLInputElement;
  const balanceButton = document.getElementById("balanceButton") as HTMLButtonElement;
  const withdrawButton = document.getElementById("withdrawButton") as HTMLButtonElement;
  const getAddressFundedAmountButton = document.getElementById("getAddressFundedAmountButton") as HTMLButtonElement;

  let walletClient: WalletClient<Transport> | undefined;
  let publicClient: PublicClient<Transport> | undefined;

  async function connect(): Promise<void> {
    if (typeof window.ethereum !== 'undefined') {
      walletClient = createWalletClient({
        transport: custom(window.ethereum)
      });
      const account = await walletClient.requestAddresses();
      console.log("connected", account);
    } else {
      connectButton.innerHTML = "Please install MetaMask";
    }
  }

  async function fund(): Promise<void> {
    const ethAmount = ethAmountInput.value;
    console.log(`Funding with ${ethAmount} ETH`);

    if (typeof window.ethereum !== 'undefined') {
      walletClient = createWalletClient({
        transport: custom(window.ethereum)
      });
      const [connectedAccount] = await walletClient.requestAddresses();

      publicClient = createPublicClient({
        transport: custom(window.ethereum)
      });

      const chain = await getCurrentChain(publicClient);

      const { request } =
        await publicClient.simulateContract({
          address: contractAddress,
          abi,
          functionName: "fund",
          account: connectedAccount,
          chain,
          value: parseEther(ethAmount),
        });

      console.log(request);

      const hash = await walletClient.writeContract(request);
      console.log(hash);
    } else {
      connectButton.innerHTML = "Please install MetaMask";
    }
  }

  async function getCurrentChain(client: PublicClient): Promise<Chain> {
    const chainId = await client.getChainId();
    return defineChain({
      id: chainId,
      name: "Custom Chain",
      nativeCurrency: {
        name: "Ether",
        symbol: "ETH",
        decimals: 18,
      },
      rpcUrls: {
        default: {
          http: ["http://localhost:8545"],
        },
      },
    });
  }

  async function getBalance(): Promise<void> {
    if (typeof window.ethereum !== 'undefined') {
      publicClient = createPublicClient({
        transport: custom(window.ethereum)
      });

      const balance = await publicClient.getBalance({
        address: contractAddress,
      });

      console.log(`Balance is ${formatEther(balance)}`);
    } else {
      connectButton.innerHTML = "Please install MetaMask";
    }
  }

  async function withdraw(): Promise<void> {
    if (typeof window.ethereum !== 'undefined') {
      walletClient = createWalletClient({
        transport: custom(window.ethereum)
      });
      const [connectedAccount] = await walletClient.requestAddresses();

      publicClient = createPublicClient({
        transport: custom(window.ethereum)
      });

      const chain = await getCurrentChain(publicClient);

      const { request } =
        await publicClient.simulateContract({
          address: contractAddress,
          abi,
          functionName: "withdraw",
          account: connectedAccount,
          chain,
        });

      console.log(request);

      const hash = await walletClient.writeContract(request);
      console.log(hash);
    } else {
      connectButton.innerHTML = "Please install MetaMask";
    }
  }

  async function getAddressFundedAmount(): Promise<void> {
    if (typeof window.ethereum !== 'undefined') {
      publicClient = createPublicClient({
        transport: custom(window.ethereum)
      });

      const funderAddress = (document.getElementById("funderAddress") as HTMLInputElement).value;

      const amount = await publicClient.readContract({
        address: contractAddress,
        abi,
        functionName: "getAddressToAmountFunded",
        args: [funderAddress],
      });

      console.log(`Amount funded by ${funderAddress} is ${amount}`);
    } else {
      connectButton.innerHTML = "Please install MetaMask";
    }
  }

  balanceButton.onclick = getBalance;
  connectButton.onclick = connect;
  fundButton.onclick = fund;
  withdrawButton.onclick = withdraw;
  getAddressFundedAmountButton.onclick = getAddressFundedAmount;
