// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleAirdrop {
    using SafeERC20 for IERC20;

    error InvalidMerkleProof();
    error AlreadyClaimed();

    bytes32 private immutable merkleRoot;
    IERC20 private immutable airdropToken;
    mapping(address => bool) claimed;

    event Claim(address account, uint256 amount);

    constructor(bytes32 _merkleRoot, IERC20 _airdropToken) {
        merkleRoot = _merkleRoot;
        airdropToken = _airdropToken;
    }

    function claim(address account, uint256 amount, bytes32[] calldata merkleProof) external {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) revert InvalidMerkleProof();
        if (claimed[account]) revert AlreadyClaimed();

        claimed[account] = true;

        airdropToken.safeTransfer(account, amount);
        emit Claim(account, amount);
    }

    function getMerkleRoot() external view returns (bytes32) {
        return merkleRoot;
    }

    function getClaimStatus(address account) external view returns (bool) {
        return claimed[account];
    }

    function getAirdropToken() external view returns (IERC20) {
        return airdropToken;
    }
}