// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Callee {
    uint256 value;

    function getValue() public view returns (uint256) {
        return value;
    }

    function setValue(uint256 value_) public payable {
        require(msg.value > 0);
        value = value_;
    }
}

contract Caller {
    function callSetValue(address callee, uint256 value) public returns (bool) {
        // call setValue()
        (bool success, )= callee.call{value: 1 ether}(
            abi.encodeWithSignature("setValue(uint256)", value)
        );
        require(success, "call function failed");
        return success;
    }

    receive() external payable { }
}
