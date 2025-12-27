// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {HelperConfig, ChainIdConfig} from "./HelperConfig.s.sol";
import {
    VRFCoordinatorV2_5Mock
} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        createSubscription(config.vrfCoordinator, config.account);
    }

    function createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256) {
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        return subId;
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}
/// @title 添加消费金额
/// @author Naah
/// @notice 注入资金
contract FundSubscription is Script, ChainIdConfig {
    uint256 internal constant FUND_AMOUNT = 3 ether;
    function FundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subId, linkToken, account);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subId,
        address linkToken,
        address account
    ) public {
        if (block.chainid == ANVIL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
        }
    }
    function run() public {
        FundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function run() public {
        address mostRecentlyDeploy = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsignConfig(mostRecentlyDeploy);
    }

    function addConsumerUsignConfig(address mostRecentlyDeploy) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subId;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentlyDeploy, vrfCoordinator, subId, account);
    }

    function addConsumer(
        address mostRecentlyDeploy,
        address vrfCoordinator,
        uint256 subId,
        address account
    ) public {
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subId,
            mostRecentlyDeploy
        );
        vm.stopBroadcast();
    }
}
