// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {DeployFriendsNFT} from "../../script/DeployFriendsNFT.s.sol";
import {FriendsNFT} from "../../src/FriendsNFT.sol";

contract FriendsNFTTest is Test {
    DeployFriendsNFT deployer;
    FriendsNFT friendsNFT;
    address public immutable USER = makeAddr("user");
    string public constant FRIENDS =
        "ipfs://bafybeifavnfkv3rc26poccnk6xyd7rxizyqanaxappwuu3u3mwhwfvb4rq/friends1.json";

    function setUp() public {
        deployer = new DeployFriendsNFT();
        friendsNFT = deployer.run();
    }

    function testNameisCorrect() public view {
        string memory expectedName = "Friends";
        string memory actualName = friendsNFT.name();

        assert(
            keccak256(abi.encodePacked(expectedName)) ==
                keccak256(abi.encodePacked(actualName))
        );
    }

    function testCanMintAndHaveBalance() public {
        vm.prank(USER);
        friendsNFT.mintNft(FRIENDS);

        assert(friendsNFT.balanceOf(USER) == 1);
        assert(
            keccak256(abi.encodePacked(FRIENDS)) ==
                keccak256(abi.encodePacked(friendsNFT.tokenURI(0)))
        );
    }
}
