// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { StarToken } from "../src/StarToken.sol";
import { MerkleAirdrop } from "../src/MerkleAirdrop.sol";
import { ZkSyncChainChecker } from "foundry-devops/src/ZkSyncChainChecker.sol";
import { DeployMerkleAirdrop } from "../script/DeployMerkleAirdrop.s.sol";

contract MerkleAirdropTest is Test, ZkSyncChainChecker {
    MerkleAirdrop public airdrop;
    StarToken public starToken;

    bytes32 public root = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 public amount = 25 * 1e18;
    bytes32[] public proof = [bytes32(0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a), bytes32(0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576)];

    address user;
    uint256 userPrivKey;
    address gasPayer;

    function setUp() public {
        if (!isZkSyncChain()) {
            DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
            (starToken, airdrop) = deployer.deployMerkleAirdrop();
        } else {
            starToken = new StarToken();
            airdrop = new MerkleAirdrop(root, starToken);
            starToken.mint(starToken.owner(), 4 * amount);
            starToken.transfer(address(airdrop), 4 * amount);
        }

        (user, userPrivKey) = makeAddrAndKey("user");
        gasPayer = makeAddr("gasPayer");
    }

    function testUsersCanClaim() public {
        uint256 startingBalance = starToken.balanceOf(user);

        vm.prank(user);
        airdrop.claim(user, amount, proof);

        uint256 endingBalance = starToken.balanceOf(user);
        console.log(endingBalance - startingBalance);

        assertEq(endingBalance - startingBalance, amount);
    }

    function testAnotherUserCanClaimWithSignature() public {
        uint256 startingBalance = starToken.balanceOf(user);
        bytes32 digest = airdrop.getMessageHash(user, amount);

        // user signes the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivKey, digest);

        vm.prank(gasPayer);
        airdrop.claimWithSignature(user, amount, proof, v, r, s);

        uint256 endingBalance = starToken.balanceOf(user);
        console.log(endingBalance - startingBalance);

        assertEq(endingBalance - startingBalance, amount);
    }
}