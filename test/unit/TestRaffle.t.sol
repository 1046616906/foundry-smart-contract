// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
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

    function test_RaffleStatus() public view {
        assert(raffle.raffleStatus() == Raffle.RaffleStatus.OPEN);
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
        Raffle.RaffleStatus state = raffle.raffleStatus();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        currentBalance = entranceFee;
        playerNum = 1;

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle_NotUpkeepNeeded.selector, currentBalance,playerNum,state)
        );
        raffle.performUpkeep();
    }
}
