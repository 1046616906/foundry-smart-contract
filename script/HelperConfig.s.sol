// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script} from "lib/forge-std/src/Script.sol";
import {
    VRFCoordinatorV2_5Mock
} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract ChainIdConfig {
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ANVIL_CHAIN_ID = 31337;
}

contract HelperConfig is ChainIdConfig, Script {
    error HelperConfig_NotFindChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        bytes32 keyHash;
        uint32 callbackGasLimit;
        address vrfCoordinator;
        uint256 subId;
        uint256 interval;
        address link;
    }
    mapping(uint256 => NetworkConfig) config;
    NetworkConfig public anvilConfig;
    constructor() {
        config[SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) internal returns (NetworkConfig memory) {
        if (config[chainId].vrfCoordinator != address(0)) {
            return config[chainId];
        } else if (block.chainid == ANVIL_CHAIN_ID) {
            return getAnvilConfig();
        } else {
            revert HelperConfig_NotFindChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                subId: 108676595255390158925884288886226485914029300675292554031389501149004825938295,
                interval: 30,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        if (anvilConfig.vrfCoordinator != address(0)) {
            return anvilConfig;
        }
        uint96 baseFee = 0.25 ether;
        uint96 gasPrice = 1e9;
        int256 wei_per_unit_link = -5e15;
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
                baseFee,
                gasPrice,
                wei_per_unit_link
            );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();
        anvilConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            subId: 0,
            interval: 30,
            link: address(linkToken)
        });
        return anvilConfig;
    }
}
