// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {
    VRFCoordinatorV2_5Mock
} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
contract TestRaffle is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    bytes32 keyHash;
    uint32 callbackGasLimit;
    address vrfCoordinator;
    uint256 subId;
    uint256 interval;
    address PLAYER = makeAddr("player");
    uint256 constant START_PLAYER_BALANCE = 10 ether;

    event EnterRaffle(address indexed player, uint256 amount);

    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        keyHash = config.keyHash;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinator = config.vrfCoordinator;
        subId = config.subId;
        interval = config.interval;

        vm.deal(PLAYER, START_PLAYER_BALANCE);
    }

    function test_RaffleState() public view {
        assert(raffle.raffleState() == Raffle.RaffleState.OPEN);
    }

    function test_EnterRaffle_Reverts_WhenNotEnoughEthSent() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_NotEnoughETH.selector);
        raffle.enterRaffle();
    }

    function test_EnterRaffle_RecordsPlayer_WhenEntered() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.s_players(0) == PLAYER);
    }

    function test_EnterRaffle_EmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, true, address(raffle));
        emit EnterRaffle(PLAYER, entranceFee);
        raffle.enterRaffle{value: entranceFee}();
    }

    function test_EnterRaffle_Reverts_WhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep();

        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_CALCULATING.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    function test_CheckUpkeep_ReturnFalse_WhenNoPlayers() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test_CheckUpkeep_ReturnFalse_WhenNoTime() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test_CheckUpkeep_ReturnFalse_WhenStatusIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function test_CheckUpkeep_RetrunTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + interval + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function test_PerformUpkeep_Reverts_IfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint16 playerNum = 0;
        Raffle.RaffleState state = raffle.raffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        currentBalance = entranceFee;
        playerNum = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_NotUpkeepNeeded.selector,
                currentBalance,
                playerNum,
                state
            )
        );
        raffle.performUpkeep();
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + interval + 1);
        _;
    }

    function test_PerformUpkeep_UpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        vm.recordLogs();
        raffle.performUpkeep();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState state = raffle.raffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(state) == 1);
    }

    function test_FulfillRandomWords_RevertsIf_InvalidRequestId(
        uint256 requestId
    ) public raffleEntered {
        // 1. Arrange
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(raffle)
        );
    }

    function test_FulfillRandomWords_PicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
    {
        // 1. Arrange
        uint16 additionalEntrants = 3;
        uint16 startIndex = 1;
        address expectWinner = address(1);
        for (
            uint256 index = startIndex;
            index < additionalEntrants + startIndex;
            index++
        ) {
            hoax(address(uint160(index)), 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startTime = raffle.s_lastTime();
        uint256 winnerStartingBalance = expectWinner.balance;
        // Act
        vm.recordLogs();
        raffle.performUpkeep();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        console.log(uint256(requestId));
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        // assert

        address winner = raffle.winner();
        Raffle.RaffleState raffleState = raffle.raffleState();
        uint256 winnerBalance = winner.balance;
        uint256 endingTime = raffle.s_lastTime();
        uint256 prize = (additionalEntrants + 1) * entranceFee;

        assert(winner == expectWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTime > startTime);
    }
}
