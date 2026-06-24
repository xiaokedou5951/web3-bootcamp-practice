// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./Ownable.sol";
contract Bank is Ownable {
    mapping(address => uint) public deposits;
    
    // 存储存款金额前3名的地址，按存款金额从高到低排序（topDepositors[0]为第一名）
    address[3] public topDepositors;

    uint8 private constant TOP_COUNT = 3;
    
    constructor() Ownable(msg.sender) payable {
        if (msg.value > 0) {
            deposits[msg.sender] += msg.value;
            updateTopDepositors(msg.sender);
        }
    }
    
    // 接收ETH并记录存款
    receive() external payable { 
        _handleDeposit();
    }
    
    // 存款函数，允许用户显式调用存款
    function deposit() external payable {
        _handleDeposit();
    }
    
    function _handleDeposit() internal {
        // 更新用户存款金额
        deposits[msg.sender] += msg.value;
        updateTopDepositors(msg.sender);
    }
    
    // 更新前3名存款人
    function updateTopDepositors(address depositor) internal {
        uint depositorBalance = deposits[depositor];
        
        // 检查存款人是否已在前3名中
        int8 existingIndex = -1;
        for (uint8 i = 0; i < TOP_COUNT; i++) {
            if (topDepositors[i] == depositor) {
                existingIndex = int8(i);
                break;
            }
        }
        
        // 如果已在前3名中，需要重新排序
        if (existingIndex >= 0) {
            // 将当前存款人移到正确的位置
            for (uint8 i = uint8(existingIndex); i > 0; i--) {
                if (deposits[topDepositors[i]] > deposits[topDepositors[i - 1]]) {
                    // 交换位置
                    address temp = topDepositors[i];
                    topDepositors[i] = topDepositors[i - 1];
                    topDepositors[i - 1] = temp;
                } else {
                    break;
                }
            }
        } else {
            // 如果不在前3名中，检查是否应该加入
            // 找到应该插入的位置
            int8 insertIndex = -1;
            for (uint8 i = 0; i < TOP_COUNT; i++) {
                if (topDepositors[i] == address(0) || depositorBalance > deposits[topDepositors[i]]) {
                    insertIndex = int8(i);
                    break;
                }
            }
            
            // 如果找到了插入位置
            if (insertIndex >= 0) {
                // 从后往前移动元素，为新元素腾出空间
                for (uint8 i = TOP_COUNT - 1; i > uint8(insertIndex); i--) {
                    topDepositors[i] = topDepositors[i - 1];
                }
                // 插入新的存款人
                topDepositors[uint8(insertIndex)] = depositor;
            }
        }
    }
    
    // 获取前3名存款人及其存款金额
    function getTopDepositors() external view returns (address[3] memory, uint[3] memory) {
        uint[3] memory amounts;
        for (uint8 i = 0; i < TOP_COUNT; i++) {
            amounts[i] = deposits[topDepositors[i]];
        }
        return (topDepositors, amounts);
    }
    
    // 只有管理员可以提取所有ETH
    function withdraw() external onlyOwner {
        // 获取合约余额
        uint balance = address(this).balance;
        
        // 确保有余额可提取
        require(balance > 0, "No balance to withdraw");
        
        // 将所有ETH转给管理员
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}