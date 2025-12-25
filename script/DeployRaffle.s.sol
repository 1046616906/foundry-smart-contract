// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script} from "../lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {
    CreateSubscription,
    FundSubscription,
    AddConsumer
} from "./Interactions.s.sol";
contract DeployRaffle is Script {
    function run() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        if (config.subId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            config.subId = createSubscription.createSubscription(
                config.vrfCoordinator
            );
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.subId,
                config.link
            );
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
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            config.vrfCoordinator,
            config.subId
        );
        return (raffle, helperConfig);
    }
}
