// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Meme_Factory.sol";

contract MemeFactoryTest is Test {
    Meme_Factory public factory;
    address public projectOwner;
    address public creator;
    address public buyer;
    
    // 测试参数
    string constant SYMBOL = "MEME";
    uint256 constant TOTAL_SUPPLY = 1000000 * 10**18; // 1,000,000 tokens
    uint256 constant PER_MINT = 1000 * 10**18;       // 1,000 tokens per mint
    uint256 constant PRICE = 0.0001 ether;           // 0.0001 ETH per token
    
    function setUp() public {
        projectOwner = makeAddr("projectOwner");
        creator = makeAddr("creator");
        buyer = makeAddr("buyer");
        
        // 给测试账户一些 ETH
        vm.deal(creator, 10 ether);
        vm.deal(buyer, 10 ether);
        
        // 部署工厂合约
        factory = new Meme_Factory(projectOwner);
    }
    
    function testDeployInscription() public {
        vm.startPrank(creator);
        
        address tokenAddr = factory.deployInscription(
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        
        vm.stopPrank();
        
        // 验证代币部署成功
        assertTrue(factory.deployedTokens(tokenAddr), "Token not deployed");
        
        // 验证代币参数
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.totalSupply_(), TOTAL_SUPPLY, "Incorrect total supply");
        assertEq(token.perMint(), PER_MINT, "Incorrect per mint amount");
        assertEq(token.price(), PRICE, "Incorrect price");
        assertEq(token.memeCreator(), creator, "Incorrect creator");
    }
    
    function testMintInscription() public {
        // 部署代币
        vm.startPrank(creator);
        address tokenAddr = factory.deployInscription(
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();
        
        // 记录初始余额
        uint256 initialProjectBalance = projectOwner.balance;
        uint256 initialCreatorBalance = creator.balance;
        
        // 计算所需支付金额
        uint256 requiredAmount = PER_MINT * PRICE / 10**18;
        
        // 买家铸造代币
        vm.startPrank(buyer);
        factory.mintInscription{value: requiredAmount}(tokenAddr);
        vm.stopPrank();
        
        // 验证代币铸造成功
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.balanceOf(buyer), PER_MINT, "Incorrect minted amount");
        assertEq(token.mintedAmount(), PER_MINT, "Incorrect total minted amount");
        
        // 验证费用分配
        uint256 projectFee = (requiredAmount * factory.PROJECT_FEE_PERCENT()) / 100;
        uint256 creatorFee = requiredAmount - projectFee;
        
        assertEq(projectOwner.balance, initialProjectBalance + projectFee, "Incorrect project fee");
        assertEq(creator.balance, initialCreatorBalance + creatorFee, "Incorrect creator fee");
    }
    
    function testMintMultipleTimes() public {
        // 部署代币
        vm.startPrank(creator);
        address tokenAddr = factory.deployInscription(
            SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        vm.stopPrank();
        
        // 计算所需支付金额
        uint256 requiredAmount = PER_MINT * PRICE / 10**18;
        
        // 多次铸造，但限制次数以避免超过总供应量
        // 由于 TOTAL_SUPPLY = 1,000,000 * 10**18 且 PER_MINT = 1,000 * 10**18
        // 理论上最多可以铸造 1000 次，但为安全起见，我们只铸造几次进行测试
        uint256 testMints = 5; // 只测试铸造 5 次，避免测试耗时过长
        
        for (uint256 i = 0; i < testMints; i++) {
            vm.startPrank(buyer);
            factory.mintInscription{value: requiredAmount}(tokenAddr);
            vm.stopPrank();
            
            // 验证铸造数量
            MemeToken token = MemeToken(tokenAddr);
            assertEq(token.mintedAmount(), PER_MINT * (i + 1), "Incorrect total minted amount");
        }
        
        // 验证可以继续铸造（因为我们只铸造了少量代币）
        vm.startPrank(buyer);
        factory.mintInscription{value: requiredAmount}(tokenAddr);
        vm.stopPrank();
        
        // 验证铸造后的总量
        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.mintedAmount(), PER_MINT * (testMints + 1), "Incorrect final minted amount");
    }
}