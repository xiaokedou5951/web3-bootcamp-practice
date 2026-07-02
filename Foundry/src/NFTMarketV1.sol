// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./Interfaces.sol";

contract NFTMarketV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable, ITokenReceiver {
    IExtendedERC20 public paymentToken;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool isActive;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;

    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event NFTListingCancelled(uint256 indexed listingId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _paymentTokenAddress) public initializer {
        require(_paymentTokenAddress != address(0), "NFTMarket: payment token address cannot be zero");
        paymentToken = IExtendedERC20(_paymentTokenAddress);
        __Ownable_init_unchained(msg.sender);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function list(address _nftContract, uint256 _tokenId, uint256 _price) external returns (uint256) {
        require(_price > 0, "NFTMarket: price must be greater than zero");
        require(_nftContract != address(0), "NFTMarket: NFT contract address cannot be zero");

        IERC721 nftContract = IERC721(_nftContract);
        address owner = nftContract.ownerOf(_tokenId);
        require(
            owner == msg.sender || 
            nftContract.isApprovedForAll(owner, msg.sender) || 
            nftContract.getApproved(_tokenId) == msg.sender,
            "NFTMarket: caller is not owner nor approved"
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
        require(listing.isActive, "NFTMarket: listing is not active");
        require(listing.seller == msg.sender, "NFTMarket: caller is not the seller");

        listing.isActive = false;
        emit NFTListingCancelled(_listingId);
    }

    function buyNFT(uint256 _listingId) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "NFTMarket: listing is not active");
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "NFTMarket: insufficient token balance");

        listing.isActive = false;

        require(paymentToken.transferFrom(msg.sender, listing.seller, listing.price), "NFTMarket: token transfer failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);

        emit NFTSold(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, listing.price);
    }

    function tokensReceived(address from, uint256 amount, bytes calldata data) external override returns (bool) {
        require(msg.sender == address(paymentToken), "NFTMarket: caller is not the payment token contract");
        require(data.length == 32, "NFTMarket: invalid data length");

        uint256 listingId = abi.decode(data, (uint256));
        Listing storage listing = listings[listingId];

        require(listing.isActive, "NFTMarket: listing is not active");
        require(amount == listing.price, "NFTMarket: incorrect payment amount");

        listing.isActive = false;

        require(paymentToken.transfer(listing.seller, amount), "NFTMarket: token transfer to seller failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, from, listing.tokenId);

        emit NFTSold(listingId, from, listing.seller, listing.nftContract, listing.tokenId, amount);
        return true;
    }

    function buyNFTWithCallback(uint256 _listingId) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "NFTMarket: listing is not active");
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "NFTMarket: insufficient token balance");

        bytes memory data = abi.encode(_listingId);
        require(paymentToken.transferWithCallbackAndData(address(this), listing.price, data), "NFTMarket: token transfer with callback failed");
    }
} 