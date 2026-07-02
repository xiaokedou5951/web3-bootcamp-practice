// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITokenBank {
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function balanceOf(address _user) external view returns (uint256);
}

contract SimpleDelegateContract {
    event Executed(address indexed to, uint256 value, bytes data);
    event Log(string message);
    event ApproveAndDepositCompleted(address indexed user, uint256 amount);
 
    struct Call {
        bytes data;
        address to;
        uint256 value;
    }
 
    // 批量执行多个调用
    function execute(Call[] memory calls) external payable {
        for (uint256 i = 0; i < calls.length; i++) {
            Call memory call = calls[i];
            (bool success, bytes memory result) = call.to.call{value: call.value}(call.data);
            require(success, string(result));
            emit Executed(call.to, call.value, call.data);
        }
    }

    // EIP-7702 初始化函数
    function initialize() external payable {
        emit Log('EIP-7702 Delegate Contract Initialized');
    }
    
    // 测试函数
    function ping() external {
        emit Log('Pong from EIP-7702!');
    }

    // 一键授权和存款函数
    function approveAndDeposit(address token, address tokenbank, uint256 amount) external {
        // 第一步：授权TokenBank合约使用token
        IERC20(token).approve(tokenbank, amount);
        
        // 第二步：调用TokenBank的deposit函数
        ITokenBank(tokenbank).deposit(amount);
        
        emit ApproveAndDepositCompleted(msg.sender, amount);
    }

    // 支持接收ETH
    receive() external payable {}
    
    // fallback函数
    fallback() external payable {}
} 