// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {StableCoin} from "../src/StableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDsc is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (StableCoin, DSCEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            config.activeNetworkConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast();
        StableCoin stableCoin = new StableCoin();
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(stableCoin));

        stableCoin.transferOwnership(address(engine));
        vm.stopBroadcast();

        return (stableCoin, engine, config);
    }
}
