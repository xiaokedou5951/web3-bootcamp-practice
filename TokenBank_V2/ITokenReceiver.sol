// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 定义接收代币回调的接口
interface ITokenReceiver {
    function tokensReceived(address from, uint256 amount) external returns (bool);
}