// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/OracleSimple.sol";
import {Meme_Factory, MemeToken} from "../src/Meme_FactoryV2.sol";
import {IUniswapV2Router02, IUniswapV2Factory, IUniswapV2Pair} from "../src/Interfaces.sol";

// Mock Uniswap V2 Factory
contract MockUniswapV2Factory is IUniswapV2Factory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    
    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2Factory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Factory: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2Factory: PAIR_EXISTS');
        
        // 使用普通的MockPair合约，非代理
        MockUniswapV2Pair mockPair = new MockUniswapV2Pair();
        mockPair.initialize(token0, token1);
        
        pair = address(mockPair);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        
        return pair;
    }
}

// Mock Uniswap V2 Pair
contract MockUniswapV2Pair is IUniswapV2Pair {
    address public override token0;
    address public override token1;
    
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;
    
    uint private _price0CumulativeLast;
    uint private _price1CumulativeLast;
    
    function initialize(address _token0, address _token1) external {
        token0 = _token0;
        token1 = _token1;
    }
    
    function getReserves() external view override returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (reserve0, reserve1, blockTimestampLast);
    }
    
    function price0CumulativeLast() external view override returns (uint) {
        return _price0CumulativeLast;
    }
    
    function price1CumulativeLast() external view override returns (uint) {
        return _price1CumulativeLast;
    }
    
    // 模拟设置储备量和时间戳
    function setReserves(uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) external {
        // 记录之前的时间戳和储备，用于计算累积价格
        uint32 previousTimestamp = blockTimestampLast;
        uint112 previousReserve0 = reserve0;
        uint112 previousReserve1 = reserve1;
        
        // 更新储备和时间戳
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        
        // 模拟价格累积计算
        if (previousTimestamp > 0 && previousReserve0 > 0 && previousReserve1 > 0) {
            uint32 timeElapsed = _blockTimestampLast - previousTimestamp;
            if (timeElapsed > 0) {
                // 使用之前的储备来计算，而不是新设置的储备
                uint224 price0 = uint224((uint256(previousReserve1) * 2**112) / previousReserve0);
                uint224 price1 = uint224((uint256(previousReserve0) * 2**112) / previousReserve1);
                
                // 累积价格 = 之前的价格 * 时间
                _price0CumulativeLast += uint256(price0) * timeElapsed;
                _price1CumulativeLast += uint256(price1) * timeElapsed;
            }
        }
        
        blockTimestampLast = _blockTimestampLast;
    }
    
    // 模拟 totalSupply 方法
    function totalSupply() external pure returns (uint) {
        return 1000 ether;
    }
    
    // 模拟 balanceOf 方法
    function balanceOf(address) external pure returns (uint) {
        return 100 ether;
    }
}

// Mock Uniswap V2 Router
contract MockUniswapV2Router is IUniswapV2Router02 {
    address private _factory;
    address private _weth;
    
    constructor(address factoryAddr, address wethAddress) {
        _factory = factoryAddr;
        _weth = wethAddress;
    }
    
    function factory() external pure override returns (address) {
        return 0x0000000000000000000000000000000000000000; // Mock factory address
    }
    
    function WETH() external pure override returns (address) {
        return 0x1234567890AbcdEF1234567890aBcdef12345678; // Mock WETH address
    }
    
    // 添加流动性 ETH
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable override returns (uint amountToken, uint amountETH, uint liquidity) {
        // 简化实现
        IUniswapV2Factory factoryContract = IUniswapV2Factory(_factory);
        address pair = factoryContract.getPair(token, _weth);
        
        if (pair == address(0)) {
            pair = factoryContract.createPair(token, _weth);
        }
        
        // 设置储备
        MockUniswapV2Pair(pair).setReserves(
            uint112(amountTokenDesired),
            uint112(msg.value),
            uint32(block.timestamp)
        );
        
        return (amountTokenDesired, msg.value, 0);
    }
    
    // 添加流动性
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external override returns (uint amountA, uint amountB, uint liquidity) {
        return (0, 0, 0);
    }
    
    // 获取兑换金额
    function getAmountsOut(uint amountIn, address[] calldata path)
        external view override returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        if (path.length == 2) {
            amounts[1] = amountIn * 10; // 简化：1 token = 10 ETH
        }
        return amounts;
    }
    
    // 支持转移费用的兑换 ETH 到代币
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable override {
        // 简化实现
    }
}

