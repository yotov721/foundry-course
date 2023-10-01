// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    DeployFundMe deployFundMe;

    address USER = makeAddr("Alice");
    uint256 constant SEND_AMOUNT = 0.1 ether;
    uint256 constant START_BALANCE = 10 ether;

    // forge coverage --fork-url $SEPOLIA_RPC_URL
    function setUp() external {
        deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, START_BALANCE);
    }

    function testMinimumDollarsIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        assertEq(fundMe.owner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundMeFailsWithoutEnoughtETH() public {
        vm.expectRevert(); // The next line should revert
        fundMe.fund();
    }

    function testFundMeUpdatesFUndedDataStructure() public {
        vm.prank(USER); // the next Tx will be send by USER
        fundMe.fund{value: SEND_AMOUNT}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_AMOUNT);
    }

    function testAddFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_AMOUNT}();

        address funder = fundMe.getFunder(0);

        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_AMOUNT}();
        assert(address(fundMe).balance > 0);
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawlWithSigngleFunder() public funded {
        uint256 startingOwnerBalance = fundMe.owner().balance;
        uint256 startingContractBalance = address(fundMe).balance;

        vm.prank(fundMe.owner());
        fundMe.withdraw();

        uint256 endingOwnerBalance = fundMe.owner().balance;
        uint256 endingContractBalance = address(fundMe).balance;

        assertEq(endingContractBalance, 0);
        assertEq(
            endingOwnerBalance,
            startingContractBalance + startingOwnerBalance
        );
    }

    function testWithDrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // we get hoax from stdcheats
            // prank + deal
            hoax(address(i), START_BALANCE);
            fundMe.fund{value: SEND_AMOUNT}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.owner().balance;

        vm.startPrank(fundMe.owner());
        fundMe.withdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.owner().balance
        );
    }

    function testCheaperWithDrawFromMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2;
        for (
            uint160 i = startingFunderIndex;
            i < numberOfFunders + startingFunderIndex;
            i++
        ) {
            // prank + deal
            hoax(address(i), START_BALANCE);
            fundMe.fund{value: SEND_AMOUNT}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.owner().balance;

        vm.startPrank(fundMe.owner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.owner().balance
        );
    }
}
