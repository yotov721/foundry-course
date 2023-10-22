// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {MockFailedMintDSC} from "../mocks/MockFailedMintDSC.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";

contract DSCEngineTest is Test {
    DeployDsc deployer;
    StableCoin stableCoin;
    DSCEngine engine;
    HelperConfig config;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    address public immutable USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether; // 10 * $2000 = $20 000 colalteral value
    uint256 public constant STARTING_ERC20_BALANCE = 20 ether;
    uint256 public constant AMOUNT_TO_MINT = 100 ether;

    function setUp() public {
        deployer = new DeployDsc();

        (stableCoin, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    //////////////
    // Constructor Tests
    //////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthsDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(stableCoin));
    }

    //////////////
    // Price Tests
    //////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;

        uint256 expectedUsd =
            (ethAmount * uint256(config.ETH_USD_PRICE()) * engine.getAdditionalFeedPrecision()) / engine.getPrecision();
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);

        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        // 1 ETH = $2000; $100 = 0.05 ETH
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    //////////////
    // depositCollateral Tests
    //////////////

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        // uint256 userBalanceWeth = engine.getCollateralBalanceOfUser(USER, weth);
        // console.log("User balance weth: %s", userBalanceWeth);
        _;
    }

    function testRevertIfCollateralIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock fakeToken = new ERC20Mock("FT", "FT", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);

        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__TokenNotAllowed.selector, address(fakeToken)));
        engine.depositCollateral(address(fakeToken), 10);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);

        uint256 expectedDscMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        console.log("Collateral value in usd: %s", collateralValueInUsd);

        assertEq(totalDscMinted, expectedDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    // This test requires custom setup
    function testCanDepositCollateralTransferFromFails() public {
        MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
        tokenAddresses.push(address(mockDsc));
        priceFeedAddresses.push(ethUsdPriceFeed);

        mockDsc.mint(USER, STARTING_ERC20_BALANCE);
        DSCEngine mockEngine = new DSCEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(mockDsc)
        );

        mockDsc.transferOwnership(address(mockEngine));

        vm.startPrank(USER);
        ERC20Mock(address(mockDsc)).approve(address(mockEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockEngine.depositCollateral(address(mockDsc), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    //////////////
    // mintDsc Tests
    //////////////

    function testCanMintDsc() public depositedCollateral {
        uint256 amountDscToMint = AMOUNT_COLLATERAL / 2;

        vm.prank(USER);
        engine.mintDsc(amountDscToMint);

        uint256 userBalance = stableCoin.balanceOf(USER);

        assertEq(amountDscToMint, userBalance);
    }

    // This test requires custom setup
    function testMintDscFailsToMint() public {
        MockFailedMintDSC mockStableCoin = new MockFailedMintDSC();
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);

        DSCEngine mockEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockStableCoin));
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();

        // console.log("price: %s", uint256(price));

        // AMOUNT_COLLATERAL * (price Of ETH / 2) = 1000, Max stable coin able to be minted
        // as collateral needs to be atleast 2x the minted stable coin
        uint256 amountDscToMint = ((AMOUNT_COLLATERAL * uint256(price)) / engine.getFeedPercision()) / 2;
        mockStableCoin.transferOwnership(address(mockEngine));

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(mockEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MintingFailed.selector);
        mockEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, amountDscToMint);
    }

    function testMintDscFailsToMintIfHealthFactorIsBroken() public depositedCollateral {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        uint256 amountToMint =
            (AMOUNT_COLLATERAL * (uint256(price) * engine.getAdditionalFeedPrecision())) / engine.getPrecision();

        uint256 expectedHealthFactor =
            engine.calculateHealthFactor(amountToMint, engine.getUsdValue(weth, AMOUNT_COLLATERAL));

        // console.log("Expected health factor %s", expectedHealthFactor);
        // console.log("Amount to mint %s", amountToMint);

        vm.startPrank(USER);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        engine.mintDsc(amountToMint);
    }

    //////////////
    // redeemCollateral Tests
    //////////////

    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(USER);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        uint256 userBalance = ERC20Mock(weth).balanceOf(USER);
        vm.stopPrank();

        assertEq(userBalance, STARTING_ERC20_BALANCE);
    }

    function testRedeemCollateralTransferFails() public depositedCollateral {
        MockFailedTransfer mockStableCoin = new MockFailedTransfer();
        tokenAddresses.push(address(mockStableCoin));
        priceFeedAddresses.push(ethUsdPriceFeed);

        DSCEngine mockEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockStableCoin));

        mockStableCoin.mint(USER, AMOUNT_COLLATERAL);
        mockStableCoin.transferOwnership(address(mockEngine));

        vm.startPrank(USER);
        ERC20Mock(address(mockStableCoin)).approve(address(mockEngine), AMOUNT_COLLATERAL);

        mockEngine.depositCollateral(address(mockStableCoin), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockEngine.redeemCollateral(address(mockStableCoin), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    //////////////
    // burnDsc Tests
    //////////////

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testBurnMoreThanUserHas() public {
        vm.prank(USER);
        vm.expectRevert();
        engine.burnDsc(1);
    }

    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        stableCoin.approve(address(engine), AMOUNT_TO_MINT);
        engine.burnDsc(AMOUNT_TO_MINT);
        vm.stopPrank();

        assertEq(stableCoin.balanceOf(USER), 0);
    }

    //////////////
    // redeemCollateralForDsc Tests
    //////////////

    function testRedeemCollateralForDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(USER);
        stableCoin.approve(address(engine), AMOUNT_TO_MINT);
        engine.redeemCollateralForDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    //////////////
    // View & Pure Function Tests
    //////////////

    function testGetCollateralBalanceOfUser() public depositedCollateral {
        uint256 collateralBalance = engine.getCollateralBalanceOfUser(USER, weth);
        assertEq(collateralBalance, AMOUNT_COLLATERAL);
    }

    function testProperlyReportsHealthFactor() public depositedCollateralAndMintedDsc {
        uint256 expectedHealthFactor = 100 ether;
        uint256 healthFactor = engine.getHealthFactor(USER);
        // $100 minted with $20,000 collateral at 50% liquidation threshold
        // means that we must have $200 collatareral at all times.
        // 20,000 / 2 = 10,000
        // 10,000 / 100 = 100 health factor
        assertEq(healthFactor, expectedHealthFactor);
    }
}
