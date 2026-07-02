// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {CallOptionToken} from "../src/CallOptionToken.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

contract CallOptionTokenTest is Test {
    CallOptionToken public optionToken;
    MockUSDT public usdt;
    
    address public issuer;
    address public user1;
    address public user2;
    
    uint256 public strikePrice = 2000 * 10**6;
    uint256 public expirationDate;
    uint256 public underlyingAmount = 0.001 ether;
    
    function setUp() public {
        issuer = makeAddr("issuer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        vm.deal(issuer, 100 ether);
        vm.deal(user1, 50 ether);
        vm.deal(user2, 50 ether);
        
        expirationDate = block.timestamp + 3600;
        
        vm.startPrank(issuer);
        usdt = new MockUSDT();
        
        optionToken = new CallOptionToken(
            "ETH Call Option",
            "ETHCALL",
            address(0),
            address(usdt),
            strikePrice,
            expirationDate,
            underlyingAmount
        );
        vm.stopPrank();
        
        usdt.mint(issuer, 500000 * 10**6);
        usdt.mint(user1, 1000000 * 10**6);
        usdt.mint(user2, 1000000 * 10**6);
        
        console.log("=== Initialization Complete ===");
        console.log("Issuer address:", issuer);
        console.log("Strike price:", strikePrice / 10**6, "USDT");
    }
    
    function test_CompleteOptionLifecycle() public {
        console.log("=== Complete Option Lifecycle Test ===");
        
        // Issue options
        vm.startPrank(issuer);
        uint256 ethToDeposit = 1 ether;
        uint256 expectedTokens = ethToDeposit / underlyingAmount;
        
        console.log("Issuer deposits ETH:", ethToDeposit);
        console.log("Expected option tokens:", expectedTokens);
        
        optionToken.issueOptions{value: ethToDeposit}(ethToDeposit);
        
        console.log("Issuer option balance:", optionToken.balanceOf(issuer));
        console.log("Total supply:", optionToken.totalSupply());
        vm.stopPrank();
        
        // User buys options
        vm.startPrank(user1);
        uint256 toBuy = 500;
        uint256 payment = (toBuy * strikePrice * 10) / 100;
        
        console.log("User1 buys tokens:", toBuy);
        console.log("Payment amount:", payment / 10**6, "USDT");
        console.log("User1 USDT balance before:", usdt.balanceOf(user1) / 10**6, "USDT");
        console.log("Required payment:", payment / 10**6, "USDT");
        
        usdt.approve(address(optionToken), payment);
        optionToken.buyOptions(toBuy, payment);
        
        console.log("User1 option balance:", optionToken.balanceOf(user1));
        vm.stopPrank();
        
        // User exercises options
        vm.startPrank(user1);
        uint256 toExercise = 300;
        uint256 exercisePayment = toExercise * strikePrice;
        
        console.log("User1 exercises:", toExercise);
        console.log("Exercise payment:", exercisePayment / 10**6, "USDT");
        
        usdt.approve(address(optionToken), exercisePayment);
        
        uint256 ethBefore = user1.balance;
        optionToken.exerciseOptions(toExercise);
        uint256 ethAfter = user1.balance;
        
        console.log("ETH received:", ethAfter - ethBefore);
        console.log("Remaining options:", optionToken.balanceOf(user1));
        vm.stopPrank();
        
        // Expire options
        vm.warp(expirationDate + 1);
        
        vm.startPrank(issuer);
        uint256 issuerEthBefore = issuer.balance;
        optionToken.expireOptions();
        uint256 issuerEthAfter = issuer.balance;
        
        console.log("Issuer ETH recovered:", issuerEthAfter - issuerEthBefore);
        console.log("Options expired:", optionToken.expired());
        vm.stopPrank();
        
        console.log("=== Test Complete ===");
    }
    
    function test_MultipleUsersScenario() public {
        console.log("=== Multiple Users Scenario Test ===");
        
        // 1. Issuer issues options
        vm.startPrank(issuer);
        uint256 ethToDeposit = 2 ether;
        optionToken.issueOptions{value: ethToDeposit}(ethToDeposit);
        console.log("Issued options for 2 ETH, total tokens:", optionToken.totalSupply());
        vm.stopPrank();
        
        // 2. User1 buys options
        vm.startPrank(user1);
        uint256 user1Buy = 800;
        uint256 user1Payment = (user1Buy * strikePrice * 10) / 100;
        usdt.approve(address(optionToken), user1Payment);
        optionToken.buyOptions(user1Buy, user1Payment);
        console.log("User1 bought", user1Buy, "option tokens");
        vm.stopPrank();
        
        // 3. User2 buys options
        vm.startPrank(user2);
        uint256 user2Buy = 600;
        uint256 user2Payment = (user2Buy * strikePrice * 10) / 100;
        usdt.approve(address(optionToken), user2Payment);
        optionToken.buyOptions(user2Buy, user2Payment);
        console.log("User2 bought", user2Buy, "option tokens");
        vm.stopPrank();
        
        console.log("Remaining issuer tokens:", optionToken.balanceOf(issuer));
        
        // 4. User1 exercises part of options
        vm.startPrank(user1);
        uint256 user1Exercise = 400;
        uint256 user1ExercisePayment = user1Exercise * strikePrice;
        usdt.approve(address(optionToken), user1ExercisePayment);
        
        uint256 user1EthBefore = user1.balance;
        optionToken.exerciseOptions(user1Exercise);
        uint256 user1EthAfter = user1.balance;
        
        console.log("User1 exercised", user1Exercise, "tokens, received ETH:", user1EthAfter - user1EthBefore);
        console.log("User1 remaining options:", optionToken.balanceOf(user1));
        vm.stopPrank();
        
        // 5. User2 exercises part of options
        vm.startPrank(user2);
        uint256 user2Exercise = 300;
        uint256 user2ExercisePayment = user2Exercise * strikePrice;
        usdt.approve(address(optionToken), user2ExercisePayment);
        
        uint256 user2EthBefore = user2.balance;
        optionToken.exerciseOptions(user2Exercise);
        uint256 user2EthAfter = user2.balance;
        
        console.log("User2 exercised", user2Exercise, "tokens, received ETH:", user2EthAfter - user2EthBefore);
        console.log("User2 remaining options:", optionToken.balanceOf(user2));
        vm.stopPrank();
        
        console.log("Contract remaining underlying:", optionToken.totalUnderlyingDeposited());
        console.log("Total supply after exercises:", optionToken.totalSupply());
        
        // 6. Fast forward to expiration and clean up
        vm.warp(expirationDate + 1);
        vm.startPrank(issuer);
        uint256 issuerEthBefore = issuer.balance;
        uint256 issuerUsdtBefore = usdt.balanceOf(issuer);
        
        optionToken.expireOptions();
        
        uint256 issuerEthAfter = issuer.balance;
        uint256 issuerUsdtAfter = usdt.balanceOf(issuer);
        
        console.log("After expiry - Issuer ETH recovered:", issuerEthAfter - issuerEthBefore);
        console.log("After expiry - Issuer USDT received:", (issuerUsdtAfter - issuerUsdtBefore) / 10**6, "USDT");
        console.log("Final total supply:", optionToken.totalSupply());
        vm.stopPrank();
        
        console.log("=== Multiple Users Test Complete ===");
    }
    
    function test_FailureScenarios() public {
        console.log("=== Failure Scenarios Test ===");
        
        // Issue some options first
        vm.startPrank(issuer);
        optionToken.issueOptions{value: 1 ether}(1 ether);
        vm.stopPrank();
        
        // Test 1: Non-issuer tries to issue options
        vm.startPrank(user1);
        vm.expectRevert("Only issuer can call this function");
        optionToken.issueOptions{value: 0.1 ether}(0.1 ether);
        vm.stopPrank();
        console.log("[PASS] Non-issuer cannot issue options");
        
        // Test 2: Exercise more than balance
        vm.startPrank(user1);
        vm.expectRevert("Insufficient option tokens");
        optionToken.exerciseOptions(100);
        vm.stopPrank();
        console.log("[PASS] Cannot exercise more than balance");
        
        // Test 3: Buy options with insufficient payment
        vm.startPrank(user1);
        uint256 toBuy = 100;
        uint256 insufficientPayment = 1000 * 10**6; // Much less than required
        usdt.approve(address(optionToken), insufficientPayment);
        vm.expectRevert("Payment not sufficient");
        optionToken.buyOptions(toBuy, insufficientPayment);
        vm.stopPrank();
        console.log("[PASS] Cannot buy with insufficient payment");
        
        // Test 4: Exercise after expiration
        vm.warp(expirationDate + 1);
        
        // Give user1 some option tokens first
        vm.startPrank(issuer);
        optionToken.transfer(user1, 100);
        vm.stopPrank();
        
        vm.startPrank(user1);
        vm.expectRevert("Option has expired");
        optionToken.exerciseOptions(50);
        vm.stopPrank();
        console.log("[PASS] Cannot exercise after expiration");
        
        // Test 5: Repeated expiry destruction
        vm.startPrank(issuer);
        optionToken.expireOptions();
        vm.expectRevert("Options already expired");
        optionToken.expireOptions();
        vm.stopPrank();
        console.log("[PASS] Cannot expire options twice");
        
        console.log("=== All Failure Tests Passed ===");
    }
} 