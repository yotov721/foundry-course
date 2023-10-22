// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {StableCoin} from "./StableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*
 * Designed to be as minimal as possible and have tokens maintain 1 token == $1 peg
 * Properties
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algoritmically Stable
 *
 * The system should always be overcollateralized
 *
 * @notice This contract handles logic for minting and redeeming, as well as depositing and withdrawing collateral
 */
contract DSCEngine is ReentrancyGuard {
    ///////////////////
    // Errors
    ///////////////////
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error DSCEngine__TokenNotAllowed(address token);
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 userHealthFactor);
    error DSCEngine__MintingFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    ///////////////////
    // State Variables
    ///////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHHOLD = 50; // 200 % OVER COLLATERALISED
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    StableCoin private immutable i_dsc;

    ///////////////////
    // Events
    ///////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(address indexed from, address indexed to, address indexed token, uint256 amount);

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed(token);
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        // USD Price feeds
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = StableCoin(dscAddress);
    }

    /**
     * @notice Deposits collateral and mints stable coin in one transaction
     */
    function depositCollateralAndMintDSC(address tokenCollateral, uint256 amountCollateral, uint256 amountToMint)
        external
    {
        depositCollateral(tokenCollateral, amountCollateral);
        mintDsc(amountToMint);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral depositing
     * @param amountCollateral: The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateral, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateral)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateral] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateral, amountCollateral);

        bool success = IERC20(tokenCollateral).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /*
     * Burns DSC and redeems collateral in one transaction
     */
    function redeemCollateralForDSC(address tokenCollateral, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateral, amountCollateral);
    }

    /*
     * In order to redeem collateral health factor needs to be over 1 when pulled
     * Reverts if health factor is less than 1
     */
    function redeemCollateral(address tokenCollateral, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(tokenCollateral, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @notice: the use must have more collateral than the minimum threshold
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintingFailed();
        }
    }

    function burnDsc(uint256 amount) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // If some positions start nearing undercollateralization, they need to be liquidated
    // $100 ETH backing $50 DSC
    // $20 ETH backing $50 DSC <- 1 DSC worth 20/50 $

    // $75 ETH backing $50 DSC
    // Liquidator - take $75 backing and burn $50 DSC and win in the exchange

    /**
     * @param collateral The ERC20 collateral address to liquidate from the user
     * @param user The user who's health factor is bellow MIN_HEALTH_FACTOR
     * @param debtToCover The amount of DSC to burn in order to improve the user's health factor
     *
     * @notice You can partially liquidate a user
     * @notice You will get a liquidation bonus for taking the user's funds
     * @notice This function working assumes that the protocol will be roughly 150% overcollateralized in order for this to work.
     * @notice A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate anyone.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // Check health factor
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }

        // Burn their DSC debt
        // Take their collateral - BAd User: $140 ETH, $100 DSC
        // debtToCover = $100
        // $100 of DSC == amount ETH ?
        // 1 ETH = $2000 -> 0.05 ETH
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // Give the liquidator a bonus -> 10%
        // $110 of WETH for 100 DSC
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);
        // Burn DSC
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);

        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }

        // !!! Revert if health factor is broken for msg.sender
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view {}

    //////////////////////////////
    // Private & Internal View & Pure Functions
    //////////////////////////////

    /**
     * @notice Do NOT call unless calling function is checking health factors
     */
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }

        i_dsc.burn(amountDscToBurn);
    }

    function _redeemCollateral(address tokenCollateral, uint256 amountCollateral, address from, address to) private {
        s_collateralDeposited[from][tokenCollateral] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateral, amountCollateral);

        bool success = IERC20(tokenCollateral).transfer(to, amountCollateral);

        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /*
     * @return: Returns how close to liquidataion a user is
     * If a user goes bellow 1, they can get liquidated
     */
    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);

        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        // Escape division by 0
        if (totalDscMinted == 0) return type(uint256).max;

        // Liquidated example:
        // $150 ETH / 100 DSC = 1.5
        // 150 * 50 = 7500 / 100 = (75 / 100) < 1

        // NOT liquidated example:
        // $1000 ETH / 100 DSC = 10
        // 1000 * 50 = 50 000 / 100 = (500 / 100) > 1
        uint256 collateralAdjustedForThreshhold =
            (collateralValueInUsd * LIQUIDATION_THRESHHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshhold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    //////////////////////////////
    // Public & External View & Pure Functions
    //////////////////////////////

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        // price of ETH
        // $2000 / ETH. $1000 = 0.5 ETH
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getFeedPercision() external pure returns (uint256) {
        return PRECISION / ADDITIONAL_FEED_PRECISION;
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }
}
