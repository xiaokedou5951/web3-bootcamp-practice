# MiniBlockChain - Go 实现的简易区块链

一个使用 Go 语言实现的简化版区块链系统，用于学习区块链核心概念：交易、区块、工作量证明（PoW）、节点广播和共识机制。

## 功能特性

- **交易 (Transaction)** - 记录地址之间的金额转移，包含时间戳
- **区块 (Block)** - 将多笔交易打包为一个区块，通过哈希与前一区块链接
- **工作量证明 (Proof of Work)** - 通过调整 Nonce 值寻找以 N 个 0 开头的哈希值，模拟挖矿
- **区块链 (Blockchain)** - 维护完整的链式区块结构，提供余额查询和完整性验证
- **节点广播** - 模拟向网络中其他节点广播新区块
- **共识算法** - 基于"最长有效链"规则解决链冲突

## 核心数据结构

### Transaction
| 字段          | 类型    | 说明                 |
|---------------|---------|----------------------|
| FromAddress   | string  | 发送方地址           |
| ToAddress     | string  | 接收方地址           |
| Amount        | int64   | 交易金额             |
| Timestamp     | int64   | 时间戳（毫秒）       |

### Block
| 字段          | 类型              | 说明                       |
|---------------|-------------------|----------------------------|
| Timestamp     | int64             | 区块创建时间               |
| Transactions  | []\*Transaction    | 区块包含的交易列表         |
| PreviousHash  | string            | 前一区块哈希值             |
| Hash          | string            | 当前区块哈希值             |
| Nonce         | int               | 工作量证明随机数           |

### Blockchain
| 字段               | 类型                 | 说明                       |
|--------------------|----------------------|----------------------------|
| Chain              | []\*Block             | 区块链表                   |
| Difficulty         | int                  | 挖矿难度（默认 4，即 4 个 0） |
| PendingTransactions| []\*Transaction       | 待打包的交易队列           |
| MiningReward       | int64                | 挖矿奖励金额（默认 100）   |
| Nodes              | map[string]bool       | 已注册的节点列表           |

## 核心机制说明

### 1. 哈希计算
使用 SHA256 算法对区块/交易内容进行哈希运算，确保数据的唯一标识和不可篡改。

### 2. 工作量证明（PoW）
挖矿过程不断递增 Nonce 值，重新计算区块哈希，直到哈希值的前 `Difficulty` 位均为 0。

### 3. 区块链链接
每个新区块的 `PreviousHash` 必须等于链中最后一个区块的 `Hash`，形成一条不可分割的链。

### 4. 挖矿奖励
挖出新区块后，系统创建一笔 `fromAddress = ""` 的奖励交易添加到待处理队列，待下一次挖矿时被打包进链。

### 5. 链完整性验证
遍历所有区块，检查：
- 当前区块哈希值是否与重新计算一致
- 当前区块的 `PreviousHash` 是否等于前一区块的 `Hash`

## 运行方式

```bash
# 进入目录
cd MiniBlockChain

# 方式一：直接运行（自动初始化模块）
go mod init mini_block_chain
go run mini_block_chain.go

# 方式二：先构建再运行
go build -o mini_block_chain mini_block_chain.go
./mini_block_chain
```

## 输出示例

```
创建区块链...
创建交易...
开始挖矿...
开始挖矿...
区块已挖出! 哈希值: 0000a77c53b0cdf7899696e0179c5c73c3a879a59465a62a63f6d630b16beffd
区块成功挖出!
向所有节点广播新区块
矿工余额: 0
再次挖矿...
开始挖矿...
区块已挖出! 哈希值: 000093a696f8e90e4d825bb3cb3688e758a0b0d8b3e3f88098f162c41820ab9e
区块成功挖出!
向所有节点广播新区块
矿工余额: 100
区块链是否有效: true
{ ... JSON 格式的完整链 ... }
```

> 注意：第一次挖矿后矿工余额为 0，是因为奖励交易被添加到了待处理队列，需等待下一次挖矿被打包进区块。

## 主要 API

| 函数 | 说明 |
|------|------|
| `NewBlockchain()` | 创建一条新链（含创世区块） |
| `bc.CreateTransaction(tx)` | 添加交易到待处理队列 |
| `bc.MinePendingTransactions(address)` | 挖矿并发放奖励 |
| `bc.GetBalanceOfAddress(address)` | 查询地址余额 |
| `bc.IsChainValid()` | 验证链完整性 |
| `bc.RegisterNode(nodeUrl)` | 注册网络节点 |
| `bc.ReceiveNewBlock(block, url)` | 接收并验证外来区块 |
| `bc.ResolveConflicts(chains)` | 解决链冲突 |

## 学习建议

1. 从 `Transaction` 结构体入手，理解交易的本质
2. 理解 `Block` 如何通过 `PreviousHash` 与 `Hash` 形成链接
3. 深入 `MineBlock` 函数体会工作量证明的计算过程
4. 跟踪 `MinePendingTransactions` 观察奖励机制
5. 尝试修改 `Difficulty` 观察挖矿耗时的变化

## 依赖

- Go 1.18+
- 标准库（crypto/sha256、encoding/json、time 等），无需外部依赖
