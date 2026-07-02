// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./VoteToken.sol";
import "./Bank.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Gov
 * @dev 治理合约，通过投票管理 Bank 合约
 */
contract Gov is ReentrancyGuard {
    VoteToken public voteToken;
    Bank public bank;

    // 提案状态
    enum ProposalState {
        Pending,    // 待投票
        Active,     // 投票中
        Defeated,   // 被否决
        Succeeded,  // 通过
        Executed    // 已执行
    }

    // 提案结构
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        address payable target;      // 提取目标地址
        uint256 amount;             // 提取金额
        string reason;              // 提取原因
        uint256 startBlock;         // 投票开始区块
        uint256 endBlock;           // 投票结束区块
        uint256 forVotes;           // 赞成票
        uint256 againstVotes;       // 反对票
        ProposalState state;        // 提案状态
        mapping(address => bool) hasVoted;  // 是否已投票
        mapping(address => bool) votes;     // 投票选择 (true: 赞成, false: 反对)
    }

    // 状态变量
    uint256 public proposalCount;
    uint256 public votingDelay = 1;        // 投票延迟（区块数）
    uint256 public votingPeriod = 100;     // 投票期间（区块数）
    uint256 public proposalThreshold = 1000 * 10**18;  // 提案门槛
    uint256 public quorum = 4000 * 10**18;  // 法定人数

    mapping(uint256 => Proposal) public proposals;
    
    // 事件
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        address target,
        uint256 amount,
        string reason,
        uint256 startBlock,
        uint256 endBlock
    );
    
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        bool support,
        uint256 weight
    );
    
    event ProposalExecuted(uint256 indexed proposalId, bool success);

    constructor(address _voteToken, address _bank) {
        voteToken = VoteToken(_voteToken);
        bank = Bank(payable(_bank));
    }

    /**
     * @dev 创建提案
     */
    function propose(
        string memory description,
        address payable target,
        uint256 amount,
        string memory reason
    ) external returns (uint256) {
        require(
            voteToken.getVotes(msg.sender) >= proposalThreshold,
            "Gov: proposer votes below proposal threshold"
        );
        require(target != address(0), "Gov: target cannot be zero address");
        require(amount > 0, "Gov: amount must be greater than 0");

        proposalCount++;
        uint256 proposalId = proposalCount;
        
        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.target = target;
        newProposal.amount = amount;
        newProposal.reason = reason;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        newProposal.state = ProposalState.Pending;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            description,
            target,
            amount,
            reason,
            startBlock,
            endBlock
        );

        return proposalId;
    }

    /**
     * @dev 投票
     */
    function castVote(uint256 proposalId, bool support) external {
        require(proposalId <= proposalCount && proposalId > 0, "Gov: invalid proposal id");
        
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.hasVoted[msg.sender], "Gov: voter already voted");
        require(block.number >= proposal.startBlock, "Gov: voting not yet started");
        require(block.number <= proposal.endBlock, "Gov: voting ended");

        uint256 weight = voteToken.getPastVotes(msg.sender, proposal.startBlock);
        require(weight > 0, "Gov: voter has no voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = support;

        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        // 更新提案状态
        if (proposal.state == ProposalState.Pending) {
            proposal.state = ProposalState.Active;
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    /**
     * @dev 执行提案
     */
    function execute(uint256 proposalId) external nonReentrant {
        require(proposalId <= proposalCount && proposalId > 0, "Gov: invalid proposal id");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Active || proposal.state == ProposalState.Succeeded, "Gov: proposal not executable");
        require(block.number > proposal.endBlock, "Gov: voting not ended");

        // 检查提案是否通过
        if (proposal.forVotes > proposal.againstVotes && proposal.forVotes >= quorum) {
            proposal.state = ProposalState.Succeeded;
        } else {
            proposal.state = ProposalState.Defeated;
            emit ProposalExecuted(proposalId, false);
            return;
        }

        // 执行提案
        proposal.state = ProposalState.Executed;
        
        try bank.withdraw(proposal.target, proposal.amount, proposal.reason) {
            emit ProposalExecuted(proposalId, true);
        } catch {
            proposal.state = ProposalState.Succeeded; // 回滚状态，允许重试
            emit ProposalExecuted(proposalId, false);
            revert("Gov: execution failed");
        }
    }

    /**
     * @dev 获取提案状态
     */
    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        require(proposalId <= proposalCount && proposalId > 0, "Gov: invalid proposal id");
        
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.state == ProposalState.Executed) {
            return ProposalState.Executed;
        }
        
        if (block.number <= proposal.endBlock) {
            if (block.number < proposal.startBlock) {
                return ProposalState.Pending;
            }
            return ProposalState.Active;
        }
        
        // 投票结束，检查结果
        if (proposal.forVotes > proposal.againstVotes && proposal.forVotes >= quorum) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }

    /**
     * @dev 获取提案信息
     */
    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        string memory description,
        address target,
        uint256 amount,
        string memory reason,
        uint256 startBlock,
        uint256 endBlock,
        uint256 forVotes,
        uint256 againstVotes,
        ProposalState state
    ) {
        require(proposalId <= proposalCount && proposalId > 0, "Gov: invalid proposal id");
        
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.target,
            proposal.amount,
            proposal.reason,
            proposal.startBlock,
            proposal.endBlock,
            proposal.forVotes,
            proposal.againstVotes,
            this.getProposalState(proposalId)
        );
    }

    /**
     * @dev 检查用户是否已投票
     */
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        require(proposalId <= proposalCount && proposalId > 0, "Gov: invalid proposal id");
        return proposals[proposalId].hasVoted[voter];
    }

    /**
     * @dev 获取用户投票选择
     */
    function getVote(uint256 proposalId, address voter) external view returns (bool) {
        require(proposalId <= proposalCount && proposalId > 0, "Gov: invalid proposal id");
        require(proposals[proposalId].hasVoted[voter], "Gov: voter has not voted");
        return proposals[proposalId].votes[voter];
    }

    /**
     * @dev 设置投票参数 - 仅用于测试
     */
    function setVotingParameters(
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorum
    ) external {
        // 在实际项目中，这个函数应该通过治理投票来修改
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorum = _quorum;
    }
} 