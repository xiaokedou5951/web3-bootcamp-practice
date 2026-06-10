package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"
)

// Transaction 交易结构体
// 表示区块链中的一笔交易，包含发送方地址、接收方地址、交易金额和时间戳
type Transaction struct {
	FromAddress string // 发送方地址（从哪个地址转出）
	ToAddress   string // 接收方地址（转入到哪个地址）
	Amount      int64  // 交易金额
	Timestamp   int64  // 交易时间戳（毫秒）
}

// NewTransaction 创建一笔新交易
// 参数: fromAddress 发送方地址, toAddress 接收方地址, amount 交易金额
// 返回: 新创建的交易对象指针
func NewTransaction(fromAddress, toAddress string, amount int64) *Transaction {
	return &Transaction{
		FromAddress: fromAddress,
		ToAddress:   toAddress,
		Amount:      amount,
		Timestamp:   time.Now().UnixMilli(),
	}
}

// CalculateHash 计算交易的哈希值
// 将交易的所有字段拼接后进行 SHA256 哈希计算，得到交易的唯一标识
// 返回: 十六进制编码的哈希字符串
func (t *Transaction) CalculateHash() string {
	data := t.FromAddress + t.ToAddress + strconv.FormatInt(t.Amount, 10) + strconv.FormatInt(t.Timestamp, 10)
	hash := sha256.Sum256([]byte(data))
	return hex.EncodeToString(hash[:])
}

// Block 区块结构体
// 区块链中的基本单元，包含时间戳、交易列表、前一区块哈希、当前哈希和Nonce值
type Block struct {
	Timestamp    int64          // 区块创建时间戳（毫秒）
	Transactions []*Transaction // 区块中包含的交易列表
	PreviousHash string         // 前一区块的哈希值，用于链接区块
	Hash         string         // 当前区块的哈希值（区块唯一标识）
	Nonce        int            // 工作量证明中使用的随机数
}

// NewBlock 创建一个新区块
// 参数: timestamp 时间戳, transactions 交易列表, previousHash 前一区块哈希
// 返回: 新创建的区块对象指针
func NewBlock(timestamp int64, transactions []*Transaction, previousHash string) *Block {
	block := &Block{
		Timestamp:    timestamp,
		Transactions: transactions,
		PreviousHash: previousHash,
		Nonce:        0,
	}
	// 计算并设置区块的初始哈希值
	block.Hash = block.CalculateHash()
	return block
}

// CalculateHash 计算区块的哈希值
// 将前一区块哈希、时间戳、交易数据和Nonce值拼接后进行 SHA256 哈希计算
// 返回: 十六进制编码的区块哈希字符串
func (b *Block) CalculateHash() string {
	// 拼接前一区块哈希和时间戳
	data := b.PreviousHash + strconv.FormatInt(b.Timestamp, 10)
	// 将交易列表序列化为JSON字符串
	transactionsJSON, _ := json.Marshal(b.Transactions)
	// 拼接交易数据和Nonce值
	data += string(transactionsJSON) + strconv.Itoa(b.Nonce)
	// 计算SHA256哈希并转为十六进制字符串
	hash := sha256.Sum256([]byte(data))
	return hex.EncodeToString(hash[:])
}

// MineBlock 工作量证明 - 挖矿
// 通过不断递增Nonce值，直到找到一个使区块哈希值满足难度要求的Nonce
// 参数: difficulty 难度值（哈希值需要以多少个0开头）
func (b *Block) MineBlock(difficulty int) {
	// 构造目标字符串：difficulty个连续的0
	target := strings.Repeat("0", difficulty)

	fmt.Println("开始挖矿...")
	// 不断尝试，直到找到符合要求的哈希值
	for b.Hash[:difficulty] != target {
		// 递增Nonce值
		b.Nonce++
		// 重新计算区块哈希
		b.Hash = b.CalculateHash()
	}

	fmt.Printf("区块已挖出! 哈希值: %s\n", b.Hash)
}

// Blockchain 区块链结构体
// 整个区块链系统的核心结构，包含区块链、难度设置、待处理交易、挖矿奖励和网络节点
type Blockchain struct {
	Chain               []*Block        // 区块链，存储所有区块的切片
	Difficulty          int             // 挖矿难度（哈希值需要以多少个0开头）
	PendingTransactions []*Transaction  // 待处理的交易列表，等待被打包进区块
	MiningReward        int64           // 挖矿奖励金额，成功挖出区块后奖励给矿工
	Nodes               map[string]bool // 网络中的其他节点集合
}

// NewBlockchain 创建一个新的区块链实例
// 初始化创世区块、设置默认难度为4、初始化待处理交易列表和挖矿奖励
// 返回: 新创建的区块链对象指针
func NewBlockchain() *Blockchain {
	return &Blockchain{
		Chain:               []*Block{createGenesisBlock()}, // 创世区块作为链的起点
		Difficulty:          4,                              // 设置难度为4个0
		PendingTransactions: []*Transaction{},               // 初始时没有待处理交易
		MiningReward:        100,                            // 默认挖矿奖励100
		Nodes:               make(map[string]bool),          // 初始化空节点集合
	}
}

