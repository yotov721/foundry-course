// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {FriendsNFT} from "../src/FriendsNFT.sol";

contract DeployFriendsNFT is Script {
    function run() external returns (FriendsNFT) {
        vm.startBroadcast();
        FriendsNFT friendsNft = new FriendsNFT();
        vm.stopBroadcast();
        return friendsNft;
    }
}
