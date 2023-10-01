// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {PriceConverter} from "./PriceConverter.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract FundMe is Ownable {
    using PriceConverter for uint256;

    // Constants do not take a storage slot -> Cost less gas
    // Immutable -> set only one time -> Cost less gas
    // stored inside the byte code of the contract
    uint256 public constant MINIMUM_USD = 5 * (10 ** 18);

    address[] public funders;
    mapping(address => uint256) public addressToAmountFunded;

    function fund() public payable onlyOwner {
        require(msg.value.getConversionRate() >= MINIMUM_USD, "Didn't send enough ETH");
        funders.push(msg.sender);
        addressToAmountFunded[msg.sender] += msg.value;
    }

    function withdraw() public {
        for (uint256 i = 0; i < funders.length; i++) {
            addressToAmountFunded[funders[i]] = 0;
        }

        delete funders;

        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }
}
