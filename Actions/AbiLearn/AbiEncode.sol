// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ABIEncoder {
    function encodeUint(uint256 value) public pure returns (bytes memory) {
        return abi.encode(value);
    }

    function encodeMultiple(
        uint num,
        string memory text
    ) public pure returns (bytes memory) {
       return abi.encode(num, text);
    }
}

contract ABIDecoder {
    function decodeUint(bytes memory data) public pure returns (uint) {
        uint value = abi.decode(data, (uint));
        return value;
    }

    function decodeMultiple(
        bytes memory data
    ) public pure returns (uint, string memory) {
        (uint num, string memory text) = abi.decode(data,(uint, string));
        return (num, text);
    }
}