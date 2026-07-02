// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Vesting.sol";
import "../src/TestToken.sol";

contract VestingTest is Test {
    // 合约
    TokenVesting public vesting;
    TestToken public token;
    
    // 测试地址
    address public deployer = address(1);
    address public beneficiary = address(2);
    
    // 常量
    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 10**18; // 1000万代币
    uint256 public constant VESTING_AMOUNT = 1_000_000 * 10**18;  // 100万代币
    
    // 时间常量
    uint256 public constant ONE_MONTH = 30 days;
    uint256 public constant ONE_YEAR = 365 days;
    uint256 public constant CLIFF_DURATION = 365 days; // 12个月锁定期
    uint256 public constant VESTING_DURATION = 730 days; // 24个月线性释放期
    
    function setUp() public {
        // 设置deployer为msg.sender
        vm.startPrank(deployer);
        
        // 部署测试代币
        token = new TestToken("Test Token", "TEST", INITIAL_SUPPLY);
        
        // 部署Vesting合约
        vesting = new TokenVesting(IERC20(address(token)), beneficiary);
        
        // 批准并存入代币到Vesting合约
        token.approve(address(vesting), VESTING_AMOUNT);
        vesting.deposit(VESTING_AMOUNT);
        
        vm.stopPrank();
    }
    
    // 测试初始状态
    function testInitialState() public {
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(vesting.totalAmount(), VESTING_AMOUNT);
        assertEq(vesting.releasedAmount(), 0);
        assertEq(token.balanceOf(address(vesting)), VESTING_AMOUNT);
        assertEq(token.balanceOf(beneficiary), 0);
    }
    
    // 测试锁定期内无法提取
    function testCannotReleaseBeforeCliff() public {
        // 设置受益人
        vm.startPrank(beneficiary);
        
        // 尝试在锁定期内提取，应该失败
        vm.expectRevert("No tokens available for release");
        vesting.release();
        
        // 推进时间但仍在锁定期内
        vm.warp(block.timestamp + 11 * ONE_MONTH);
        
        // 仍然无法提取
        vm.expectRevert("No tokens available for release");
        vesting.release();
        
        vm.stopPrank();
    }
    
    // 测试锁定期后第一次提取
    function testReleaseAfterCliff() public {
        // 推进时间到锁定期结束后一个月
        vm.warp(block.timestamp + ONE_YEAR + ONE_MONTH);
        
        // 计算应该释放的数量 (1/24 的总量)
        uint256 expectedRelease = VESTING_AMOUNT / 24;
        
        // 验证可释放金额
        assertApproxEqRel(vesting.getReleasableAmount(), expectedRelease, 0.02e18); // 允许2%误差
        
        // 受益人提取代币
        vm.startPrank(beneficiary);
        vesting.release();
        vm.stopPrank();
        
        // 验证已释放金额和余额
        assertApproxEqRel(vesting.releasedAmount(), expectedRelease, 0.02e18);
        assertApproxEqRel(token.balanceOf(beneficiary), expectedRelease, 0.02e18);
    }
    
    // 测试线性释放
    function testLinearRelease() public {
        // 循环测试不同月份的释放量
        for (uint256 i = 0; i < 24; i++) {
            // 跳过锁定期
            uint256 timeToWarp = ONE_YEAR + (i + 1) * ONE_MONTH;
            vm.warp(block.timestamp + timeToWarp);
            
            // 计算应该释放的总量
            uint256 expectedTotalVested = (i + 1) * VESTING_AMOUNT / 24;
            
            // 验证已解锁的总量
            assertApproxEqRel(vesting.getVestedAmount(), expectedTotalVested, 0.02e18);
            
            // 重置时间继续下一次循环
            vm.warp(block.timestamp - timeToWarp);
        }
    }
    
    // 测试释放过程
    function testCompleteVestingSchedule() public {
        // 按照3个月的间隔来测试释放
        uint256[] memory checkpoints = new uint256[](9);
        checkpoints[0] = ONE_YEAR;                       // 12个月（锁定期结束）
        checkpoints[1] = ONE_YEAR + 3 * ONE_MONTH;       // 15个月
        checkpoints[2] = ONE_YEAR + 6 * ONE_MONTH;       // 18个月
        checkpoints[3] = ONE_YEAR + 9 * ONE_MONTH;       // 21个月
        checkpoints[4] = ONE_YEAR + 12 * ONE_MONTH;      // 24个月
        checkpoints[5] = ONE_YEAR + 15 * ONE_MONTH;      // 27个月
        checkpoints[6] = ONE_YEAR + 18 * ONE_MONTH;      // 30个月
        checkpoints[7] = ONE_YEAR + 21 * ONE_MONTH;      // 33个月
        checkpoints[8] = ONE_YEAR + 24 * ONE_MONTH;      // 36个月（完全释放）
        
        uint256 totalReleased = 0;
        
        for (uint256 i = 0; i < checkpoints.length; i++) {
            // 跳到指定时间点
            vm.warp(block.timestamp + checkpoints[i]);
            
            // 计算这个时间点应该已解锁的总量
            uint256 vestedAmount = vesting.getVestedAmount();
            
            // 计算可释放的数量
            uint256 releasableAmount = vesting.getReleasableAmount();
            
            // 如果有可释放的代币，则释放
            if (releasableAmount > 0) {
                vm.startPrank(beneficiary);
                vesting.release();
                vm.stopPrank();
                
                totalReleased += releasableAmount;
                
                // 验证已释放的总量和受益人的余额
                assertEq(vesting.releasedAmount(), totalReleased);
                assertEq(token.balanceOf(beneficiary), totalReleased);
            }
            
            // 重置时间继续下一次循环
            vm.warp(block.timestamp - checkpoints[i]);
        }
        
        // 最后一次检查，应该全部释放
        vm.warp(block.timestamp + ONE_YEAR + VESTING_DURATION);
        
        // 受益人提取剩余代币
        vm.startPrank(beneficiary);
        vesting.release();
        vm.stopPrank();
        
        // 验证所有代币都已释放
        assertEq(vesting.releasedAmount(), VESTING_AMOUNT);
        assertEq(token.balanceOf(beneficiary), VESTING_AMOUNT);
        assertEq(vesting.getReleasableAmount(), 0);
        assertEq(vesting.getRemainingAmount(), 0);
        assertTrue(vesting.isFullyVested());
    }
    
    // 测试辅助函数
    function testHelperFunctions() public {
        // 检查初始状态下的辅助函数
        assertEq(vesting.getDaysFromStart(), 0);
        assertEq(vesting.getDaysUntilCliff(), 365);
        assertFalse(vesting.isCliffPassed());
        assertFalse(vesting.isFullyVested());
        assertEq(vesting.getVestingProgress(), 0);
        
        // 推进到锁定期结束
        vm.warp(block.timestamp + ONE_YEAR);
        
        // 检查锁定期结束时的辅助函数
        assertEq(vesting.getDaysFromStart(), 365);
        assertEq(vesting.getDaysUntilCliff(), 0);
        assertTrue(vesting.isCliffPassed());
        assertFalse(vesting.isFullyVested());
        assertEq(vesting.getVestingProgress(), 0);
        
        // 推进到锁定期结束后中间阶段
        vm.warp(block.timestamp + 365 days);
        
        // 检查中间阶段的辅助函数
        assertEq(vesting.getDaysFromStart(), 730);
        assertEq(vesting.getDaysUntilCliff(), 0);
        assertTrue(vesting.isCliffPassed());
        assertFalse(vesting.isFullyVested());
        assertEq(vesting.getVestingProgress(), 5000); // 50%
        
        // 推进到完全释放
        vm.warp(block.timestamp + 365 days);
        
        // 检查完全释放时的辅助函数
        assertTrue(vesting.isCliffPassed());
        assertTrue(vesting.isFullyVested());
        assertEq(vesting.getVestingProgress(), 10000); // 100%
    }
    
    // 测试非受益人无法提取
    function testOnlyBeneficiaryCanRelease() public {
        // 推进到有可释放代币的时间点
        vm.warp(block.timestamp + ONE_YEAR + 6 * ONE_MONTH);
        
        // 非受益人尝试提取
        vm.startPrank(deployer);
        vm.expectRevert("Only beneficiary can release tokens");
        vesting.release();
        vm.stopPrank();
    }
}