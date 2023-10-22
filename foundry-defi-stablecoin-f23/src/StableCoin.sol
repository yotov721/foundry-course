// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Collateral: ETH & BTC
 * Minting: Algorithmic
 * Stability: Pegged to USD
 */
contract StableCoin is ERC20Burnable, Ownable {
    error StableCoin__MustBeMoreThanZero();
    error StableCoin__BurnAmountExceedsBalance();
    error StableCoin__NonZeroAddress();

    constructor() ERC20("Stablecoin", "DSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount <= 0) {
            revert StableCoin__MustBeMoreThanZero();
        }

        if (balance < _amount) {
            revert StableCoin__BurnAmountExceedsBalance();
        }

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert StableCoin__NonZeroAddress();
        }

        if (_amount <= 0) {
            revert StableCoin__MustBeMoreThanZero();
        }

        _mint(_to, _amount);

        return true;
    }
}
