// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {TestToken} from "../src/TestToken.sol";
import {DeployTestToken} from "../script/DeployTestToken.s.sol";

contract TestTokenTest is Test {
    uint256 BOB_STARTING_AMOUNT = 100 ether;

    TestToken public testToken;
    DeployTestToken public deployer;

    address public deployerAddress;
    address bob;
    address alice;

    function setUp() public {
        deployer = new DeployTestToken();
        testToken = deployer.run();

        deployerAddress = vm.addr(deployer.deployerKey());
        bob = makeAddr("bob");
        alice = makeAddr("alice");

        vm.prank(deployerAddress);
        testToken.transfer(bob, BOB_STARTING_AMOUNT);
    }

    function testInitialSupply() public {
        assertEq(testToken.totalSupply(), deployer.INITIAL_SUPPLY());
    }
}