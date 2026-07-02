// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Bank
 * @dev 资金管理合约，由治理合约管理
 */
contract Bank is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // 事件
    event Deposit(address indexed from, uint256 amount);
    event Withdraw(address indexed to, uint256 amount, string reason);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    constructor(address initialAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
        _grantRole(ADMIN_ROLE, initialAdmin);
    }

    /**
     * @dev 接收以太币存款
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev 存款函数
     */
    function deposit() external payable {
        require(msg.value > 0, "Bank: deposit amount must be greater than 0");
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev 提取资金 - 仅管理员可调用
     * @param to 提取到的地址
     * @param amount 提取金额
     * @param reason 提取原因
     */
    function withdraw(address payable to, uint256 amount, string memory reason) 
        external 
        onlyRole(ADMIN_ROLE) 
        nonReentrant 
    {
        require(to != address(0), "Bank: cannot withdraw to zero address");
        require(amount > 0, "Bank: withdraw amount must be greater than 0");
        require(address(this).balance >= amount, "Bank: insufficient balance");

        (bool success, ) = to.call{value: amount}("");
        require(success, "Bank: withdraw failed");

        emit Withdraw(to, amount, reason);
    }

    /**
     * @dev 获取合约余额
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev 检查是否为管理员
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /**
     * @dev 添加管理员 - 仅超级管理员可调用
     */
    function addAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, newAdmin);
        emit AdminChanged(address(0), newAdmin);
    }

    /**
     * @dev 移除管理员 - 仅超级管理员可调用
     */
    function removeAdmin(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, admin);
        emit AdminChanged(admin, address(0));
    }

    /**
     * @dev 转移超级管理员权限
     */
    function transferSuperAdmin(address newSuperAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newSuperAdmin != address(0), "Bank: new super admin cannot be zero address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, newSuperAdmin);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // 确保新超级管理员也有管理员权限
        _grantRole(ADMIN_ROLE, newSuperAdmin);
    }
} 