import React from 'react';

interface TransactionDetailsProps {
  tokenName: string;
  amountInWei: string | number;
  amountInTokens: string | number;
}

export default function TransactionDetails({
  tokenName,
  amountInWei,
  amountInTokens
}: TransactionDetailsProps) {
  return (
    <div className="bg-gray-100 p-4 rounded-md mb-4">
      <h3 className="text-lg font-bold mb-2">Transaction Details</h3>
      <div className="grid grid-cols-2 gap-2">
        <div className="text-gray-600">Token:</div>
        <div className="font-medium">{tokenName}</div>

        <div className="text-gray-600">Amount (Wei):</div>
        <div className="font-medium">{amountInWei}</div>

        <div className="text-gray-600">Amount (Tokens):</div>
        <div className="font-medium">{amountInTokens}</div>
      </div>
    </div>
  );
}

