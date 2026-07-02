// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MemeToken
 * @dev 实现基本的 ERC20 代币，用于创建 Meme 代币
 */
contract MemeToken is ERC20 {
    address public memeCreator;
    address public factory;  // 添加工厂合约地址变量
    uint256 public totalSupply_;
    uint256 public perMint;
    uint256 public price;
    uint256 public mintedAmount;

    constructor() ERC20("MemeToken", "") {}

    /**
     * @dev 初始化 Meme 代币
     * @param _symbol 代币符号
     * @param _totalSupply 总供应量
     * @param _perMint 每次铸造的数量
     * @param _price 每个代币的价格（wei）
     * @param _creator 创建者地址
     */
    function initialize(
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _creator
    ) external {
        require(memeCreator == address(0), "Already initialized");
        require(_totalSupply > 0, "Total supply must be greater than 0");
        require(_perMint > 0, "Per mint must be greater than 0");
        require(_perMint <= _totalSupply, "Per mint must be less than or equal to total supply");
        
        _setSymbol(_symbol);
        totalSupply_ = _totalSupply;
        perMint = _perMint;
        price = _price;
        memeCreator = _creator;
        factory = msg.sender;  // 设置工厂合约地址为调用初始化函数的地址
        mintedAmount = 0;
    }

    /**
     * @dev 设置代币符号
     * @param _symbol 新的代币符号
     */
    function _setSymbol(string memory _symbol) internal pure {
        // 由于 ERC20 的 symbol 是不可变的，这里我们使用一个内部函数来设置
        // 在实际部署中，可能需要使用更复杂的方法来处理这个问题
        // 这里简化处理，实际上这个函数在当前 OpenZeppelin 实现中不存在
        // 您可能需要修改 ERC20 合约或使用其他方法来实现这个功能
        _symbol = _symbol;
    }

    /**
     * @dev 铸造新的代币
     * @param to 接收者地址
     * @return 是否成功
     */
    function mint(address to) external returns (bool) {
        require(msg.sender == factory, "Only factory can mint");  // 使用存储的工厂地址
        require(mintedAmount + perMint <= totalSupply_, "Exceeds total supply");
        
        mintedAmount += perMint;
        _mint(to, perMint);
        return true;
    }
}

/**
 * @title Meme_Factory
 * @dev 使用最小代理模式创建 Meme 代币的工厂合约
 */
contract Meme_Factory is Ownable {
    using Clones for address;

    // 项目方地址
    address public projectOwner;
    // 项目方费用比例（1%）
    uint256 public constant PROJECT_FEE_PERCENT = 1;
    // 基础代币实现
    address public implementation;
    // 已部署的代币地址映射
    mapping(address => bool) public deployedTokens;

    event MemeDeployed(address indexed tokenAddress, address indexed creator, string symbol, uint256 totalSupply, uint256 perMint, uint256 price);
    event MemeMinted(address indexed tokenAddress, address indexed buyer, uint256 amount, uint256 paid);

    /**
     * @dev 构造函数
     * @param _projectOwner 项目方地址
     */
    constructor(address _projectOwner) Ownable(msg.sender) {
        require(_projectOwner != address(0), "Invalid project owner");
        projectOwner = _projectOwner;
        
        // 部署基础代币实现
        implementation = address(new MemeToken());
    }

    /**
     * @dev 部署新的 Meme 代币
     * @param symbol 代币符号
     * @param totalSupply 总供应量
     * @param perMint 每次铸造的数量
     * @param price 每个代币的价格（wei）
     * @return tokenAddr 新部署的代币地址
     */
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address tokenAddr) {
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint must be greater than 0");
        require(perMint <= totalSupply, "Per mint must be less than or equal to total supply");

        // 使用 Clones 库创建最小代理
        tokenAddr = implementation.clone();
        
        // 初始化代币
        MemeToken(tokenAddr).initialize(symbol, totalSupply, perMint, price, msg.sender);
        
        // 记录已部署的代币
        deployedTokens[tokenAddr] = true;
        
        emit MemeDeployed(tokenAddr, msg.sender, symbol, totalSupply, perMint, price);
        
        return tokenAddr;
    }

    /**
     * @dev 铸造 Meme 代币
     * @param tokenAddr 代币地址
     */
    function mintInscription(address tokenAddr) external payable {
        require(deployedTokens[tokenAddr], "Token not deployed by this factory");
        
        MemeToken token = MemeToken(tokenAddr);
        
        // 检查是否超过总供应量
        require(token.mintedAmount() + token.perMint() <= token.totalSupply_(), "Exceeds total supply");
        
        // 检查支付金额 - 修改计算方式，与测试保持一致
        uint256 requiredAmount = token.price() * token.perMint() / 1e18;
        require(msg.value >= requiredAmount, "Insufficient payment");
        
        // 计算费用分配
        uint256 projectFee = (requiredAmount * PROJECT_FEE_PERCENT) / 100;
        uint256 creatorFee = requiredAmount - projectFee;
        
        // 分配费用
        (bool projectSuccess, ) = payable(projectOwner).call{value: projectFee}("");
        require(projectSuccess, "Project fee transfer failed");
        
        (bool creatorSuccess, ) = payable(token.memeCreator()).call{value: creatorFee}("");
        require(creatorSuccess, "Creator fee transfer failed");
        
        // 铸造代币
        token.mint(msg.sender);
        
        // 退还多余的 ETH
        if (msg.value > requiredAmount) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: msg.value - requiredAmount}("");
            require(refundSuccess, "Refund failed");
        }
        
        emit MemeMinted(tokenAddr, msg.sender, token.perMint(), requiredAmount);
    }

    /**
     * @dev 更新项目方地址
     * @param _newProjectOwner 新的项目方地址
     */
    function updateProjectOwner(address _newProjectOwner) external onlyOwner {
        require(_newProjectOwner != address(0), "Invalid project owner");
        projectOwner = _newProjectOwner;
    }
}