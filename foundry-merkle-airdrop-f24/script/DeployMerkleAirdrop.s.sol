// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { StarToken } from "../src/StarToken.sol";
import { MerkleAirdrop } from "../src/MerkleAirdrop.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract DeployMerkleAirdrop is Script {
    bytes32 merkleRoot = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 amountToMint = 4 * 25 * 1e18;

    function run() external returns (StarToken, MerkleAirdrop) {
        return deployMerkleAirdrop();
    }

    function deployMerkleAirdrop() public returns (StarToken token, MerkleAirdrop airdrop) {
        vm.startBroadcast();
        token = new StarToken();
        airdrop = new MerkleAirdrop(merkleRoot, IERC20(token));
        token.mint(token.owner(), amountToMint);
        token.transfer(address(airdrop), amountToMint);
        vm.stopBroadcast(); 
    }
}