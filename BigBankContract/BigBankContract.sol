// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Bank} from "./BankContract.sol";

interface IBank {
    function deposit() external payable;
    function getTopDepositors() external view returns (address[3] memory, uint[3] memory);
    function withdraw() external;
    function owner() external view returns (address);
}

contract BigBank is Bank {
    
    constructor() {
        
    }
    
    // 函数修改器modifier要求存款金额大于0.001 ether才能存款
    modifier depositAmountGreaterThan001() {
        require(msg.value > 0.001 ether, "Deposit amount must be greater than 0.001 ether");
        _;
    }
    // 显式转账需要满足条件
    function deposit() external payable override depositAmountGreaterThan001 {
        _handleDeposit();
    }

    // 直接转账也需要满足条件
    receive() external payable override depositAmountGreaterThan001 {
        // require(msg.value > 0.001 ether, "Deposit amount must be greater than 0.001 ether");
        _handleDeposit();
    }

    // 实现BigBank 合约支持转移管理员的功能，委托给transferOwnership来实现
    function changeAdmin(address newAdmin) external {
        transferOwnership(newAdmin);
    }
}

contract Admin {
    address public immutable admin;
    
    constructor() {
        admin = msg.sender;
    }
    
    // 添加receive函数以接收ETH
    receive() external payable {}
    
    // 在 Solidity 中，接口类型参数在底层就是 address 类型。
    // 当你传入一个合约地址时，Solidity 会自动将其当作该接口类型来处理，从而可以调用接口中定义的方法。
    function adminWithdraw(IBank bank) external {
        require(msg.sender == admin, "Only admin can withdraw");
        // 确保Bank合约的admin是Admin合约地址
        require(bank.owner() == address(this), "Bank admin must be this Admin contract");
        bank.withdraw();
    }
    
    // 添加函数让Admin合约的admin可以提取合约中的ETH
    function withdrawToOwner() external {
        require(msg.sender == admin, "Only admin can withdraw");
        uint balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success, ) = admin.call{value: balance}("");
        require(success, "Withdrawal failed");
    }
}