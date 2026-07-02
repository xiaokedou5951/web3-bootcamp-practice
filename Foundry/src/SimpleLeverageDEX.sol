// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 极简的杠杆 DEX 实现， 完成 TODO 代码部分
contract SimpleLeverageDEX {

    uint public vK;  // 100000 
    uint public vETHAmount;
    uint public vUSDCAmount;

    IERC20 public USDC;  // 自己创建一个币来模拟 USDC

    struct PositionInfo {
        uint256 margin; // 保证金    // 真实的资金， 如 USDC 
        uint256 borrowed; // 借入的资金
        int256 position;    // 虚拟 eth 持仓
        uint256 entryPrice; // 开仓价格 (USDC per ETH * 1e18)
        bool isLong; // 是否做多
    }
    mapping(address => PositionInfo) public positions;

    event PositionOpened(address indexed user, uint256 margin, uint256 leverage, bool isLong, int256 position);
    event PositionClosed(address indexed user, int256 pnl);
    event PositionLiquidated(address indexed user, address indexed liquidator, int256 pnl);

    constructor(uint vEth, uint vUSDC, address _usdc) {
        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC;
        USDC = IERC20(_usdc);
    }

    // 获取当前虚拟价格 (USDC per ETH)
    function getCurrentPrice() public view returns (uint256) {
        // vUSDCAmount 是 6 位小数，vETHAmount 是 18 位小数
        // 为了得到 18 位小数的价格，需要乘以额外的 1e12
        return (vUSDCAmount * 1e18 * 1e12) / vETHAmount;
    }

    // 开启杠杆头寸
    function openPosition(uint256 _margin, uint level, bool long) external {
        require(positions[msg.sender].position == 0, "Position already open");
        require(level > 0 && level <= 10, "Invalid leverage level");

        PositionInfo storage pos = positions[msg.sender];

        USDC.transferFrom(msg.sender, address(this), _margin); // 用户提供保证金
        uint256 amount = _margin * level;
        uint256 borrowAmount = amount - _margin;

        pos.margin = _margin;
        pos.borrowed = borrowAmount;
        pos.entryPrice = getCurrentPrice();
        pos.isLong = long;

        if (long) {
            // 做多：用借来的资金购买虚拟 ETH
            // amount 是 USDC (6位小数)，getCurrentPrice() 返回 18位小数的价格
            // 需要将 amount 转换为 18位小数再除以价格
            uint256 ethToBuy = (amount * 1e12 * 1e18) / getCurrentPrice();
            require(ethToBuy < vETHAmount, "Insufficient virtual ETH liquidity");
            
            // 更新虚拟池状态
            uint256 newVETH = vETHAmount - ethToBuy;
            uint256 newVUSDC = vK / newVETH;
            
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
            
            pos.position = int256(ethToBuy);
        } else {
            // 做空：借入虚拟 ETH 并卖出
            // amount 是 USDC (6位小数)，getCurrentPrice() 返回 18位小数的价格
            // 需要将 amount 转换为 18位小数再除以价格
            uint256 ethToSell = (amount * 1e12 * 1e18) / getCurrentPrice();
            
            // 更新虚拟池状态
            uint256 newVETH = vETHAmount + ethToSell;
            uint256 newVUSDC = vK / newVETH;
            
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
            
            pos.position = -int256(ethToSell);
        }

        emit PositionOpened(msg.sender, _margin, level, long, pos.position);
    }

    // 关闭头寸并结算, 不考虑协议亏损
    function closePosition() external {
        PositionInfo memory pos = positions[msg.sender];
        require(pos.position != 0, "No open position");

        int256 pnl = calculatePnL(msg.sender);
        
        // 恢复虚拟池状态
        if (pos.isLong) {
            // 平多仓：卖回虚拟 ETH
            uint256 ethToSell = uint256(pos.position);
            uint256 newVETH = vETHAmount + ethToSell;
            uint256 newVUSDC = vK / newVETH;
            
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        } else {
            // 平空仓：买回虚拟 ETH
            uint256 ethToBuy = uint256(-pos.position);
            uint256 newVETH = vETHAmount - ethToBuy;
            uint256 newVUSDC = vK / newVETH;
            
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        }

        // 结算资金 - 简化为只返还保证金
        USDC.transfer(msg.sender, pos.margin);

        emit PositionClosed(msg.sender, pnl);
        delete positions[msg.sender];
    }

    // 清算头寸， 清算的逻辑和关闭头寸类似，不过利润由清算用户获取
    // 注意： 清算人不能是自己，同时设置一个清算条件，例如亏损大于保证金的 80%
    function liquidatePosition(address _user) external {
        require(msg.sender != _user, "Cannot liquidate own position");
        
        PositionInfo memory position = positions[_user];
        require(position.position != 0, "No open position");
        
        int256 pnl = calculatePnL(_user);
        
        // 清算条件：亏损大于保证金的 80%
        require(pnl < -int256(position.margin * 80 / 100), "Position not liquidatable");

        // 恢复虚拟池状态
        if (position.isLong) {
            // 平多仓：卖回虚拟 ETH
            uint256 ethToSell = uint256(position.position);
            uint256 newVETH = vETHAmount + ethToSell;
            uint256 newVUSDC = vK / newVETH;
            
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        } else {
            // 平空仓：买回虚拟 ETH
            uint256 ethToBuy = uint256(-position.position);
            uint256 newVETH = vETHAmount - ethToBuy;
            uint256 newVUSDC = vK / newVETH;
            
            vETHAmount = newVETH;
            vUSDCAmount = newVUSDC;
        }

        // 清算奖励给清算人（保证金的 5%）
        uint256 liquidationReward = position.margin * 5 / 100;
        USDC.transfer(msg.sender, liquidationReward);

        emit PositionLiquidated(_user, msg.sender, pnl);
        delete positions[_user];
    }

    // 计算盈亏： 对比当前的仓位和借的 vUSDC
    function calculatePnL(address user) public view returns (int256) {
        PositionInfo memory pos = positions[user];
        if (pos.position == 0) return 0;

        uint256 currentPrice = getCurrentPrice();
        uint256 entryPrice = pos.entryPrice;

        if (pos.isLong) {
            // 做多盈亏 = 持仓数量 * (当前价格 - 开仓价格)
            int256 priceDiff = int256(currentPrice) - int256(entryPrice);
            // 结果需要转换为 USDC 精度 (6位小数)
            return (int256(uint256(pos.position)) * priceDiff) / int256(1e18) / int256(1e12);
        } else {
            // 做空盈亏 = 持仓数量 * (开仓价格 - 当前价格)
            int256 priceDiff = int256(entryPrice) - int256(currentPrice);
            // 结果需要转换为 USDC 精度 (6位小数)
            return (pos.position * priceDiff) / int256(1e18) / int256(1e12);
        }
    }

    // 检查头寸是否可被清算
    function isLiquidatable(address user) public view returns (bool) {
        PositionInfo memory pos = positions[user];
        if (pos.position == 0) return false;
        
        int256 pnl = calculatePnL(user);
        return pnl < -int256(pos.margin * 80 / 100);
    }
}