// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MerkleAirdrop is EIP712 {
    using SafeERC20 for IERC20;

    error InvalidMerkleProof();
    error AlreadyClaimed();
    error InvalidSignature();

    bytes32 private immutable merkleRoot;
    IERC20 private immutable airdropToken;
    mapping(address => bool) claimed;

    bytes32 public constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account,uint256 amount)");

    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    event Claim(address account, uint256 amount);

    constructor(bytes32 _merkleRoot, IERC20 _airdropToken) EIP712("MerkleAirdrop", "1") {
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

    function claimWithSignature(address account, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) revert InvalidMerkleProof();
        if (claimed[account]) revert AlreadyClaimed();

        if (!_isValidSignature(account, getMessageHash(account, amount), v, r ,s)) revert InvalidSignature();
        claimed[account] = true;

        airdropToken.safeTransfer(account, amount);
        emit Claim(account, amount);
    }

    function getMessageHash(address account, uint256 amount) public view returns (bytes32){
        return _hashTypedDataV4(
            keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount})))
        );
    }

    function _isValidSignature(address account, bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal pure returns (bool) {
        (address actualSigner, , ) = ECDSA.tryRecover(digest, v, r, s);
        return account == actualSigner;
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