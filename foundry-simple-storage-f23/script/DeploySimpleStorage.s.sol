// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {SimpleStorage} from "../src/SimpleStorage.sol";

// forge script script/DeploySimpleStorage.s.sol --rpc-url $SEPOLIAD_RPC_URL --broadcast --private-key $PRIVATE_KEY
contract DeploySimpleStorage is Script {
    function run() external returns (SimpleStorage) {
        // Send data to the RPC
        vm.startBroadcast();

        SimpleStorage simpleStorage = new SimpleStorage();

        vm.stopBroadcast();
        return simpleStorage;
    }
}
