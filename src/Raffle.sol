// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    VRFConsumerBaseV2Plus
} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {
    VRFV2PlusClient
} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /* Error */
    error Raffle_NotEnoughETH();
    error Raffle_CALCULATING();
    error Raffle_TransferFailed();
    error Raffle_NotUpkeepNeeded();
    /**status */
    uint32 constant NUMBER_WORD = 1;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint256 public immutable i_entranceFee;
    bytes32 public immutable i_keyHash;
    uint32 public immutable i_callbackGasLimit;
    uint256 public immutable i_subId;
    uint256 public immutable i_interval;
    uint256 public s_lastTime;
    address payable[] public s_players;
    address public winner; // 获胜者

    RaffleStatus public raffleStatus = RaffleStatus.OPEN;
    enum RaffleStatus {
        OPEN,
        CALCULATING
    }

    /* 事件 */
    event EnterRaffle(address indexed player, uint256 amount);

    constructor(
        uint256 entranceFee,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        address vrfCoordinator,
        uint256 subId,
        uint256 interval
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        i_subId = subId;
        i_interval = interval;
        s_lastTime = block.timestamp;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) revert Raffle_NotEnoughETH();
        if (raffleStatus != RaffleStatus.OPEN) revert Raffle_CALCULATING();
        s_players.push(payable(msg.sender));
        emit EnterRaffle(msg.sender, msg.value);
    }
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool hasTime = block.timestamp - s_lastTime >= i_interval;
        bool hasPlayers = s_players.length > 0;
        bool raffleStatusIsOpen = (raffleStatus == RaffleStatus.OPEN);
        bool hasEnoughETH = address(this).balance >= 0;
        upkeepNeeded =
            hasTime &&
            hasPlayers &&
            raffleStatusIsOpen &&
            hasEnoughETH;
        return (upkeepNeeded, "");
    }

    function performUpkeep() public {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) revert Raffle_NotUpkeepNeeded();
        raffleStatus = RaffleStatus.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory result = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUMBER_WORD,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        // uint256 requestId = 
        s_vrfCoordinator.requestRandomWords(result);
    }

    function fulfillRandomWords(
        uint256 /*_requestId*/,
        uint256[] calldata _randomWords
    ) internal override {
        uint256 randomNum = _randomWords[0] % s_players.length; // 获取余数
        winner = s_players[randomNum];
        raffleStatus = RaffleStatus.OPEN;
        s_lastTime = block.timestamp;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) revert Raffle_TransferFailed();
    }
}
