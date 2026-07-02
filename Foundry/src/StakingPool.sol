// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./StakingInterfaces.sol";

contract StakingPool is IStaking {
    
    IToken public kkToken;
    ILendingPool public lendingPool;
    IWETH public weth;
    address public owner;
    
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18;
    uint256 public totalStaked;
    uint256 public lastRewardBlock;
    uint256 public accRewardPerShare;
    
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 stakingTime;
    }
    
    mapping(address => UserInfo) public userInfo;
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 reward);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor(address _kkToken, address _weth, address _lendingPool) {
        kkToken = IToken(_kkToken);
        weth = IWETH(_weth);
        lendingPool = ILendingPool(_lendingPool);
        owner = msg.sender;
        lastRewardBlock = block.number;
    }
    
    function updateReward() public {
        if (block.number <= lastRewardBlock || totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        
        uint256 diff = block.number - lastRewardBlock;
        uint256 reward = diff * REWARD_PER_BLOCK;
        accRewardPerShare += (reward * 1e12) / totalStaked;
        lastRewardBlock = block.number;
    }
    
    function stake() external payable override {
        require(msg.value > 0, "Cannot stake 0");
        updateReward();
        
        UserInfo storage user = userInfo[msg.sender];
        
        // 发放待领取的奖励
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
            if (pending > 0) {
                kkToken.mint(msg.sender, pending);
            }
        } else {
            user.stakingTime = block.timestamp;
        }
        
        user.amount += msg.value;
        totalStaked += msg.value;
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
        
        // 存入借贷市场
        if (address(lendingPool) != address(0)) {
            weth.deposit{value: msg.value}();
            weth.approve(address(lendingPool), msg.value);
            lendingPool.deposit(address(weth), msg.value, address(this), 0);
        }
        
        emit Staked(msg.sender, msg.value);
    }
    
    function unstake(uint256 amount) external override {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= amount && amount > 0, "Invalid amount");
        
        updateReward();
        
        uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
        
        user.amount -= amount;
        totalStaked -= amount;
        
        if (user.amount == 0) {
            user.stakingTime = 0;
        }
        
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
        
        // 发放奖励
        if (pending > 0) {
            kkToken.mint(msg.sender, pending);
        }
        
        // 从借贷市场提取
        if (address(lendingPool) != address(0)) {
            lendingPool.withdraw(address(weth), amount, address(this));
            weth.withdraw(amount);
        }
        
        payable(msg.sender).transfer(amount);
        emit Unstaked(msg.sender, amount);
    }
    
    function claim() external override {
        updateReward();
        
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
        
        require(pending > 0, "No rewards");
        
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;
        kkToken.mint(msg.sender, pending);
        
        emit Claimed(msg.sender, pending);
    }
    
    function balanceOf(address account) external view override returns (uint256) {
        return userInfo[account].amount;
    }
    
    function earned(address account) external view override returns (uint256) {
        UserInfo memory user = userInfo[account];
        if (user.amount == 0) return 0;
        
        uint256 currentAcc = accRewardPerShare;
        if (block.number > lastRewardBlock && totalStaked > 0) {
            uint256 diff = block.number - lastRewardBlock;
            uint256 reward = diff * REWARD_PER_BLOCK;
            currentAcc += (reward * 1e12) / totalStaked;
        }
        
        return (user.amount * currentAcc) / 1e12 - user.rewardDebt;
    }
    
    function getStakingTime(address account) external view returns (uint256) {
        return userInfo[account].stakingTime;
    }
    
    function updateLendingPool(address _lendingPool) external onlyOwner {
        lendingPool = ILendingPool(_lendingPool);
    }
    
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner).transfer(balance);
        }
    }
    
    receive() external payable {}
}