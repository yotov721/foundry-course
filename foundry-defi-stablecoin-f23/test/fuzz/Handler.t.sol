// Handler is going to narrow down the way we call functions -> don't waste runs
// Example: Don't revert for invalid token collateral address

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {console} from "forge-std/console.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

// Third party contracts can be hadled
// Price Feeds

contract Handler is Test {
    DSCEngine engine;
    StableCoin stableCoin;

    ERC20Mock weth;
    ERC20Mock wbtc;
    MockV3Aggregator ethUsdPriceFeed;

    uint256 public timesMintIsCalled;
    address[] public usersWithdeCollateralDeposited;

    uint256 MAX_DEPOSID_SIZE = type(uint96).max;

    constructor(DSCEngine _engine, StableCoin _stableCoin) {
        engine = _engine;
        stableCoin = _stableCoin;

        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(engine.getCollateralTokenPriceFeed(address(weth)));
    }

    function deposidCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock tokenCollateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSID_SIZE);

        vm.startPrank(msg.sender);
        tokenCollateral.mint(msg.sender, amountCollateral);
        tokenCollateral.approve(address(engine), amountCollateral);
        engine.depositCollateral(address(tokenCollateral), amountCollateral);
        vm.stopPrank();

        // double push
        usersWithdeCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock tokenCollateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxRedeemableCollateral = engine.getCollateralBalanceOfUser(msg.sender, address(tokenCollateral));
        amountCollateral = bound(amountCollateral, 0, maxRedeemableCollateral);

        if (amountCollateral == 0) {
            return;
        }

        engine.redeemCollateral(address(tokenCollateral), amountCollateral);
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if (usersWithdeCollateralDeposited.length == 0) {
            return;
        }

        address sender = usersWithdeCollateralDeposited[addressSeed % usersWithdeCollateralDeposited.length];

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);

        if (maxDscToMint <= 0) {
            return;
        }

        amount = bound(amount, 1, uint256(maxDscToMint));

        vm.prank(sender);
        engine.mintDsc(amount);

        timesMintIsCalled++;
    }

    // If collateral price falls rapidly the protocol breaks
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPrice = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPrice);
    // }

    // Helper functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
