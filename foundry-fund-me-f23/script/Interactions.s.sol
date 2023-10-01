// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {FundMe} from "../src/FundMe.sol";

contract FundFundMe is Script {
    uint256 constant SEND_VALUE = 0.01 ether;

    function run() external {
        // address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
        //     "FundMe",
        //     block.chainid
        // );
        address mostRecentlyDeployed = 0x2de4145217fff7E4EAff9B7feEbA44c99E5103Dd;

        fundFundMe(mostRecentlyDeployed);
    }

    function fundFundMe(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        FundMe(payable(mostRecentlyDeployed)).fund{value: SEND_VALUE}();
        vm.stopBroadcast();
    }
}

contract WithdrawFundMe is Script {
    uint256 constant SEND_VALUE = 0.01 ether;

    function run() external {
        // address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
        //     "FundMe",
        //     block.chainid
        // );
        address mostRecentlyDeployed = 0x2de4145217fff7E4EAff9B7feEbA44c99E5103Dd;

        withdrawFundMe(mostRecentlyDeployed);
    }

    function withdrawFundMe(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        FundMe(payable(mostRecentlyDeployed)).withdraw();
        vm.stopBroadcast();
    }
}
