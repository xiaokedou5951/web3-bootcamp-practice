一份 **完整的工程指南**：基于 OpenZeppelin 的 ERC-721 合约，将图片与元数据上传至去中心化存储（IPFS），并在 OpenSea上查看。你只需按步骤操作，就能获得真实的 OpenSea 链接。

---

## 1. 智能合约（Solidity + OpenZeppelin）

使用 `ERC721URIStorage`（可逐个 Token 设置 URI）和 `ERC721Enumerable`（方便在 OpenSea 展示合集）。

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721URIStorage, ERC721Enumerable, Ownable {
    uint256 private _nextTokenId;

    constructor() ERC721("MyNFT", "MNFT") Ownable(msg.sender) {}

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // 以下覆盖是为了 ERC721Enumerable 与 ERC721URIStorage 的兼容
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

---

## 2. 准备图片与元数据 JSON
准备图片（png/jpg），并上传至 IPFS 获得图片 CID。
[goku_normal.jpg](./goku_normal.jpg)

为每个 NFT 创建类似如下的 JSON 文件（**符合 OpenSea 元数据标准**）：

[goku_normal.json](./metadata/goku_normal.json)

> **关键点**：`image` 必须使用 `ipfs://` 协议，不能是 `https://` 网关，否则 OpenSea 可能无法正确读取。

---

## 3. 上传至去中心化存储（IPFS）


### B. Pinata（经典 IPFS 固定服务）
- 注册 [Pinata](https://pinata.cloud)
- 上传图片和 JSON 文件夹，保持文件路径
- 获得 CID 后拼接 `ipfs://<CID>/goku_normal.json`

**示例最终 URI**：`ipfs://bafkreigkzv...abc123/goku_normal.json`

---

## 4. 部署与铸造（以 Polygon 网为例）

### 部署
使用 Remix ，部署上面合约至 **Polygon**。  
部署者成为 `owner`，拥有铸造权限。

### 铸造
调用 `safeMint` 函数：
- `to`：接收 NFT 的地址（如你的钱包地址）
- `uri`：刚才上传到 IPFS 的 JSON CID，例如 `ipfs://bafkreig.../metadata1.json`

每调用一次铸造一个，Token ID 从 0 开始递增。

---

## 5. 在 OpenSea 查看（获取链接）

1. 打开 [OpenSea](https://opensea.io)
2. 点击右上角钱包图标，连接你的 MetaMask，确保网络仍是 **Polygon Mainnet**
3. 点击你的头像 → **Profile**
4. 你会看到自动生成的合集 **MyNFT (MNFT)**，以及铸造的 NFT
5. 点击某个 NFT，浏览器地址栏的链接即是 OpenSea 链接，格式：
   ```
   https://opensea.io/item/polygon/合约地址/Token_ID
   ```


---
