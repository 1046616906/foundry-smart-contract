// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script} from "../lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "./Interactions.s.sol";
contract DeployRaffle is Script {
    function run() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        if (config.subId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            config.subId = createSubscription.createSubscription(config.vrfCoordinator);
        }
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.keyHash,
            config.callbackGasLimit,
            config.vrfCoordinator,
            config.subId,
            config.interval
        );
        vm.stopBroadcast();
        return (raffle, helperConfig);
    }
}
