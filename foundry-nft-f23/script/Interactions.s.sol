// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "@foundry-devops/src/DevOpsTools.sol";
import {FriendsNFT} from "../src/FriendsNFT.sol";

contract MintFriendsNFT is Script {
    string public constant FRIENDS =
        "ipfs://bafybeifavnfkv3rc26poccnk6xyd7rxizyqanaxappwuu3u3mwhwfvb4rq/friends1.json";

    function run() external {
        // address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
        //     "FriendsNFT",
        //     block.chainid
        // );
        address mostRecentlyDeployed = 0x5238D06416D4b50eCd206D4d2DEf54cae8793D30;
        mintNftOncontract(mostRecentlyDeployed);
    }

    function mintNftOncontract(address contractAddress) public {
        vm.startBroadcast();
        FriendsNFT(contractAddress).mintNft(FRIENDS);
        vm.stopBroadcast();
    }
}
