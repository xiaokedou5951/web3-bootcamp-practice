// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/VoteToken.sol";
import "../src/Bank.sol";
import "../src/Gov.sol";

contract DAOTest is Test {
    VoteToken public voteToken;
    Bank public bank;
    Gov public gov;

    address public deployer = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);
    address public recipient = address(0x5);

    uint256 public constant INITIAL_SUPPLY = 100000 * 10**18;

    function setUp() public {
        vm.startPrank(deployer);

        // Deploy VoteToken
        voteToken = new VoteToken(
            "DAO Token",
            "DAO",
            INITIAL_SUPPLY,
            deployer
        );

        // Deploy Bank (deployer as initial admin)
        bank = new Bank(deployer);

        // Deploy Gov
        gov = new Gov(address(voteToken), address(bank));

        // Set Gov as Bank admin
        bank.addAdmin(address(gov));
        bank.removeAdmin(deployer); // Remove deployer admin privileges

        // Set voting parameters suitable for testing
        gov.setVotingParameters(
            1,      // votingDelay: 1 block
            10,     // votingPeriod: 10 blocks  
            1000 * 10**18,  // proposalThreshold: 1000 tokens
            4000 * 10**18   // quorum: 4000 tokens
        );

        // Distribute tokens
        voteToken.transfer(user1, 10000 * 10**18);
        voteToken.transfer(user2, 15000 * 10**18);
        voteToken.transfer(user3, 5000 * 10**18);

        // Deposit some funds to Bank
        vm.deal(deployer, 10 ether);
        bank.deposit{value: 5 ether}();

        vm.stopPrank();

        console.log("=== DAO System Deployed ===");
        console.log("VoteToken address:", address(voteToken));
        console.log("Bank address:", address(bank));
        console.log("Gov address:", address(gov));
        console.log("Bank balance:", bank.getBalance());
        console.log("User1 token balance:", voteToken.balanceOf(user1));
        console.log("User2 token balance:", voteToken.balanceOf(user2));
        console.log("User3 token balance:", voteToken.balanceOf(user3));
        console.log("");
    }

    function testCompleteDAOWorkflow() public {
        console.log("=== Starting Complete DAO Workflow Test ===");
        
        // Step 1: Create proposal
        _testCreateProposal();
        
        // Step 2: Voting process
        _testVoting();
        
        // Step 3: Execute proposal
        _testExecution();
        
        console.log("=== DAO Workflow Test Completed ===");
    }

    function _testCreateProposal() internal {
        console.log("--- Step 1: Create Proposal ---");
        
        uint256 withdrawAmount = 1 ether;
        string memory description = "Pay development fee to community developers";
        string memory reason = "Develop new features";

        // User1 creates proposal
        vm.startPrank(user1);
        
        uint256 user1Votes = voteToken.getVotes(user1);
        console.log("User1 current voting weight:", user1Votes);
        require(user1Votes >= 1000 * 10**18, "User1 voting weight insufficient for proposal");

        uint256 proposalId = gov.propose(
            description,
            payable(recipient),
            withdrawAmount,
            reason
        );

        vm.stopPrank();

        console.log("Proposal created successfully!");
        console.log("Proposal ID:", proposalId);
        console.log("Proposal description:", description);
        console.log("Withdraw amount:", withdrawAmount);
        console.log("Withdraw target:", recipient);
        console.log("Withdraw reason:", reason);

        // Verify proposal info
        (
            address proposer,
            string memory desc,
            address target,
            uint256 amount,
            string memory _reason,
            uint256 startBlock,
            uint256 endBlock,
            uint256 forVotes,
            uint256 againstVotes,
            Gov.ProposalState state
        ) = gov.getProposal(proposalId);

        assertEq(proposer, user1);
        assertEq(target, recipient);
        assertEq(amount, withdrawAmount);
        assertTrue(state == Gov.ProposalState.Pending);
        
        console.log("Voting start block:", startBlock);
        console.log("Voting end block:", endBlock);
        console.log("Current block:", block.number);
        console.log("");
    }

    function _testVoting() internal {
        console.log("--- Step 2: Voting Process ---");
        
        uint256 proposalId = 1;

        // Wait for voting to start
        vm.roll(block.number + 2); // Skip voting delay
        console.log("Voting phase started, current block:", block.number);

        // User1 votes FOR
        vm.startPrank(user1);
        uint256 user1Weight = voteToken.getPastVotes(user1, block.number - 1);
        gov.castVote(proposalId, true);
        vm.stopPrank();
        console.log("User1 voted: FOR, weight:", user1Weight);

        // User2 votes FOR
        vm.startPrank(user2);
        uint256 user2Weight = voteToken.getPastVotes(user2, block.number - 1);
        gov.castVote(proposalId, true);
        vm.stopPrank();
        console.log("User2 voted: FOR, weight:", user2Weight);

        // User3 votes AGAINST
        vm.startPrank(user3);
        uint256 user3Weight = voteToken.getPastVotes(user3, block.number - 1);
        gov.castVote(proposalId, false);
        vm.stopPrank();
        console.log("User3 voted: AGAINST, weight:", user3Weight);

        // Verify voting results
        (,,,,,,,uint256 forVotes, uint256 againstVotes,) = gov.getProposal(proposalId);
        console.log("Current FOR votes:", forVotes);
        console.log("Current AGAINST votes:", againstVotes);

        // Verify voting status
        assertTrue(gov.hasVoted(proposalId, user1));
        assertTrue(gov.hasVoted(proposalId, user2));
        assertTrue(gov.hasVoted(proposalId, user3));
        assertTrue(gov.getVote(proposalId, user1));
        assertTrue(gov.getVote(proposalId, user2));
        assertFalse(gov.getVote(proposalId, user3));

        console.log("Voting phase completed");
        console.log("");
    }

    function _testExecution() internal {
        console.log("--- Step 3: Execute Proposal ---");
        
        uint256 proposalId = 1;

        // Wait for voting to end
        vm.roll(block.number + 15); // Beyond voting period
        console.log("Voting ended, current block:", block.number);

        // Check proposal status
        Gov.ProposalState state = gov.getProposalState(proposalId);
        console.log("Proposal current status:", uint256(state));
        assertTrue(state == Gov.ProposalState.Succeeded, "Proposal should succeed");

        // Record balances before execution
        uint256 bankBalanceBefore = bank.getBalance();
        uint256 recipientBalanceBefore = recipient.balance;
        console.log("Bank balance before execution:", bankBalanceBefore);
        console.log("Recipient balance before execution:", recipientBalanceBefore);

        // Execute proposal
        gov.execute(proposalId);

        // Record balances after execution
        uint256 bankBalanceAfter = bank.getBalance();
        uint256 recipientBalanceAfter = recipient.balance;
        console.log("Bank balance after execution:", bankBalanceAfter);
        console.log("Recipient balance after execution:", recipientBalanceAfter);

        // Verify execution results
        assertEq(bankBalanceAfter, bankBalanceBefore - 1 ether);
        assertEq(recipientBalanceAfter, recipientBalanceBefore + 1 ether);

        // Verify proposal status
        Gov.ProposalState finalState = gov.getProposalState(proposalId);
        assertTrue(finalState == Gov.ProposalState.Executed, "Proposal should be executed");

        console.log("Proposal executed successfully!");
        console.log("Final proposal status:", uint256(finalState));
        console.log("");
    }

    function testDefeatedProposal() public {
        console.log("=== Testing Failed Proposal ===");

        // Create proposal
        vm.startPrank(user1);
        uint256 proposalId = gov.propose(
            "Test failed proposal",
            payable(recipient),
            1 ether,
            "Testing"
        );
        vm.stopPrank();

        // Wait for voting to start
        vm.roll(block.number + 2);

        // Only User3 votes AGAINST (5000 tokens, meets quorum but votes against)
        vm.startPrank(user3);
        gov.castVote(proposalId, false);
        vm.stopPrank();

        // Wait for voting to end
        vm.roll(block.number + 15);

        // Check status - should be defeated because no FOR votes
        Gov.ProposalState state = gov.getProposalState(proposalId);
        assertTrue(state == Gov.ProposalState.Defeated, "Proposal should be defeated");

        console.log("Failed proposal test completed, status:", uint256(state));
        console.log("");
    }

    function testInsufficientVotingPower() public {
        console.log("=== Testing Insufficient Voting Power ===");

        // Try to create proposal with account that has insufficient tokens
        address lowPowerUser = address(0x6);
        vm.deal(lowPowerUser, 1 ether);
        
        vm.startPrank(user1);
        voteToken.transfer(lowPowerUser, 500 * 10**18); // Less than threshold
        vm.stopPrank();

        vm.startPrank(lowPowerUser);
        vm.expectRevert("Gov: proposer votes below proposal threshold");
        gov.propose(
            "Invalid proposal",
            payable(recipient),
            1 ether,
            "Test"
        );
        vm.stopPrank();

        console.log("Insufficient voting power test completed");
        console.log("");
    }

    function testComplexVotingScenario() public {
        console.log("=== Testing Complex Voting Scenario ===");

        // Create proposal
        vm.startPrank(user1);
        uint256 proposalId = gov.propose(
            "Complex voting test",
            payable(recipient),
            2 ether,
            "Complex scenario test"
        );
        vm.stopPrank();

        // Wait for voting to start
        vm.roll(block.number + 2);

        // Record voting weights
        uint256 user1Weight = voteToken.getPastVotes(user1, block.number - 1);
        uint256 user2Weight = voteToken.getPastVotes(user2, block.number - 1);
        uint256 user3Weight = voteToken.getPastVotes(user3, block.number - 1);

        console.log("Voting weights:");
        console.log("User1:", user1Weight);
        console.log("User2:", user2Weight);
        console.log("User3:", user3Weight);

        // User1 and User3 vote AGAINST
        vm.startPrank(user1);
        gov.castVote(proposalId, false);
        vm.stopPrank();

        vm.startPrank(user3);
        gov.castVote(proposalId, false);
        vm.stopPrank();

        // User2 votes FOR
        vm.startPrank(user2);
        gov.castVote(proposalId, true);
        vm.stopPrank();

        // Wait for voting to end
        vm.roll(block.number + 15);

        // Check results - more AGAINST votes, should be defeated
        (,,,,,,,uint256 forVotes, uint256 againstVotes,) = gov.getProposal(proposalId);
        console.log("Final voting results:");
        console.log("FOR:", forVotes);
        console.log("AGAINST:", againstVotes);

        Gov.ProposalState state = gov.getProposalState(proposalId);
        assertTrue(state == Gov.ProposalState.Defeated, "Proposal should be defeated");

        console.log("Complex voting scenario test completed, status:", uint256(state));
        console.log("");
    }

    // Helper function: Print event logs
    function testEventLogs() public {
        console.log("=== Event Logs Test ===");

        // Create proposal and listen for events
        vm.startPrank(user1);
        
        vm.recordLogs();
        uint256 proposalId = gov.propose(
            "Event test proposal",
            payable(recipient),
            1 ether,
            "Test events"
        );
        
        Vm.Log[] memory logs = vm.getRecordedLogs();
        console.log("ProposalCreated event triggered, log count:", logs.length);
        
        vm.stopPrank();

        // Vote and listen for events
        vm.roll(block.number + 2);
        
        vm.startPrank(user1);
        vm.recordLogs();
        gov.castVote(proposalId, true);
        logs = vm.getRecordedLogs();
        console.log("VoteCast event triggered, log count:", logs.length);
        vm.stopPrank();

        vm.startPrank(user2);
        gov.castVote(proposalId, true);
        vm.stopPrank();

        // Execute and listen for events
        vm.roll(block.number + 15);
        
        vm.recordLogs();
        gov.execute(proposalId);
        logs = vm.getRecordedLogs();
        console.log("ProposalExecuted event triggered, log count:", logs.length);

        console.log("Event logs test completed");
        console.log("");
    }
} 