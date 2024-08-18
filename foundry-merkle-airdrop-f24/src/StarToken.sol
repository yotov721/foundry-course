// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract StarToken is ERC20, Ownable {
    constructor() ERC20("Star", "STR") Ownable(msg.sender) { }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }
}