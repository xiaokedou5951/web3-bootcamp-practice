// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract ERC721_Upgrade is Initializable, ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name, string memory symbol) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}