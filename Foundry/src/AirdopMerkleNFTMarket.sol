// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

interface ITokenReceiver {
    function tokensReceived(address from, uint256 amount, bytes calldata data) external returns (bool);
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function getApproved(uint256 tokenId) external view returns (address);
}

interface IExtendedERC20 is IERC20, IERC20Permit {
    function transferWithCallback(address _to, uint256 _value) external returns (bool);
    function transferWithCallbackAndData(address _to, uint256 _value, bytes calldata _data) external returns (bool);
}

contract AirdopMerkleNFTMarket is ITokenReceiver {
    IExtendedERC20 public immutable paymentToken;
    bytes32 public merkleRoot;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool isActive;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;
    
    // 记录已经使用白名单优惠的地址
    mapping(address => bool) public hasUsedWhitelist;

    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event NFTListingCancelled(uint256 indexed listingId);
    event WhitelistNFTClaimed(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);

    constructor(address _paymentTokenAddress, bytes32 _merkleRoot) {
        require(_paymentTokenAddress != address(0), "AirdopMerkleNFTMarket: payment token address cannot be zero");
        paymentToken = IExtendedERC20(_paymentTokenAddress);
        merkleRoot = _merkleRoot;
    }
    
    // 更新默克尔树根（仅限管理员，实际实现中应添加访问控制）
    function updateMerkleRoot(bytes32 _merkleRoot) external {
        // 在实际实现中应添加访问控制
        merkleRoot = _merkleRoot;
    }

    // 验证地址是否在白名单中
    function isWhitelisted(address user, bytes32[] calldata proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        return verifyProof(proof, leaf);
    }

    // 验证默克尔证明
    function verifyProof(bytes32[] calldata proof, bytes32 leaf) internal view returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // 检查计算出的哈希值是否与默克尔根匹配
        return computedHash == merkleRoot;
    }

    // 上架NFT（与NFT_Market.sol中的上架逻辑一致）
    function list(address _nftContract, uint256 _tokenId, uint256 _price) external returns (uint256) {
        require(_price > 0, "AirdopMerkleNFTMarket: price must be greater than zero");
        require(_nftContract != address(0), "AirdopMerkleNFTMarket: NFT contract address cannot be zero");

        IERC721 nftContract = IERC721(_nftContract);
        address owner = nftContract.ownerOf(_tokenId);
        require(
            owner == msg.sender || 
            nftContract.isApprovedForAll(owner, msg.sender) || 
            nftContract.getApproved(_tokenId) == msg.sender,
            "AirdopMerkleNFTMarket: caller is not owner nor approved"
        );

        uint256 listingId = nextListingId++;
        listings[listingId] = Listing({
            seller: owner,
            nftContract: _nftContract,
            tokenId: _tokenId,
            price: _price,
            isActive: true
        });

        emit NFTListed(listingId, owner, _nftContract, _tokenId, _price);
        return listingId;
    }

    function cancelListing(uint256 _listingId) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");
        require(listing.seller == msg.sender, "AirdopMerkleNFTMarket: caller is not the seller");

        listing.isActive = false;
        emit NFTListingCancelled(_listingId);
    }

    function buyNFT(uint256 _listingId) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "AirdopMerkleNFTMarket: insufficient token balance");

        listing.isActive = false;

        require(paymentToken.transferFrom(msg.sender, listing.seller, listing.price), "AirdopMerkleNFTMarket: token transfer failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);

        emit NFTSold(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, listing.price);
    }

    function tokensReceived(address from, uint256 amount, bytes calldata data) external override returns (bool) {
        require(msg.sender == address(paymentToken), "AirdopMerkleNFTMarket: caller is not the payment token contract");
        require(data.length == 32, "AirdopMerkleNFTMarket: invalid data length");

        uint256 listingId = abi.decode(data, (uint256));
        Listing storage listing = listings[listingId];

        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");
        require(amount == listing.price, "AirdopMerkleNFTMarket: incorrect payment amount");

        listing.isActive = false;

        require(paymentToken.transfer(listing.seller, amount), "AirdopMerkleNFTMarket: token transfer to seller failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, from, listing.tokenId);

        emit NFTSold(listingId, from, listing.seller, listing.nftContract, listing.tokenId, amount);
        return true;
    }

    // 白名单用户使用permit授权并购买NFT的multicall实现
    struct Call {
        address target;
        bytes callData;
    }

    // 使用delegateCall方式的multicall
    function multicall(Call[] memory calls) public returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = calls[i].target.delegatecall(calls[i].callData);
            require(success, "AirdopMerkleNFTMarket: delegatecall failed");
            results[i] = result;
        }
        return results;
    }

    // 调用token的permit进行授权
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        paymentToken.permit(owner, spender, value, deadline, v, r, s);
    }

    // 通过默克尔树验证白名单，并利用permitPrePay的授权，转入token转出NFT
    function claimNFT(uint256 _listingId, bytes32[] calldata merkleProof) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");
        
        // 验证用户是否在白名单中
        require(isWhitelisted(msg.sender, merkleProof), "AirdopMerkleNFTMarket: not in whitelist");
        require(!hasUsedWhitelist[msg.sender], "AirdopMerkleNFTMarket: whitelist discount already used");
        
        // 计算50%优惠后的价格
        uint256 discountedPrice = listing.price / 2;
        require(paymentToken.balanceOf(msg.sender) >= discountedPrice, "AirdopMerkleNFTMarket: insufficient token balance");

        // 标记该用户已使用白名单优惠
        hasUsedWhitelist[msg.sender] = true;
        listing.isActive = false;

        // 转移代币和NFT
        require(paymentToken.transferFrom(msg.sender, listing.seller, discountedPrice), "AirdopMerkleNFTMarket: token transfer failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);

        emit WhitelistNFTClaimed(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, discountedPrice);
    }
}