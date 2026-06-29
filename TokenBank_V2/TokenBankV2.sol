// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ExtendedERC20.sol";
import "./ITokenReceiver.sol";
import "../TokenBank_V1/TokenBank.sol";

// TokenBankV2合约，支持直接通过transferWithCallback存入代币
contract TokenBankV2 is TokenBank, ITokenReceiver {
    // 扩展的ERC20代币合约地址
    ExtendedERC20 public extendedToken;
    
    // 构造函数，设置扩展的ERC20代币合约地址
    constructor(address _tokenAddress) TokenBank(_tokenAddress) {
        extendedToken = ExtendedERC20(_tokenAddress);
    }
    
    // 实现tokensReceived接口，处理通过transferWithCallback接收到的代币
    function tokensReceived(address from, uint256 amount) external override returns (bool) {
        // 检查调用者是否为代币合约
        require(msg.sender == address(extendedToken), "TokenBankV2: caller is not the token contract");
        
        // 更新用户的存款记录
        _deposits[from] += amount;
        
        // 触发存款事件
        emit Deposit(from, amount);
        
        return true;
    }
}