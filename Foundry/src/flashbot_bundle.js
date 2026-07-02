const { ethers } = require('ethers');
const { FlashbotsBundleProvider } = require('@flashbots/ethers-provider-bundle');
require('dotenv').config();

// OpenspaceNFT ABI (简化版，仅包含需要的函数)
const OPENSPACE_NFT_ABI = [
    "function enablePresale() external",
    "function presale(uint256 amount) external payable",
    "function isPresaleActive() external view returns (bool)",
    "function owner() external view returns (address)"
];

class FlashbotBundleExecutor {
    constructor() {
        // 验证环境变量
        this.validateEnvVars();
        
        // 初始化provider和signer
        this.provider = new ethers.providers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
        this.signer = new ethers.Wallet(process.env.PRIVATE_KEY, this.provider);
        this.nftContract = new ethers.Contract(
            process.env.OPENSPACE_NFT_ADDRESS,
            OPENSPACE_NFT_ABI,
            this.signer
        );
        
        console.log("✅ 初始化完成");
        console.log("钱包地址:", this.signer.address);
        console.log("NFT合约地址:", process.env.OPENSPACE_NFT_ADDRESS);
    }
    
    validateEnvVars() {
        const requiredVars = ['SEPOLIA_RPC_URL', 'PRIVATE_KEY', 'OPENSPACE_NFT_ADDRESS'];
        for (const varName of requiredVars) {
            if (!process.env[varName]) {
                throw new Error(`缺少环境变量: ${varName}`);
            }
        }
    }
    
    async initFlashbots() {
        try {
            // 初始化Flashbots provider
            this.flashbotsProvider = await FlashbotsBundleProvider.create(
                this.provider,
                this.signer,
                process.env.FLASHBOT_RELAY_URL || 'https://relay-sepolia.flashbots.net'
            );
            console.log("✅ Flashbots provider 初始化成功");
        } catch (error) {
            console.error("❌ Flashbots provider 初始化失败:", error);
            throw error;
        }
    }
    
    async checkContractStatus() {
        try {
            const isActive = await this.nftContract.isPresaleActive();
            const owner = await this.nftContract.owner();
            console.log("📊 合约状态:");
            console.log("- 预售是否激活:", isActive);
            console.log("- 合约owner:", owner);
            console.log("- 当前钱包是否为owner:", owner.toLowerCase() === this.signer.address.toLowerCase());
            return { isActive, owner, isOwner: owner.toLowerCase() === this.signer.address.toLowerCase() };
        } catch (error) {
            console.error("❌ 检查合约状态失败:", error);
            throw error;
        }
    }
    
    async createBundleTransactions() {
        try {
            console.log("🔨 创建捆绑交易...");
            
            const currentBlock = await this.provider.getBlockNumber();
            const baseFee = (await this.provider.getFeeData()).gasPrice;
            const nonce = await this.signer.getTransactionCount();
            
            console.log("当前区块:", currentBlock);
            console.log("当前nonce:", nonce);
            
            // 创建 enablePresale 交易
            const enablePresaleTx = await this.nftContract.populateTransaction.enablePresale();
            const enablePresaleTransaction = {
                ...enablePresaleTx,
                nonce: nonce,
                gasLimit: ethers.BigNumber.from("100000"),
                gasPrice: baseFee.mul(110).div(100), // 增加10%的gas价格以确保优先级
                chainId: 11155111 // Sepolia chainId
            };
            
            // 创建 presale 交易 (购买1个NFT，价格0.01 ETH)
            const presaleAmount = 1;
            const presaleValue = ethers.utils.parseEther("0.01").mul(presaleAmount);
            const presaleTx = await this.nftContract.populateTransaction.presale(presaleAmount, {
                value: presaleValue
            });
            const presaleTransaction = {
                ...presaleTx,
                nonce: nonce + 1,
                gasLimit: ethers.BigNumber.from("150000"),
                gasPrice: baseFee.mul(110).div(100),
                chainId: 11155111,
                value: presaleValue
            };
            
            console.log("📝 交易详情:");
            console.log("1. EnablePresale交易:");
            console.log("   - Nonce:", enablePresaleTransaction.nonce);
            console.log("   - Gas Limit:", enablePresaleTransaction.gasLimit.toString());
            console.log("   - Gas Price:", ethers.utils.formatUnits(enablePresaleTransaction.gasPrice, 'gwei'), "Gwei");
            
            console.log("2. Presale交易:");
            console.log("   - Nonce:", presaleTransaction.nonce);
            console.log("   - Gas Limit:", presaleTransaction.gasLimit.toString());
            console.log("   - Gas Price:", ethers.utils.formatUnits(presaleTransaction.gasPrice, 'gwei'), "Gwei");
            console.log("   - Value:", ethers.utils.formatEther(presaleTransaction.value), "ETH");
            
            return [enablePresaleTransaction, presaleTransaction];
        } catch (error) {
            console.error("❌ 创建交易失败:", error);
            throw error;
        }
    }
    
