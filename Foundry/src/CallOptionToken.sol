// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract CallOptionToken {
    // ERC20 基本属性
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    
    // 期权相关属性
    address public issuer;              // 期权发行方
    address public underlyingAsset;     // 标的资产地址 (ETH使用WETH)
    address public paymentToken;        // 支付代币 (USDT)
    uint256 public strikePrice;         // 行权价格 (以paymentToken计价)
    uint256 public expirationDate;      // 到期日期
    uint256 public underlyingAmount;    // 每个期权Token对应的标的资产数量
    bool public expired;                // 期权是否已过期
    
    uint256 public totalUnderlyingDeposited; // 总共存入的标的资产
    
    // ERC20 事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    // 期权事件
    event OptionIssued(address indexed issuer, uint256 underlyingAmount, uint256 optionTokens);
    event OptionExercised(address indexed exerciser, uint256 optionTokens, uint256 underlyingReceived, uint256 paymentPaid);
    event OptionExpired(address indexed issuer, uint256 remainingUnderlying);
    event TradingPairCreated(address indexed token0, address indexed token1, uint256 liquidity);
    
    modifier onlyIssuer() {
        require(msg.sender == issuer, "Only issuer can call this function");
        _;
    }
    
    modifier notExpired() {
        require(block.timestamp < expirationDate, "Option has expired");
        require(!expired, "Option has been marked as expired");
        _;
    }
    
    modifier isExpired() {
        require(block.timestamp >= expirationDate || expired, "Option has not expired yet");
        _;
    }
    
    constructor(
        string memory _name,
        string memory _symbol,
        address _underlyingAsset,
        address _paymentToken,
        uint256 _strikePrice,
        uint256 _expirationDate,
        uint256 _underlyingAmount
    ) {
        name = _name;
        symbol = _symbol;
        decimals = 18;
        totalSupply = 0; // 初始供应量为0，通过发行增加
        
        issuer = msg.sender;
        underlyingAsset = _underlyingAsset;
        paymentToken = _paymentToken;
        strikePrice = _strikePrice;
        expirationDate = _expirationDate;
        underlyingAmount = _underlyingAmount; // 例如：1个期权Token = 0.001 ETH
        expired = false;
    }
    
    // ERC20 函数实现
    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }
    
    function transfer(address to, uint256 amount) public returns (bool) {
        require(balances[msg.sender] >= amount, "ERC20: transfer amount exceeds balance");
        require(to != address(0), "ERC20: transfer to the zero address");
        
        balances[msg.sender] -= amount;
        balances[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balances[from] >= amount, "ERC20: transfer amount exceeds balance");
        require(allowances[from][msg.sender] >= amount, "ERC20: transfer amount exceeds allowance");
        require(to != address(0), "ERC20: transfer to the zero address");
        
        balances[from] -= amount;
        balances[to] += amount;
        allowances[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) public returns (bool) {
        require(spender != address(0), "ERC20: approve to the zero address");
        
        allowances[msg.sender][spender] = amount;
        
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view returns (uint256) {
        return allowances[owner][spender];
    }
    
    // 发行期权Token（项目方角色）
    function issueOptions(uint256 _underlyingAmountDeposit) external onlyIssuer notExpired payable {
        require(_underlyingAmountDeposit > 0, "Underlying amount must be greater than 0");
        
        // 如果是ETH，接收msg.value
        if (underlyingAsset == address(0)) {
            require(msg.value == _underlyingAmountDeposit, "ETH amount mismatch");
        } else {
            // 如果是ERC20代币，从发行方转入
            require(IERC20(underlyingAsset).transferFrom(msg.sender, address(this), _underlyingAmountDeposit), "Transfer failed");
        }
        
        // 计算应该发行的期权Token数量
        uint256 optionTokensToIssue = _underlyingAmountDeposit / underlyingAmount;
        require(optionTokensToIssue > 0, "Not enough underlying to issue options");
        
        // 增加总供应量和发行方余额
        totalSupply += optionTokensToIssue;
        balances[issuer] += optionTokensToIssue;
        totalUnderlyingDeposited += _underlyingAmountDeposit;
        
        emit Transfer(address(0), issuer, optionTokensToIssue);
        emit OptionIssued(issuer, _underlyingAmountDeposit, optionTokensToIssue);
    }
    
    // 模拟创建交易对（简化版本）
    function createTradingPair(uint256 _optionTokenAmount, uint256 _paymentTokenAmount) external onlyIssuer {
        require(balances[issuer] >= _optionTokenAmount, "Insufficient option tokens");
        require(IERC20(paymentToken).transferFrom(issuer, address(this), _paymentTokenAmount), "Payment token transfer failed");
        
        // 这里简化处理，实际应该创建真正的流动性池
        // 假设用户可以用较低的价格购买期权
        emit TradingPairCreated(address(this), paymentToken, _optionTokenAmount);
    }
    
    // 模拟用户购买期权（简化版本）
    function buyOptions(uint256 _optionTokenAmount, uint256 _maxPayment) external notExpired {
        require(_optionTokenAmount > 0, "Amount must be greater than 0");
        require(balances[issuer] >= _optionTokenAmount, "Insufficient option tokens available");
        
        // 计算需要支付的金额（这里简化为固定比例，实际应该基于市场价格）
        uint256 requiredPayment = (_optionTokenAmount * strikePrice * 10) / 100; // 假设期权价格是行权价格的10%
        require(_maxPayment >= requiredPayment, "Payment not sufficient");
        require(IERC20(paymentToken).transferFrom(msg.sender, address(this), requiredPayment), "Payment failed");
        
        // 转移期权Token给用户
        balances[issuer] -= _optionTokenAmount;
        balances[msg.sender] += _optionTokenAmount;
        
        emit Transfer(issuer, msg.sender, _optionTokenAmount);
    }
    
    // 行权方法（用户角色）
    function exerciseOptions(uint256 _optionTokenAmount) external notExpired {
        require(_optionTokenAmount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= _optionTokenAmount, "Insufficient option tokens");
        
        // 计算需要支付的行权价格
        uint256 totalPayment = _optionTokenAmount * strikePrice;
        require(IERC20(paymentToken).transferFrom(msg.sender, address(this), totalPayment), "Payment failed");
        
        // 计算用户应该收到的标的资产数量
        uint256 underlyingToReceive = _optionTokenAmount * underlyingAmount;
        require(totalUnderlyingDeposited >= underlyingToReceive, "Insufficient underlying assets");
        
        // 销毁期权Token
        balances[msg.sender] -= _optionTokenAmount;
        totalSupply -= _optionTokenAmount;
        totalUnderlyingDeposited -= underlyingToReceive;
        
        // 转移标的资产给用户
        if (underlyingAsset == address(0)) {
            // 如果是ETH
            payable(msg.sender).transfer(underlyingToReceive);
        } else {
            // 如果是ERC20代币
            require(IERC20(underlyingAsset).transfer(msg.sender, underlyingToReceive), "Underlying transfer failed");
        }
        
        emit Transfer(msg.sender, address(0), _optionTokenAmount);
        emit OptionExercised(msg.sender, _optionTokenAmount, underlyingToReceive, totalPayment);
    }
    
    // 过期销毁（项目方角色）
    function expireOptions() external onlyIssuer isExpired {
        require(!expired, "Options already expired");
        expired = true;
        
        // 发行方可以赎回剩余的标的资产
        uint256 remainingUnderlying = totalUnderlyingDeposited;
        
        if (remainingUnderlying > 0) {
            if (underlyingAsset == address(0)) {
                payable(issuer).transfer(remainingUnderlying);
            } else {
                IERC20(underlyingAsset).transfer(issuer, remainingUnderlying);
            }
            totalUnderlyingDeposited = 0;
        }
        
        // 转移合约中的支付代币余额给发行方
        if (paymentToken != address(0)) {
            uint256 paymentBalance = IERC20(paymentToken).balanceOf(address(this));
            if (paymentBalance > 0) {
                IERC20(paymentToken).transfer(issuer, paymentBalance);
            }
        }
        
        // 销毁所有剩余的期权Token
        totalSupply = 0;
        balances[issuer] = 0;
        
        emit OptionExpired(issuer, remainingUnderlying);
    }
    
    // 查询函数
    function getOptionInfo() external view returns (
        address _issuer,
        address _underlyingAsset,
        address _paymentToken,
        uint256 _strikePrice,
        uint256 _expirationDate,
        uint256 _underlyingAmount,
        bool _expired,
        uint256 _totalUnderlyingDeposited
    ) {
        return (
            issuer,
            underlyingAsset,
            paymentToken,
            strikePrice,
            expirationDate,
            underlyingAmount,
            expired,
            totalUnderlyingDeposited
        );
    }
    
    // 检查期权是否可以行权
    function canExercise() external view returns (bool) {
        return block.timestamp < expirationDate && !expired;
    }
    
    // 接收ETH
    receive() external payable {}
} 