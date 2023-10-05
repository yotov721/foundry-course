// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    // Events
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    DeployRaffle deployRaffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address PLAYER = makeAddr("player");
    uint256 constant SEND_AMOUNT = 0.1 ether;
    uint256 constant START_USER_BALANCE = 10 ether;

    // forge coverage --fork-url $SEPOLIA_RPC_URL
    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        vm.deal(PLAYER, START_USER_BALANCE);
        (
            entranceFee,
            interval,
            vrfCoordinator,
            keyHash,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenUserDoesntPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.1 ether}();
        assertEq(raffle.getPlayer(0), PLAYER);
    }

    function testRaffleEmitsEventWhenPlayerEnters() public {
        vm.prank(PLAYER);

        // The expected event needs to be emited after this line and before the operation
        vm.expectEmit(true, false, false, false, address(raffle));

        emit EnteredRaffle(PLAYER);

        raffle.enterRaffle{value: 0.1 ether}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.1 ether}();

        // Set block timestamp
        vm.warp(block.timestamp + interval + 1);

        // Set blockumber
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleClosed.selector);
        vm.prank(PLAYER);

        raffle.enterRaffle{value: 0.1 ether}();
    }

    // checkUpkeep

    function testCheckUpkeepReturnsFalseIfIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.1 ether}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);
    }

    // checkUpkeep

    function testCheckUpkeepReturnsFalseIfEnoughtTimeHasntPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.1 ether}();
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnstrueWhenParamethersAreGood() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.1 ether}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    // performUpkeep

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.1 ether}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        vm.expectRevert(Raffle.Raffle__UpkeepNotNeeded.selector);
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.1 ether}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Saves recorded logs
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(raffleState == Raffle.RaffleState.CALCULATING); // 0 = open, 1 = calculating
    }

    // FulfullRandomWords

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.1 ether}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsAfterPerformUpkeep()
        public
        raffleEntered
        skipFork
    {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            0,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
        skipFork
    {
        // 1st person entered in the modifier
        uint256 startingIndex = 1;
        uint256 additionalEntries = 5;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntries;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // also does prank
            raffle.enterRaffle{value: 0.1 ether}();
        }

        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimestamp = raffle.getLastTimeStamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        address recentWinner = raffle.getRecentWinner();

        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(recentWinner != address(0));
        assert(raffle.getLastTimeStamp() > previousTimestamp);
    }
}
