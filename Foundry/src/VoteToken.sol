// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VoteToken
 * @dev 用于治理投票的 ERC20 代币
 */
contract VoteToken is ERC20, Ownable {
    // 检查点结构，用于存储历史投票权重
    struct Checkpoint {
        uint256 fromBlock;
        uint256 votes;
    }

    // 用户的投票权重检查点
    mapping(address => Checkpoint[]) private _checkpoints;
    
    // 总投票权重检查点
    Checkpoint[] private _totalSupplyCheckpoints;

    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address initialOwner
    ) ERC20(name, symbol) Ownable(initialOwner) {
        _mint(initialOwner, initialSupply);
    }

    /**
     * @dev 铸造代币
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev 获取账户在指定区块的投票权重
     */
    function getPastVotes(address account, uint256 blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "VoteToken: block not yet mined");
        return _checkpointsLookup(_checkpoints[account], blockNumber);
    }

    /**
     * @dev 获取当前投票权重
     */
    function getVotes(address account) public view returns (uint256) {
        uint256 pos = _checkpoints[account].length;
        return pos == 0 ? 0 : _checkpoints[account][pos - 1].votes;
    }

    /**
     * @dev 获取指定区块的总投票权重
     */
    function getPastTotalSupply(uint256 blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "VoteToken: block not yet mined");
        return _checkpointsLookup(_totalSupplyCheckpoints, blockNumber);
    }

    /**
     * @dev 重写转账函数以更新投票权重
     */
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);

        if (from == address(0)) {
            // 铸造
            _updateTotalSupply(totalSupply() - value, totalSupply());
        }
        if (to == address(0)) {
            // 销毁
            _updateTotalSupply(totalSupply() + value, totalSupply());
        }

        _moveVotingPower(from, to, value);
    }

    /**
     * @dev 更新投票权重
     */
    function _moveVotingPower(address from, address to, uint256 amount) internal {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                uint256 oldWeight = getVotes(from);
                uint256 newWeight = oldWeight - amount;
                _writeCheckpoint(_checkpoints[from], oldWeight, newWeight);
                emit DelegateVotesChanged(from, oldWeight, newWeight);
            }

            if (to != address(0)) {
                uint256 oldWeight = getVotes(to);
                uint256 newWeight = oldWeight + amount;
                _writeCheckpoint(_checkpoints[to], oldWeight, newWeight);
                emit DelegateVotesChanged(to, oldWeight, newWeight);
            }
        }
    }

    /**
     * @dev 更新总供应量检查点
     */
    function _updateTotalSupply(uint256 oldSupply, uint256 newSupply) internal {
        _writeCheckpoint(_totalSupplyCheckpoints, oldSupply, newSupply);
    }

    /**
     * @dev 写入检查点
     */
    function _writeCheckpoint(
        Checkpoint[] storage ckpts,
        uint256 oldWeight,
        uint256 newWeight
    ) internal {
        uint256 pos = ckpts.length;
        
        if (pos > 0 && ckpts[pos - 1].fromBlock == block.number) {
            ckpts[pos - 1].votes = newWeight;
        } else {
            ckpts.push(Checkpoint({fromBlock: block.number, votes: newWeight}));
        }
    }

    /**
     * @dev 在检查点数组中查找指定区块的投票权重
     */
    function _checkpointsLookup(Checkpoint[] storage ckpts, uint256 blockNumber) internal view returns (uint256) {
        uint256 length = ckpts.length;
        
        if (length == 0) {
            return 0;
        }

        // 检查最新的检查点
        if (ckpts[length - 1].fromBlock <= blockNumber) {
            return ckpts[length - 1].votes;
        }

        // 检查第一个检查点
        if (ckpts[0].fromBlock > blockNumber) {
            return 0;
        }

        // 二分查找
        uint256 lower = 0;
        uint256 upper = length - 1;
        
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2;
            Checkpoint memory cp = ckpts[center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        
        return ckpts[lower].votes;
    }
} 