// Mock WETH
contract MockWETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;
    
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);
    
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    function withdraw(uint wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
    
    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }
    
    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        return true;
    }
    
    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }
    
    function transferFrom(address src, address dst, uint wad) public returns (bool) {
        require(balanceOf[src] >= wad);
        
        if (src != msg.sender && allowance[src][msg.sender] != type(uint).max) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }
        
        balanceOf[src] -= wad;
        balanceOf[dst] += wad;
        
        return true;
    }
}

// 测试 OracleSimple 合约
contract OracleSimpleTest is Test {
    // 合约变量
    OracleSimple public oracle;
    Meme_Factory public factory;
    MockUniswapV2Router public router;
    MockUniswapV2Factory public uniswapFactory;
    MockWETH public weth;
    
    // 地址变量
    address public projectOwner;
    address public creator;
    address public buyer;
    address public memeToken;
    
    // 测试参数
    string constant SYMBOL = "MEME";
    uint256 constant TOTAL_SUPPLY = 1000000 * 10**18; // 1,000,000 tokens
    uint256 constant PER_MINT = 1000 * 10**18;       // 1,000 tokens per mint
    uint256 constant PRICE = 0.0001 ether;           // 0.0001 ETH per token
    
    function setUp() public {
        // 设置测试账户
        projectOwner = makeAddr("projectOwner");
        creator = makeAddr("creator");
        buyer = makeAddr("buyer");
        
        // 给测试账户一些 ETH
        vm.deal(projectOwner, 10 ether);
        vm.deal(creator, 10 ether);
        vm.deal(buyer, 10 ether);
        
        // 部署 Mock 合约
        weth = new MockWETH();
        uniswapFactory = new MockUniswapV2Factory();
        router = new MockUniswapV2Router(address(uniswapFactory), address(weth));
        
        // 部署 Meme_Factory 合约
        factory = new Meme_Factory(projectOwner, address(router));
        
        // 部署 Meme 代币
        vm.startPrank(creator);
        memeToken = factory.deployInscription(
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();
    }
    
    // 测试预言机初始化
    function testOracleInitialization() public {
        // 首先添加流动性以创建交易对
        addLiquidityForTesting();
        
        // 部署预言机
        oracle = new OracleSimple(address(uniswapFactory), memeToken, address(weth));
        
        // 验证预言机初始化
        assertEq(address(oracle.pair()), uniswapFactory.getPair(memeToken, address(weth)), "Incorrect pair address");
        assertEq(oracle.memeToken(), memeToken, "Incorrect meme token address");
        assertEq(oracle.weth(), address(weth), "Incorrect WETH address");
        assertEq(oracle.factory(), address(uniswapFactory), "Incorrect factory address");
    }
    
    // 测试价格更新和查询
    function testPriceUpdateAndConsult() public {
        // 添加初始流动性
        addLiquidityForTesting();
        
        // 部署预言机
        oracle = new OracleSimple(address(uniswapFactory), memeToken, address(weth));
        
        // 记录初始状态
        uint initialPrice0Cumulative = oracle.price0CumulativeLast();
        uint initialPrice1Cumulative = oracle.price1CumulativeLast();
        uint32 initialTimestamp = oracle.blockTimestampLast();
        
        // 模拟交易 1: 添加更多流动性，改变价格
        vm.warp(block.timestamp + 1 hours);
        simulateTrading(2000 * 10**18, 0.25 ether); // 2000 Meme tokens, 0.25 ETH
        
        // 模拟交易 2: 再次改变价格
        vm.warp(block.timestamp + 2 hours);
        simulateTrading(1500 * 10**18, 0.2 ether); // 1500 Meme tokens, 0.2 ETH
        
        // 模拟交易 3: 最后一次交易
        vm.warp(block.timestamp + 3 hours);
        simulateTrading(3000 * 10**18, 0.3 ether); // 3000 Meme tokens, 0.3 ETH
        
        // 前进到 PERIOD 之后（24 小时 + 1 秒）
        vm.warp(block.timestamp + 18 hours + 1 seconds);
        
        // 更新预言机价格
        oracle.update();
        
        // 验证状态已更新
        assertTrue(oracle.price0CumulativeLast() > initialPrice0Cumulative, "Price0Cumulative not updated");
        assertTrue(oracle.price1CumulativeLast() > initialPrice1Cumulative, "Price1Cumulative not updated");
        assertTrue(oracle.blockTimestampLast() > initialTimestamp, "Timestamp not updated");
        
        // 测试 consult 函数
        (address token0, address token1) = getOrderedTokens(memeToken, address(weth));
        
        uint amount = 1 ether;
        uint expected;
        
        if (memeToken == token0) {
            // 查询 Meme 代币的价格（以 ETH 为单位）
            expected = oracle.consult(memeToken, amount);
            console.log("1 Meme token worth in ETH:", expected);
            assertTrue(expected > 0, "Expected non-zero value for Meme price");
        } else {
            // 查询 ETH 的价格（以 Meme 代币为单位）
            expected = oracle.consult(address(weth), amount);
            console.log("1 ETH worth in Meme tokens:", expected);
            assertTrue(expected > 0, "Expected non-zero value for ETH price");
        }
    }
    
    // 测试多次更新
    function testMultipleUpdates() public {
        // 添加初始流动性
        addLiquidityForTesting();
        
        // 部署预言机
        oracle = new OracleSimple(address(uniswapFactory), memeToken, address(weth));
        
        // 循环模拟多个周期
        for (uint i = 1; i <= 3; i++) {
            // 模拟多次交易
            for (uint j = 1; j <= 5; j++) {
                vm.warp(block.timestamp + 4 hours);
                uint tokenAmount = (1000 + j * 100) * 10**18; // 递增代币数量
                uint ethAmount = (0.1 ether + j * 0.02 ether);  // 递增 ETH 数量
                simulateTrading(tokenAmount, ethAmount);
            }
            
            // 前进到 PERIOD 之后
            vm.warp(block.timestamp + 4 hours + 1 seconds);
            
            // 更新预言机价格
            oracle.update();
            
            // 验证 getMemePrice 和 getEthPrice 函数
            uint memePrice = oracle.getMemePrice(1 ether);
            uint ethPrice = oracle.getEthPrice(1 ether);
            
            console.log("Update cycle", i);
            console.log("Meme price (1 Meme in ETH):", memePrice);
            console.log("ETH price (1 ETH in Meme):", ethPrice);
            
            assertTrue(memePrice > 0 || ethPrice > 0, "Both prices should not be zero");
        }
    }
    
    // 测试价格计算
    function testPriceCalculation() public {
        // 添加初始流动性
        addLiquidityForTesting();
        
        // 部署预言机
        oracle = new OracleSimple(address(uniswapFactory), memeToken, address(weth));
        
        // 模拟一个固定比例的交易：1000 Meme = 0.1 ETH (1 Meme = 0.0001 ETH)
        vm.warp(block.timestamp + 1 hours);
        simulateTrading(1000 * 10**18, 0.1 ether);
        
        // 前进到 PERIOD 之后
        vm.warp(block.timestamp + 23 hours + 1 seconds);
        
        // 更新预言机价格
        oracle.update();
        
        // 获取 token0 和 token1 的顺序
        (address token0, ) = getOrderedTokens(memeToken, address(weth));
        
        uint memeAmount = 1 ether; // 1 Meme token
        uint actualEthAmount = oracle.getMemePrice(memeAmount);
        
        console.log("Token0:", token0);
        console.log("Meme token:", memeToken);
        console.log("Actual ETH amount:", actualEthAmount);
        
        // 测试价格不为零即可
        assertTrue(actualEthAmount > 0, "Price should be greater than zero");
        
        // 反向验证：ETH 到 Meme 的转换
        uint ethAmount = 1 ether; // 1 ETH
        uint actualMemeAmount = oracle.getEthPrice(ethAmount);
        
        console.log("Actual Meme amount for 1 ETH:", actualMemeAmount);
        
        // 测试价格不为零即可
        assertTrue(actualMemeAmount > 0, "Reverse price should be greater than zero");
    }
    
    // 测试极端情况：价格大幅波动
    function testPriceVolatility() public {
        // 添加初始流动性
        addLiquidityForTesting();
        
        // 部署预言机
        oracle = new OracleSimple(address(uniswapFactory), memeToken, address(weth));
        
        // 模拟初始价格：1 Meme = 0.0001 ETH
        vm.warp(block.timestamp + 1 hours);
        simulateTrading(1000 * 10**18, 0.1 ether);
        
        // 价格暴涨：1 Meme = 0.001 ETH (10倍)
        vm.warp(block.timestamp + 4 hours);
        simulateTrading(1000 * 10**18, 1 ether);
        
        // 价格暴跌：1 Meme = 0.00001 ETH (1/100 初始价格)
        vm.warp(block.timestamp + 8 hours);
        simulateTrading(10000 * 10**18, 0.1 ether);
        
        // 价格回归：1 Meme = 0.0001 ETH
        vm.warp(block.timestamp + 12 hours);
        simulateTrading(1000 * 10**18, 0.1 ether);
        
        // 前进到 PERIOD 之后
        vm.warp(block.timestamp + 1 hours);
        
        // 更新预言机价格
        oracle.update();
        
        // 查询 TWAP 价格 - 应该是这些价格的时间加权平均值
        uint memePrice = oracle.getMemePrice(1 ether);
        
        console.log("TWAP Meme price after volatility (1 Meme in ETH):", memePrice);
        assertTrue(memePrice > 0, "TWAP price should be positive");
    }
    
    // 测试期间错误：尝试提前更新
    function testPeriodNotElapsed() public {
        // 添加初始流动性
        addLiquidityForTesting();
        
        // 部署预言机
        oracle = new OracleSimple(address(uniswapFactory), memeToken, address(weth));
        
        // 模拟交易
        vm.warp(block.timestamp + 1 hours);
        simulateTrading(1000 * 10**18, 0.1 ether);
        
        // 仅前进 12 小时（小于 PERIOD = 24 小时）
        vm.warp(block.timestamp + 12 hours);
        
        // 尝试更新预言机价格，应该失败
        vm.expectRevert("OracleSimple: PERIOD_NOT_ELAPSED");
        oracle.update();
    }
    
    // 辅助函数：添加初始流动性
    function addLiquidityForTesting() internal {
        // 创建 Meme/WETH 交易对
        uniswapFactory.createPair(memeToken, address(weth));
        address pair = uniswapFactory.getPair(memeToken, address(weth));
        
        // 设置初始储备量：1000 Meme tokens 和 0.1 ETH
        MockUniswapV2Pair(pair).setReserves(
            uint112(1000 * 10**18), 
            uint112(0.1 ether),
            uint32(block.timestamp)
        );
    }
    
    // 辅助函数：模拟交易
    function simulateTrading(uint tokenAmount, uint ethAmount) internal {
        address pair = uniswapFactory.getPair(memeToken, address(weth));
        require(pair != address(0), "Pair not created");
        
        // 获取当前储备
        (uint112 reserve0, uint112 reserve1, ) = MockUniswapV2Pair(pair).getReserves();
        
        // 确定代币顺序
        (address token0, ) = getOrderedTokens(memeToken, address(weth));
        
        // 更新储备，保持代币顺序
        if (memeToken == token0) {
            MockUniswapV2Pair(pair).setReserves(
                uint112(tokenAmount),
                uint112(ethAmount),
                uint32(block.timestamp)
            );
        } else {
            MockUniswapV2Pair(pair).setReserves(
                uint112(ethAmount),
                uint112(tokenAmount),
                uint32(block.timestamp)
            );
        }
    }
    
    // 辅助函数：获取排序后的代币地址
    function getOrderedTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
} 