    async sendBundle(transactions) {
        try {
            console.log("📦 发送Flashbot捆绑交易...");
            
            const currentBlock = await this.provider.getBlockNumber();
            const targetBlock = currentBlock + 1;
            
            // 签名交易
            const signedTransactions = [];
            for (const tx of transactions) {
                const signedTx = await this.signer.signTransaction(tx);
                signedTransactions.push(signedTx);
            }
            
            // 创建bundle
            const bundle = signedTransactions.map(signedTransaction => ({
                signedTransaction
            }));
            
            // 发送bundle
            const bundleSubmission = this.flashbotsProvider.sendBundle(bundle, targetBlock);
            
            console.log("🎯 目标区块:", targetBlock);
            console.log("📤 Bundle已提交，等待结果...");
            
            const bundleResolution = await bundleSubmission;
            
            if ('error' in bundleResolution) {
                console.error("❌ Bundle提交失败:", bundleResolution.error);
                return null;
            }
            
            console.log("✅ Bundle提交成功!");
            console.log("Bundle Hash:", bundleResolution.bundleHash);
            
            return {
                bundleHash: bundleResolution.bundleHash,
                targetBlock: targetBlock,
                transactions: signedTransactions
            };
            
        } catch (error) {
            console.error("❌ 发送Bundle失败:", error);
            throw error;
        }
    }
    
    async waitForInclusion(bundleInfo) {
        try {
            console.log("⏳ 等待Bundle被包含在区块中...");
            
            // 等待几个区块确认Bundle是否被包含
            const maxWaitBlocks = 5;
            const startBlock = bundleInfo.targetBlock;
            
            for (let i = 0; i < maxWaitBlocks; i++) {
                const currentBlock = await this.provider.getBlockNumber();
                console.log(`检查区块 ${currentBlock}...`);
                
                if (currentBlock >= startBlock) {
                    // 检查我们的交易是否在区块中
                    const block = await this.provider.getBlock(currentBlock, true);
                    const bundleTxHashes = bundleInfo.transactions.map(tx => 
                        ethers.utils.keccak256(tx)
                    );
                    
                    const foundTxs = [];
                    for (const tx of block.transactions) {
                        if (typeof tx === 'object' && bundleTxHashes.includes(tx.hash)) {
                            foundTxs.push(tx.hash);
                        }
                    }
                    
                    if (foundTxs.length > 0) {
                        console.log("🎉 Bundle已被包含在区块中!");
                        console.log("区块号:", currentBlock);
                        console.log("交易哈希:", foundTxs);
                        return { success: true, blockNumber: currentBlock, txHashes: foundTxs };
                    }
                }
                
                // 等待下一个区块
                console.log("等待下一个区块...");
                await new Promise(resolve => setTimeout(resolve, 12000)); // Sepolia出块时间约12秒
            }
            
            console.log("⚠️ Bundle在等待时间内未被包含");
            return { success: false };
            
        } catch (error) {
            console.error("❌ 等待Bundle包含时出错:", error);
            throw error;
        }
    }
    
    async getBundleStats(bundleHash) {
        try {
            console.log("📊 获取Bundle统计信息...");
            
            // 使用flashbots_getBundleStats方法
            const stats = await this.flashbotsProvider.getBundleStats(bundleHash, 1);
            
            console.log("📈 Bundle统计信息:");
            console.log(JSON.stringify(stats, null, 2));
            
            return stats;
        } catch (error) {
            console.error("❌ 获取Bundle统计信息失败:", error);
            // 如果获取统计信息失败，返回基本信息
            return {
                bundleHash: bundleHash,
                error: "无法获取详细统计信息",
                timestamp: new Date().toISOString()
            };
        }
    }
    
    async execute() {
        try {
            console.log("🚀 开始执行Flashbot捆绑交易任务");
            console.log("=" * 50);
            
            // 1. 初始化Flashbots
            await this.initFlashbots();
            
            // 2. 检查合约状态
            const contractStatus = await this.checkContractStatus();
            
            if (!contractStatus.isOwner) {
                throw new Error("当前钱包不是合约owner，无法执行enablePresale");
            }
            
            // 3. 创建交易
            const transactions = await this.createBundleTransactions();
            
            // 4. 发送Bundle
            const bundleInfo = await this.sendBundle(transactions);
            
            if (!bundleInfo) {
                throw new Error("Bundle发送失败");
            }
            
            // 5. 等待包含确认
            const inclusionResult = await this.waitForInclusion(bundleInfo);
            
            // 6. 获取Bundle统计信息
            const stats = await this.getBundleStats(bundleInfo.bundleHash);
            
            // 7. 输出最终结果
            console.log("=" * 50);
            console.log("🎯 任务完成！最终结果:");
            console.log("=" * 50);
            console.log("Bundle Hash:", bundleInfo.bundleHash);
            console.log("目标区块:", bundleInfo.targetBlock);
            
            if (inclusionResult.success) {
                console.log("✅ 交易成功执行!");
                console.log("包含区块:", inclusionResult.blockNumber);
                console.log("交易哈希:");
                inclusionResult.txHashes.forEach((hash, index) => {
                    console.log(`  ${index + 1}. ${hash}`);
                });
            } else {
                console.log("⚠️ 交易未被包含，可能需要重试");
            }
            
            console.log("\n📊 Bundle统计信息:");
            console.log(JSON.stringify(stats, null, 2));
            
            return {
                bundleHash: bundleInfo.bundleHash,
                targetBlock: bundleInfo.targetBlock,
                included: inclusionResult.success,
                txHashes: inclusionResult.txHashes || [],
                stats: stats
            };
            
        } catch (error) {
            console.error("❌ 执行失败:", error);
            throw error;
        }
    }
}

// 主函数
async function main() {
    try {
        const executor = new FlashbotBundleExecutor();
        const result = await executor.execute();
        
        console.log("\n🎉 所有任务完成!");
        console.log("最终结果已保存，请查看上方输出。");
        
    } catch (error) {
        console.error("💥 程序执行失败:", error.message);
        process.exit(1);
    }
}

// 如果直接运行此脚本
if (require.main === module) {
    main();
}

module.exports = { FlashbotBundleExecutor }; 