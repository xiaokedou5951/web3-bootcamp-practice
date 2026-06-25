// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Callee {
    function getData() public pure returns (uint256) {
        return 42;
    }
}

contract Caller {
    function callGetData(address callee) public view returns (uint256 data) {
        // call by staticcall
        (bool success, bytes memory returnData) = callee.staticcall(
            abi.encodeWithSignature("getData()")
        );
        
        require(success, "staticcall function failed");
        
        data = abi.decode(returnData, (uint256));
        return data;
    }
}