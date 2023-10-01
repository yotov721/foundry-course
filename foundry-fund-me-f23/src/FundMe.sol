// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";

contract FundMe is Ownable {
    using PriceConverter for uint256;

    // Constants do not take a storage slot -> Cost less gas
    // Immutable -> set only one time -> Cost less gas
    // stored inside the byte code of the contract
    uint256 public constant MINIMUM_USD = 5 * (10 ** 18);

    address[] public s_funders;
    mapping(address => uint256) private addressToAmountFunded;
    AggregatorV3Interface private s_priceFeed;

    constructor(address priceFeed) {
        // 0x694AA1769357215DE4FAC081bf1f309aDC325306
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function fund() public payable {
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "Didn't send enough ETH"
        );
        s_funders.push(msg.sender);
        addressToAmountFunded[msg.sender] += msg.value;
    }

    function cheaperWithdraw() public onlyOwner {
        uint256 fundersLength = s_funders.length;

        for (uint256 i = 0; i < fundersLength; i++) {
            addressToAmountFunded[s_funders[i]] = 0;
        }

        delete s_funders;

        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Withdraw failed");
    }

    function withdraw() public onlyOwner {
        for (uint256 i = 0; i < s_funders.length; i++) {
            addressToAmountFunded[s_funders[i]] = 0;
        }

        delete s_funders;

        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Withdraw failed");
    }

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    function getAddressToAmountFunded(
        address fundingAddress
    ) public view returns (uint256) {
        return addressToAmountFunded[fundingAddress];
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }
}
