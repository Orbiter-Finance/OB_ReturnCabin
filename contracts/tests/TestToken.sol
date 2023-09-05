// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 999999 ether);
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount * (1 ether));
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
