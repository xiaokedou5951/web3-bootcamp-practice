// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleLeverageDEX.sol";
import "../src/MockUSDC.sol";

contract SimpleLeverageDEXTest is Test {
    SimpleLeverageDEX public dex;
    MockUSDC public usdc;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public liquidator = address(0x3);
    
    uint256 constant INITIAL_VETH = 1000 * 1e18; // 1000 ETH
    uint256 constant INITIAL_VUSDC = 2000000 * 1e6; // 200万 USDC (价格约 2000 USDC/ETH)
    
    function setUp() public {
        // 部署合约
        usdc = new MockUSDC();
        dex = new SimpleLeverageDEX(INITIAL_VETH, INITIAL_VUSDC, address(usdc));
        
        // 给测试用户分发 USDC
        usdc.mint(user1, 10000 * 1e6); // 10000 USDC
        usdc.mint(user2, 10000 * 1e6); // 10000 USDC
        usdc.mint(liquidator, 10000 * 1e6); // 10000 USDC
        
        // 用户授权 DEX 使用 USDC
        vm.prank(user1);
        usdc.approve(address(dex), type(uint256).max);
        
        vm.prank(user2);
        usdc.approve(address(dex), type(uint256).max);
        
        vm.prank(liquidator);
        usdc.approve(address(dex), type(uint256).max);
    }
    
    function testInitialState() public view {
        assertEq(dex.vETHAmount(), INITIAL_VETH);
        assertEq(dex.vUSDCAmount(), INITIAL_VUSDC);
        assertEq(dex.vK(), INITIAL_VETH * INITIAL_VUSDC);
        assertEq(dex.getCurrentPrice(), 2000 * 1e18); // 2000 USDC per ETH (18 decimals)
    }
    
    function testOpenLongPosition() public {
        uint256 margin = 1000 * 1e6; // 1000 USDC
        uint256 leverage = 3;
        
        // 用户1开多仓
        vm.prank(user1);
        dex.openPosition(margin, leverage, true);
        
        // 检查头寸信息
        (uint256 posMargin, uint256 borrowed, int256 position, uint256 entryPrice, bool isLong) = dex.positions(user1);
        
        assertEq(posMargin, margin);
        assertEq(borrowed, margin * (leverage - 1));
        assertTrue(position > 0); // 多仓为正
        assertEq(entryPrice, 2000 * 1e18); // 修正价格期望值
        assertTrue(isLong);
        
        // 检查虚拟池状态改变
        assertTrue(dex.vETHAmount() < INITIAL_VETH);
        assertTrue(dex.vUSDCAmount() > INITIAL_VUSDC);
    }
    
    function testOpenShortPosition() public {
        uint256 margin = 1000 * 1e6; // 1000 USDC
        uint256 leverage = 2;
        
        // 用户2开空仓
        vm.prank(user2);
        dex.openPosition(margin, leverage, false);
        
        // 检查头寸信息
        (uint256 posMargin, uint256 borrowed, int256 position, uint256 entryPrice, bool isLong) = dex.positions(user2);
        
        assertEq(posMargin, margin);
        assertEq(borrowed, margin * (leverage - 1));
        assertTrue(position < 0); // 空仓为负
        assertEq(entryPrice, 2000 * 1e18); // 修正价格期望值
        assertFalse(isLong);
        
        // 检查虚拟池状态改变
        assertTrue(dex.vETHAmount() > INITIAL_VETH);
        assertTrue(dex.vUSDCAmount() < INITIAL_VUSDC);
    }
    
    function testClosePosition() public {
        uint256 margin = 1000 * 1e6; // 1000 USDC
        uint256 leverage = 3;
        
        // 用户1开多仓
        vm.prank(user1);
        dex.openPosition(margin, leverage, true);
        
        // 平仓
        vm.prank(user1);
        dex.closePosition();
        
        // 检查头寸已被删除
        (uint256 posMargin, , int256 position, ,) = dex.positions(user1);
        assertEq(posMargin, 0);
        assertEq(position, 0);
    }
    
    function testLiquidation() public {
        uint256 margin = 1000 * 1e6; // 1000 USDC
        uint256 leverage = 10; // 高杠杆更容易被清算
        
        // 用户1开多仓
        vm.prank(user1);
        dex.openPosition(margin, leverage, true);
        
        // 模拟价格大幅下跌，触发清算条件
        vm.prank(user2);
        dex.openPosition(8000 * 1e6, 5, false); // 大额空仓，大幅推低价格
        
        // 检查是否可以清算
        bool canLiquidate = dex.isLiquidatable(user1);
        if (canLiquidate) {
            // 清算人执行清算
            uint256 liquidatorBalanceBefore = usdc.balanceOf(liquidator);
            vm.prank(liquidator);
            dex.liquidatePosition(user1);
            
            // 检查清算奖励
            uint256 liquidatorBalanceAfter = usdc.balanceOf(liquidator);
            uint256 expectedReward = margin * 5 / 100; // 5% 清算奖励
            assertEq(liquidatorBalanceAfter - liquidatorBalanceBefore, expectedReward);
            
            // 检查被清算用户的头寸已被删除
            (uint256 posMargin, , int256 position, ,) = dex.positions(user1);
            assertEq(posMargin, 0);
            assertEq(position, 0);
        }
    }
    
    function testCannotLiquidateOwnPosition() public {
        uint256 margin = 1000 * 1e6;
        uint256 leverage = 5;
        
        // 用户1开仓
        vm.prank(user1);
        dex.openPosition(margin, leverage, true);
        
        // 尝试自己清算自己的头寸（应该失败）
        vm.prank(user1);
        vm.expectRevert("Cannot liquidate own position");
        dex.liquidatePosition(user1);
    }
    
    function testInvalidLeverageLevel() public {
        uint256 margin = 1000 * 1e6;
        
        // 尝试使用0杠杆
        vm.prank(user1);
        vm.expectRevert("Invalid leverage level");
        dex.openPosition(margin, 0, true);
        
        // 尝试使用过高杠杆
        vm.prank(user1);
        vm.expectRevert("Invalid leverage level");
        dex.openPosition(margin, 11, true);
    }
    
    function testPriceMovement() public {
        uint256 initialPrice = dex.getCurrentPrice();
        
        // 大量买入应该推高价格
        vm.prank(user1);
        dex.openPosition(2000 * 1e6, 3, true);
        
        uint256 priceAfterBuy = dex.getCurrentPrice();
        assertTrue(priceAfterBuy > initialPrice);
        
        // 大量卖出应该压低价格
        vm.prank(user2);
        dex.openPosition(2000 * 1e6, 3, false);
        
        uint256 priceAfterSell = dex.getCurrentPrice();
        assertTrue(priceAfterSell < priceAfterBuy);
    }
} 