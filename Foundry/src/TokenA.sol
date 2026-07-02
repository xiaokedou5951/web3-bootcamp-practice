// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenA is ERC20 {
    constructor() ERC20("Token A", "TKA") {
        _mint(msg.sender, 1000000 * 1e18); // 铸造 100万个代币
    }
} 