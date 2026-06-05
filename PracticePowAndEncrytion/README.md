# PoW 和 RSA 非对称加密实践

这是一个演示工作量证明（PoW）和 RSA 非对称加密签名验证的项目，提供了 Go 和 Node.js 两种实现。

## 功能特性

### 1. 工作量证明 (PoW)
- 使用 SHA256 哈希算法
- 寻找以 4 个 0 开头的哈希值
- 寻找以 5 个 0 开头的哈希值
- 显示计算时间和尝试次数
- 打印 Nonce 值，便于追踪结果

### 2. RSA 非对称加密
- 生成 2048 位 RSA 密钥对
- 使用私钥对符合 PoW 条件的数据进行签名
- 使用公钥验证签名的有效性
- 采用 PKCS#1 v1.5 签名标准
- **Node.js 版本**: 公钥使用 SPKI 格式，私钥使用 PKCS#8 格式（更现代的标准）

## 项目结构

```
PracticePowAndEncrytion/
├── Rsa_pow.go  # Go 语言实现
├── rsa_pow.js  # Node.js 实现
└── README.md   # 说明文档
```

## 快速开始

### Go 版本

确保已安装 Go 1.13+：

```bash
cd PracticePowAndEncrytion
go run Rsa_pow.go
```

### Node.js 版本

确保已安装 Node.js：

```bash
cd PracticePowAndEncrytion
node rsa_pow.js
```

### 程序输出示例

```
=== 开始 RSA + PoW 实践 ===
昵称: CryptoExplorer

--- 步骤1: 生成 RSA 密钥对 ---
RSA 密钥对生成成功！

=== 处理 4 个 0 开头的哈希值 ===

--- 步骤2: 寻找符合条件的哈希值 ---
找到满足条件的哈希值！
花费时间: 2.467625ms
Nonce值: 2709
Hash 内容: CryptoExplorer2709
Hash 值: 0000ced769b58655d67fe80539e9525c1d2a1aa773258d0e85ad77abe1216506

--- 步骤3: 用私钥对数据进行签名 ---
签名成功！
签名值: [签名值]

--- 步骤4: 用公钥验证签名 ---
签名验证成功！

--- 总结 ---
数据内容: CryptoExplorer2709
哈希值: 0000ced769b58655d67fe80539e9525c1d2a1aa773258d0e85ad77abe1216506
签名验证: true

=== 处理 5 个 0 开头的哈希值 ===

--- 步骤2: 寻找符合条件的哈希值 ---
已尝试 100000 个 nonce...
...
找到满足条件的哈希值！
花费时间: 1.980780557s
Nonce值: 2507720
Hash 内容: CryptoExplorer2507720
Hash 值: 000007e48683870314f943df84b17f66434e277f03929920e91d7d4d96bf25e2
```

## 技术细节

### PoW 原理
- 不断递增 nonce 值
- 对 "昵称 + nonce" 进行 SHA256 哈希
- 检查哈希是否以指定数量的 0 开头
- 满足条件即停止

### RSA 签名流程
1. 对数据进行 SHA256 哈希
2. 使用私钥对哈希值进行签名
3. 使用公钥验证签名的正确性

### 难度对比

| 前置 0 数量 | 平均尝试次数 | 相对难度 |
|------------|------------|---------|
| 4          | ~2,709     | 1x      |
| 5          | ~2,507,720 | ~1000x  |

每增加一个前置 0，难度大约增加 16 倍（因为每一位有 16 种可能的十六进制值）。

## 核心函数

### Go 版本
- `generateRSAKeyPair()` - 生成 RSA 密钥对
- `findHash()` - 寻找符合 PoW 条件的哈希
- `signData()` - 使用私钥签名数据
- `verifySignature()` - 使用公钥验证签名

### Node.js 版本
- `generateRSAKeyPair()` - 生成 RSA 密钥对（异步）
- `findHash()` - 寻找符合 PoW 条件的哈希
- `signData()` - 使用私钥签名数据
- `verifySignature()` - 使用公钥验证签名

## 学习要点

1. **工作量证明** - 理解 PoW 如何通过计算难度确保网络安全
2. **非对称加密** - 了解公钥和私钥的用途及工作原理
3. **数字签名** - 掌握如何使用 RSA 进行数据签名和验证
4. **哈希算法** - 认识 SHA256 在密码学中的应用
5. **多语言实现** - 对比 Go 和 Node.js 在密码学操作上的差异

## 依赖

### Go 版本
- Go 1.13+
- 标准库：`crypto`, `crypto/rand`, `crypto/rsa`, `crypto/sha256`

### Node.js 版本
- Node.js (建议 v12+)
- 内置 `crypto` 模块

## 许可证

本项目仅用于学习目的。