// createGenesisBlock 创建创世区块
// 创世区块是区块链的第一个区块，没有前一区块，previousHash设置为"0"
// 返回: 创世区块对象指针
func createGenesisBlock() *Block {
	return NewBlock(time.Now().UnixMilli(), []*Transaction{}, "0")
}

// GetLatestBlock 获取区块链的最新区块
// 返回: 链中最后一个区块的指针
func (bc *Blockchain) GetLatestBlock() *Block {
	return bc.Chain[len(bc.Chain)-1]
}

// CreateTransaction 添加待处理交易
// 将一笔新交易添加到待处理交易列表中，等待下次挖矿时被打包进区块
// 参数: transaction 待添加的交易对象
func (bc *Blockchain) CreateTransaction(transaction *Transaction) {
	bc.PendingTransactions = append(bc.PendingTransactions, transaction)
}

// MinePendingTransactions 挖掘待处理交易
// 将当前所有待处理交易打包成一个新区块，进行挖矿，并添加到区块链上
// 挖矿完成后，重置待处理交易列表并向矿工发送奖励交易
// 参数: miningRewardAddress 矿工的奖励接收地址
func (bc *Blockchain) MinePendingTransactions(miningRewardAddress string) {
	// 创建包含所有待处理交易的新区块，链接到最新区块
	block := NewBlock(time.Now().UnixMilli(), bc.PendingTransactions, bc.GetLatestBlock().Hash)

	// 进行挖矿以满足难度要求
	block.MineBlock(bc.Difficulty)

	fmt.Println("区块成功挖出!")
	// 将挖出的新区块添加到区块链末端
	bc.Chain = append(bc.Chain, block)

	// 重置待处理交易列表，并创建一笔奖励交易给矿工
	bc.PendingTransactions = []*Transaction{
		NewTransaction("", miningRewardAddress, bc.MiningReward),
	}

	// 向网络中的其他节点广播新区块
	bc.broadcastNewBlock()
}

// GetBalanceOfAddress 获取指定地址的余额
// 遍历区块链中所有交易，计算指定地址的收支情况
// 参数: address 要查询余额的地址
// 返回: 该地址的当前余额
func (bc *Blockchain) GetBalanceOfAddress(address string) int64 {
	var balance int64 = 0

	// 遍历区块链中的每个区块
	for _, block := range bc.Chain {
		// 遍历区块中的每笔交易
		for _, trans := range block.Transactions {
			// 如果是该地址转出，余额减少
			if trans.FromAddress == address {
				balance -= trans.Amount
			}
			// 如果是该地址转入，余额增加
			if trans.ToAddress == address {
				balance += trans.Amount
			}
		}
	}

	return balance
}

// IsChainValid 验证区块链的完整性
// 检查每个区块的哈希值是否有效，以及每个区块是否正确链接到前一区块
// 返回: 如果区块链有效返回true，否则返回false
func (bc *Blockchain) IsChainValid() bool {
	// 从第二个区块开始遍历（跳过创世区块）
	for i := 1; i < len(bc.Chain); i++ {
		currentBlock := bc.Chain[i]
		previousBlock := bc.Chain[i-1]

		// 验证当前区块的哈希值是否与重新计算的哈希一致
		if currentBlock.Hash != currentBlock.CalculateHash() {
			return false
		}

		// 验证当前区块的previousHash是否等于前一区块的哈希（验证区块链接）
		if currentBlock.PreviousHash != previousBlock.Hash {
			return false
		}
	}

	return true
}

// RegisterNode 添加节点到网络
// 将指定的节点URL注册到当前节点的网络节点列表中
// 参数: nodeUrl 要添加的节点URL地址
func (bc *Blockchain) RegisterNode(nodeUrl string) {
	bc.Nodes[nodeUrl] = true
	fmt.Printf("节点 %s 已添加到网络\n", nodeUrl)
}

// broadcastNewBlock 广播新区块到所有节点
// 在实际应用中，这里应该使用HTTP请求或WebSocket向其他节点发送新区块
// 当前仅为模拟输出
func (bc *Blockchain) broadcastNewBlock() {
	fmt.Println("向所有节点广播新区块")
	// 遍历所有已注册的节点
	for node := range bc.Nodes {
		fmt.Printf("发送区块到节点: %s\n", node)
		// 这里应该有实际的网络通信代码
	}
}

