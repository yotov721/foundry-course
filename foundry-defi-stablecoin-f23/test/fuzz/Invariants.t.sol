// SPDX-License-Identifier: MIT

// Have our invariants AKA properties that should always hold

// What are our invariants ?
// 1. The total supply os DSC < total value of collateral
// 2. Getter view functions should never revert

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";
import {console} from "forge-std/console.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployDsc deployer;
    DSCEngine engine;
    StableCoin stableCoin;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployDsc();
        (stableCoin, engine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        // targetContract(address(engine));
        handler = new Handler(engine, stableCoin);

        targetContract(address(handler));
        // Don't call redeem collateral unless there is collateral to redeem
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all the collateral in the protocol
        // compare it toll all the debt (dsc)
        uint256 totalSupply = stableCoin.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("weth value: ", wethValue);
        console.log("wbtc value: ", wbtcValue);
        console.log("total supply: ", totalSupply);
        console.log("Times mint called: ", handler.timesMintIsCalled());

        // Invariant
        assert(wethValue + wbtcValue >= totalSupply);
        // Reverts every single call because it probably passes invalid collateral addresses,
        // due to the fact that they are generated at randeom
    }

    function invariant_gettersShouldNotRevert() public view {
        engine.getPrecision();
        engine.getFeedPercision();
    }
}
