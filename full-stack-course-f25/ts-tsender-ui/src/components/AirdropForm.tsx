"use client"

import InputField from "@/components/ui/InputField"
import Spinner from "@/components/ui/Spiner"
import { useState, useMemo, useEffect } from "react"
import { chainsToTSender, erc20Abi, tsenderAbi } from "@/constants";
import { useChainId, useConfig, useAccount, useWriteContract } from "wagmi"
import { readContract, waitForTransactionReceipt, getToken } from "@wagmi/core";
import { calculateTotal } from "@/utils/calculateTotal/calculateTotal";
import TransactionDetails from "@/components/ui/TransactionDetails";
import { formatUnits } from "viem";

// Transaction states for button UI
enum TransactionState {
    IDLE = "idle",
    CONFIRMING = "confirming",
    SENDING = "sending"
}

export default function AirdropForm() {
    // state hooks with localStorage persistence
    const [tokenAddress, setTokenAddress] = useState(() => {
        if (typeof window !== 'undefined') {
            return localStorage.getItem('tokenAddress') || "";
        }
        return "";
    });

    const [recipients, setRecipients] = useState(() => {
        if (typeof window !== 'undefined') {
            return localStorage.getItem('recipients') || "";
        }
        return "";
    });

    const [amounts, setAmounts] = useState(() => {
        if (typeof window !== 'undefined') {
            return localStorage.getItem('amounts') || "";
        }
        return "";
    });

    const [transactionState, setTransactionState] = useState<TransactionState>(TransactionState.IDLE);
    const [tokenDetails, setTokenDetails] = useState<{ name: string, symbol: string, decimals: number } | null>(null);

    const chainId = useChainId();
    const config = useConfig();
    const account = useAccount();
    const total: number = useMemo(() => calculateTotal(amounts), [amounts]); // anytime amounts changes call the function
    const {writeContractAsync} = useWriteContract();

    // Save form values to localStorage whenever they change
    useEffect(() => {
        localStorage.setItem('tokenAddress', tokenAddress);
        localStorage.setItem('recipients', recipients);
        localStorage.setItem('amounts', amounts);
    }, [tokenAddress, recipients, amounts]);

    // Fetch token details when token address changes
    useEffect(() => {
        async function fetchTokenDetails() {
            if (!tokenAddress || !tokenAddress.startsWith('0x')) {
                setTokenDetails(null);
                return;
            }

            try {
                const token = await getToken(config, {
                    address: tokenAddress as `0x${string}`,
                    chainId
                });

                setTokenDetails({
                    name: token.name || 'Unknown Token',
                    symbol: token.symbol || 'UNKNOWN',
                    decimals: token.decimals
                });
            } catch (error) {
                console.error("Failed to fetch token details:", error);
                setTokenDetails(null);
            }
        }

        fetchTokenDetails();
    }, [tokenAddress, chainId, config]);

    async function getApprovedAmount(tSenderAddress: String | null): Promise<number> {
        if (!tSenderAddress) {
            alert("No address found")
            return 0
        }

        const response = await readContract(config, {
            abi: erc20Abi,
            address: tokenAddress as `0x${string}`,
            functionName: 'allowance',
            args: [account.address, tSenderAddress as `0x${string}`],
        })
        return response as number
    }

    // Format the total amount based on token decimals
    const formattedTotal = useMemo(() => {
        if (!tokenDetails || total === 0) return "0";
        return formatUnits(BigInt(total), tokenDetails.decimals);
    }, [total, tokenDetails]);

    async function handleSubmit() {
        try {
            setTransactionState(TransactionState.CONFIRMING);

            const tSenderAddress = chainsToTSender[chainId].tsender;
            const approvedAmount = await getApprovedAmount(tSenderAddress);

            if (approvedAmount < total) {
                const approvalHash = await writeContractAsync({
                    abi: erc20Abi,
                    address: tokenAddress as `0x${string}`,
                    functionName: 'approve',
                    args: [tSenderAddress as `0x${string}`, BigInt(total)],
                })

                setTransactionState(TransactionState.SENDING);

                const approvalReceipt = await waitForTransactionReceipt(config, {
                    hash: approvalHash
                })

                console.log("Approval receipt", approvalReceipt);
            }

            setTransactionState(TransactionState.CONFIRMING);

            const airdropHash = await writeContractAsync({
                abi: tsenderAbi,
                address: tSenderAddress as `0x${string}`,
                functionName: 'airdropERC20',
                args: [
                        tokenAddress,
                        recipients.split(/[,\n]+/).map(addr => addr.trim()).filter(addr => addr !== ''),
                        amounts.split(/[,\n]+/).map(amt => amt.trim()).filter(amt => amt !== ''),
                        BigInt(total),
                    ],
            })

            setTransactionState(TransactionState.SENDING);

            const airdropReceipt = await waitForTransactionReceipt(config, {
                hash: airdropHash
            })

            console.log("Airdrop receipt", airdropReceipt);

        } catch (error) {
            console.error("Transaction failed:", error);
        } finally {
            setTransactionState(TransactionState.IDLE);
        }
    }

    // Helper function to get button text based on transaction state
    const getButtonText = () => {
        switch (transactionState) {
            case TransactionState.CONFIRMING:
                return "Confirm in MetaMask";
            case TransactionState.SENDING:
                return "Sending transaction";
            default:
                return "Send Tokens";
        }
    };

    return (
        <div>
            <InputField
                label="Token Address"
                placeholder="0x123"
                value={tokenAddress}
                onChange={(e) => setTokenAddress(e.target.value)}
            />
            <InputField
                label="Recipients Addresses"
                placeholder="0x123,0x123,0x123"
                value={recipients}
                large={true}
                onChange={(e) => setRecipients(e.target.value)}
            />
            <InputField
                label="Amounts"
                placeholder="100,200,300"
                value={amounts}
                large={true}
                onChange={(e) => setAmounts(e.target.value)}
            />

            {total > 0 && tokenDetails && (
                <TransactionDetails
                    tokenName={tokenDetails.name || `${tokenDetails.symbol} Token`}
                    amountInWei={total.toString()}
                    amountInTokens={formattedTotal}
                />
            )}

            <br></br>
            <button
                onClick={handleSubmit}
                disabled={transactionState !== TransactionState.IDLE}
                className={`flex items-center justify-center font-bold py-2 px-4 rounded ${
                    transactionState !== TransactionState.IDLE
                        ? 'bg-gray-500 cursor-not-allowed'
                        : 'bg-blue-500 hover:bg-blue-700'
                } text-white`}
            >
                {(transactionState === TransactionState.CONFIRMING || transactionState === TransactionState.SENDING) && <Spinner />}
                {getButtonText()}
            </button>
        </div>
    );
}