// ReceiveNewBlock 接收并验证来自其他节点的新区块
// 验证新区块的前一区块哈希是否匹配、工作量证明是否有效，验证通过后添加到本地区块链
// 同时从待处理交易列表中移除已被新区块包含的交易
// 参数: newBlock 待接收的新区块, senderNodeUrl 发送该区块的节点URL
// 返回: 区块被接受返回true，被拒绝返回false
func (bc *Blockchain) ReceiveNewBlock(newBlock *Block, senderNodeUrl string) bool {
	latestBlock := bc.GetLatestBlock()

	// 验证新区块的previousHash是否指向我们的最新区块
	if newBlock.PreviousHash != latestBlock.Hash {
		fmt.Println("拒绝区块: previousHash不匹配")
		return false
	}

	// 验证新区块的哈希值是否满足难度要求（工作量证明）
	target := strings.Repeat("0", bc.Difficulty)
	if newBlock.Hash[:bc.Difficulty] != target {
		fmt.Println("拒绝区块: 工作量证明无效")
		return false
	}

	// 添加新区块到链中
	bc.Chain = append(bc.Chain, newBlock)
	fmt.Printf("接受来自节点 %s 的新区块\n", senderNodeUrl)

	// 更新待处理交易：移除已被新区块包含的交易
	var newPendingTransactions []*Transaction
	for _, t := range bc.PendingTransactions {
		found := false
		// 检查当前待处理交易是否已存在于新区块中
		for _, bt := range newBlock.Transactions {
			if bt.FromAddress == t.FromAddress &&
				bt.ToAddress == t.ToAddress &&
				bt.Amount == t.Amount {
				found = true
				break
			}
		}
		// 如果不在新区块中，则保留到新的待处理列表
		if !found {
			newPendingTransactions = append(newPendingTransactions, t)
		}
	}
	bc.PendingTransactions = newPendingTransactions

	return true
}

// ResolveConflicts 解决链冲突 - 共识算法
// 比较本地区块链与其他节点提供的链，选择最长且有效的链替换当前链
// 这是区块链中"最长链规则"的实现，确保网络中的节点达成共识
// 参数: chains 其他节点提供的区块链列表
// 返回: 如果链被替换返回true，否则返回false
func (bc *Blockchain) ResolveConflicts(chains [][]*Block) bool {
	// 记录当前链的长度作为基准
	maxLength := len(bc.Chain)
	var newChain []*Block

	// 遍历所有外来链，寻找最长的有效链
	for _, chain := range chains {
		// 如果外来链更长且有效，则选择它
		if len(chain) > maxLength && bc.isValidChain(chain) {
			maxLength = len(chain)
			newChain = chain
		}
	}

	// 如果找到了更长的有效链，替换当前链
	if newChain != nil {
		bc.Chain = newChain
		fmt.Println("链已替换为更长的链")
		return true
	}

	fmt.Println("当前链已是最长链")
	return false
}

// isValidChain 验证提供的链是否有效
// 检查创世区块是否匹配，以及每个区块的哈希和链接关系是否正确
// 参数: chain 待验证的区块链切片
// 返回: 链有效返回true，否则返回false
func (bc *Blockchain) isValidChain(chain []*Block) bool {
	// 检查创世区块：将本地创世区块与待验证链的第一个区块进行JSON对比
	genesisBlock := createGenesisBlock()
	genesisJSON, _ := json.Marshal(genesisBlock)
	chainGenesisJSON, _ := json.Marshal(chain[0])
	if string(genesisJSON) != string(chainGenesisJSON) {
		return false
	}

	// 验证链中的每个区块（从第二个区块开始）
	for i := 1; i < len(chain); i++ {
		block := chain[i]
		previousBlock := chain[i-1]

		// 验证区块链接：当前区块的previousHash应等于前一区块的hash
		if block.PreviousHash != previousBlock.Hash {
			return false
		}

		// 验证当前区块的哈希值是否正确（防止数据被篡改）
		if block.Hash != block.CalculateHash() {
			return false
		}
	}

	return true
}

// runDemo 运行演示程序
// 演示区块链的完整工作流程：创建链、创建交易、挖矿、查询余额、验证链完整性
func runDemo() {
	// 创建区块链实例
	myCoin := NewBlockchain()
	fmt.Println("创建区块链...")

	// 创建一些初始交易
	fmt.Println("创建交易...")
	myCoin.CreateTransaction(NewTransaction("address1", "address2", 100))
	myCoin.CreateTransaction(NewTransaction("address2", "address1", 50))

	// 进行第一次挖矿，将上述交易打包进区块
	fmt.Println("开始挖矿...")
	myCoin.MinePendingTransactions("miner-address")

	// 查看矿工第一次挖矿后的余额（此时奖励交易还未被打包进区块）
	fmt.Printf("矿工余额: %d\n", myCoin.GetBalanceOfAddress("miner-address"))

	// 再创建一些新的交易
	myCoin.CreateTransaction(NewTransaction("address1", "address2", 200))
	myCoin.CreateTransaction(NewTransaction("address2", "address1", 100))

	// 再次挖矿（此时会将上一次的挖矿奖励交易打包进区块）
	fmt.Println("再次挖矿...")
	myCoin.MinePendingTransactions("miner-address")

	// 再次查看矿工余额（现在应该包含第一次挖矿的奖励）
	fmt.Printf("矿工余额: %d\n", myCoin.GetBalanceOfAddress("miner-address"))

	// 验证区块链的完整性
	fmt.Printf("区块链是否有效: %t\n", myCoin.IsChainValid())

	// 以JSON格式打印整个区块链数据结构
	chainJSON, _ := json.MarshalIndent(myCoin, "", "    ")
	fmt.Println(string(chainJSON))
}

// main 程序入口函数
// 启动演示程序，展示区块链的完整工作流程
func main() {
	runDemo()
}
