// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MyWallet {
    string public name;
    mapping(address => bool) private approved;

    modifier auth {
        address currentOwner;
        assembly {
            currentOwner := sload(2)
        }
        require(msg.sender == currentOwner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        assembly {
            sstore(2, caller())
        }
    }

    function transferOwnership(address _addr) public auth {
        require(_addr != address(0), "New owner is the zero address");

        address currentOwner;
        assembly {
            currentOwner := sload(2)
        }
        require(_addr != currentOwner, "New owner is the same as the old owner");

        assembly {
            sstore(2, _addr)
        }
    }

    function getOwner() public view returns (address ownerAddr) {
        assembly {
            ownerAddr := sload(2)
        }
    }
}
