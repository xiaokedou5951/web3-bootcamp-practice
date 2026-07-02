// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
}

contract FlashSwap {
    address private constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    
    address public owner;
    
    event FlashSwapExecuted(
        address indexed poolA,
        address indexed poolB,
        address tokenA,
        address tokenB,
        uint256 amountBorrowed,
        uint256 profit
    );
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    // 执行闪电兑换套利
    function executeFlashSwap(
        address poolA,      // 价格较低的池子
        address poolB,      // 价格较高的池子
        address tokenA,     // 要借贷的代币
        address tokenB,     // 要交换的代币
        uint256 amountToBorrow  // 借贷数量
    ) external onlyOwner {
        // 验证池子地址
        require(poolA != address(0) && poolB != address(0), "Invalid pool addresses");
        
        // 从 poolA 开始闪电贷
        IUniswapV2Pair pair = IUniswapV2Pair(poolA);
        address token0 = pair.token0();
        address token1 = pair.token1();
        
        uint256 amount0Out = tokenA == token0 ? amountToBorrow : 0;
        uint256 amount1Out = tokenA == token1 ? amountToBorrow : 0;
        
        // 编码数据传递给回调函数
        bytes memory data = abi.encode(poolB, tokenA, tokenB, amountToBorrow);
        
        // 执行闪电贷
        pair.swap(amount0Out, amount1Out, address(this), data);
    }
    
    // Uniswap V2 回调函数
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        // 验证调用者是合法的 Uniswap V2 配对合约
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(token0, token1);
        require(msg.sender == pair, "Invalid pair");
        require(sender == address(this), "Invalid sender");
        
        // 解码数据
        (address poolB, address tokenA, address tokenB, uint256 amountBorrowed) = 
            abi.decode(data, (address, address, address, uint256));
        
        // 获取借到的代币数量
        uint256 amountReceived = amount0 > 0 ? amount0 : amount1;
        
        // 在 poolB 中将 tokenA 兑换为 tokenB
        uint256 amountOut = _swapOnPoolB(poolB, tokenA, tokenB, amountReceived);
        
        // 计算需要还款的数量（包含手续费）
        uint256 amountToRepay = _calculateRepayAmount(amountBorrowed, tokenA, msg.sender);
        
        // 将部分 tokenB 兑换回 tokenA 以偿还借款
        uint256 amountToSwapBack = _calculateAmountToSwapBack(poolB, tokenB, tokenA, amountToRepay);
        uint256 amountRepaid = _swapBackOnPoolB(poolB, tokenB, tokenA, amountToSwapBack);
        
        // 确保有足够的代币还款
        require(amountRepaid >= amountToRepay, "Insufficient amount to repay");
        
        // 还款给配对合约
        IERC20(tokenA).transfer(msg.sender, amountToRepay);
        
        // 计算利润
        uint256 remainingTokenB = IERC20(tokenB).balanceOf(address(this));
        uint256 remainingTokenA = IERC20(tokenA).balanceOf(address(this));
        
        // 将剩余代币转给 owner
        if (remainingTokenB > 0) {
            IERC20(tokenB).transfer(owner, remainingTokenB);
        }
        if (remainingTokenA > 0) {
            IERC20(tokenA).transfer(owner, remainingTokenA);
        }
        
        emit FlashSwapExecuted(msg.sender, poolB, tokenA, tokenB, amountBorrowed, remainingTokenB);
    }
    
    // 在 poolB 中执行交换
    function _swapOnPoolB(
        address poolB,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        IUniswapV2Pair pair = IUniswapV2Pair(poolB);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        
        address token0 = pair.token0();
        bool token0IsTokenIn = tokenIn == token0;
        
        (uint112 reserveIn, uint112 reserveOut) = token0IsTokenIn ? 
            (reserve0, reserve1) : (reserve1, reserve0);
        
        // 计算输出数量
        amountOut = IUniswapV2Router02(UNISWAP_V2_ROUTER).getAmountOut(
            amountIn, reserveIn, reserveOut
        );
        
        // 转移代币到配对合约
        IERC20(tokenIn).transfer(poolB, amountIn);
        
        // 执行交换
        (uint256 amount0Out, uint256 amount1Out) = token0IsTokenIn ? 
            (uint256(0), amountOut) : (amountOut, uint256(0));
        
        pair.swap(amount0Out, amount1Out, address(this), new bytes(0));
    }
    
    // 计算需要交换回去的数量
    function _calculateAmountToSwapBack(
        address poolB,
        address tokenIn,
        address tokenOut,
        uint256 amountOutNeeded
    ) internal view returns (uint256 amountIn) {
        IUniswapV2Pair pair = IUniswapV2Pair(poolB);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        
        address token0 = pair.token0();
        bool token0IsTokenIn = tokenIn == token0;
        
        (uint112 reserveIn, uint112 reserveOut) = token0IsTokenIn ? 
            (reserve0, reserve1) : (reserve1, reserve0);
        
        amountIn = IUniswapV2Router02(UNISWAP_V2_ROUTER).getAmountIn(
            amountOutNeeded, reserveIn, reserveOut
        );
    }
    
    // 执行反向交换
    function _swapBackOnPoolB(
        address poolB,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        return _swapOnPoolB(poolB, tokenIn, tokenOut, amountIn);
    }
    
    // 计算还款数量（包含 0.3% 手续费）
    function _calculateRepayAmount(
        uint256 amountBorrowed,
        address token,
        address pair
    ) internal pure returns (uint256) {
        // Uniswap V2 手续费是 0.3%
        return amountBorrowed * 1000 / 997 + 1;
    }
    
    // 紧急提取函数
    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(owner, balance);
        }
    }
} 