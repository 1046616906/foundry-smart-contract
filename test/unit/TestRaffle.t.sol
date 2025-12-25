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

    function testRaffleStatus() public view {
        assert(raffle.raffleStatus() == Raffle.RaffleStatus.OPEN);
    }

    function testRevertIsNotEnoughETH() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_NotEnoughETH.selector);
        raffle.enterRaffle();
    }

    function testEnterRaffleIsHasPlayer() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.s_players(0) == PLAYER);
    }

    function testEmitEnterRaffle() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, true, address(raffle));
        emit EnterRaffle(PLAYER, entranceFee);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testPlayerDontAllowEnterRaffleAtCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }
}
