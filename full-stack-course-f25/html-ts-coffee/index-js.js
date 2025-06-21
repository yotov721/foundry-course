import { createWalletClient, custom, createPublicClient, parseEther, defineChain, formatEther } from "https://esm.sh/viem";
import { contractAddress, abi } from "./constants.js";

const connectButton = document.getElementById("connectButton");
const fundButton = document.getElementById("fundButton");
const ethAmountInput = document.getElementById("ethAmount");
const balanceButton = document.getElementById("balanceButton");
const withdrawButton = document.getElementById("withdrawButton");
const getAddressFundedAmountButton = document.getElementById("getAddressFundedAmountButton");

let walletClient;
let publicClient;

async function connect() {
    if(typeof window.ethereum !== 'undefined') {
        walletClient = createWalletClient({
            transport: custom(window.ethereum)
        })
        const account = await walletClient.requestAddresses();
        console.log("connected" + account);
    } else {
        connectButton.innerHTML = "Please install MetaMask";
    }
}

async function fund() {
    const ethAmount = ethAmountInput.value;
    console.log(`Funding with ${ethAmount} ETH`);

    if(typeof window.ethereum !== 'undefined') {
        walletClient = createWalletClient({
            transport: custom(window.ethereum)
        })
        const [connectedAccount] = await walletClient.requestAddresses();

        publicClient = createPublicClient({
            transport: custom(window.ethereum)
        })
        // simulate request
        const { request } = await publicClient.simulateContract({
            address: contractAddress,
            abi: abi,
            functionName: "fund",
            account: connectedAccount,
            chain: await getCurrentChain(publicClient),
            value: parseEther(ethAmount),
        })
        console.log(request);

        const hash = await walletClient.writeContract(request);
        console.log(hash);
    } else {
        connectButton.innerHTML = "Please install MetaMask";
    }
}

async function getCurrentChain(client) {
    const chainId = await client.getChainId()
    const currentChain = defineChain({
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
    })
    return currentChain
}

async function getBalance() {
    if(typeof window.ethereum !== 'undefined') {
        publicClient = createPublicClient({
            transport: custom(window.ethereum)
        })
        const balance = await publicClient.getBalance({
            address: contractAddress,
            chain: await getCurrentChain(publicClient),
        })
        console.log(`Balance is ${formatEther(balance)}`);
    } else {
        connectButton.innerHTML = "Please install MetaMask";
    }
}

async function withdraw() {
    if(typeof window.ethereum !== 'undefined') {
        walletClient = createWalletClient({
            transport: custom(window.ethereum)
        })
        const [connectedAccount] = await walletClient.requestAddresses();

        publicClient = createPublicClient({
            transport: custom(window.ethereum)
        })
        // simulate request
        const { request } = await publicClient.simulateContract({
            address: contractAddress,
            abi: abi,
            functionName: "withdraw",
            account: connectedAccount,
            chain: await getCurrentChain(publicClient),
        })
        console.log(request);

        const hash = await walletClient.writeContract(request);
        console.log(hash);
    } else {
        connectButton.innerHTML = "Please install MetaMask";
    }
}

async function getAddressFundedAmount() {
    if(typeof window.ethereum !== 'undefined') {
        publicClient = createPublicClient({
            transport: custom(window.ethereum)
        })
        const funderAddress = document.getElementById("funderAddress").value;
        const amount = await publicClient.readContract({
            address: contractAddress,
            abi: abi,
            functionName: "getAddressToAmountFunded",
            args: [funderAddress],
        })
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
