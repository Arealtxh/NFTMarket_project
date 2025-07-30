// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyNFT.sol";
import "./ERC20withHook.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTMarketOptimized is IERC20Callback, IERC721Receiver {
    MyNFT public immutable nft;
    ERC20withHook public immutable token;

    // 优化：使用packed struct减少存储槽使用
    // 将address(20字节)和uint96(12字节)打包到一个32字节槽中
    struct Listing {
        address seller;  // 20 bytes
        uint96 price;    // 12 bytes - 支持最大79,228,162,514 ETH，足够使用
    }

    mapping(uint256 => Listing) public listings;

    // 优化：减少事件参数，使用indexed提高查询效率
    event NFTListed(
        uint256 indexed tokenId,
        address indexed seller,
        uint96 price
    );
    event NFTBought(
        uint256 indexed tokenId,
        address indexed buyer,
        uint96 price
    );

    constructor(address _nft, address _token) {
        nft = MyNFT(_nft);
        token = ERC20withHook(_token);
    }

    // 优化：减少外部调用，合并权限检查
    function list(uint256 tokenId, uint96 price) external {
        // 优化：一次调用获取所有者，避免重复调用
        address owner = nft.ownerOf(tokenId);
        require(owner == msg.sender, "Not the owner");
        
        // 优化：合并授权检查，减少外部调用
        require(
            nft.getApproved(tokenId) == address(this) ||
                nft.isApprovedForAll(msg.sender, address(this)),
            "Not approved"
        );

        // 优化：直接赋值而不是使用struct构造器
        listings[tokenId].seller = msg.sender;
        listings[tokenId].price = price;

        emit NFTListed(tokenId, msg.sender, price);
    }

    // 优化：减少存储读取，使用局部变量缓存
    function buyNFT(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        address seller = listing.seller;
        uint96 price = listing.price;
        
        require(seller != address(0), "NFT not listed");

        // 优化：先清除存储，节省gas（避免从非零到非零的写入）
        delete listings[tokenId];

        // 转移 Token
        require(
            token.transferFrom(msg.sender, seller, price),
            "Token transfer failed"
        );

        // 转移 NFT
        nft.safeTransferFrom(seller, msg.sender, tokenId);

        emit NFTBought(tokenId, msg.sender, price);
    }

    // 优化：简化tokensReceived逻辑
    function tokensReceived(address sender, uint256 amount) external override {
        require(msg.sender == address(token), "Only accept specific token");
        require(msg.data.length >= 32, "Missing tokenId in data");
        
        uint256 tokenId = abi.decode(msg.data[4:], (uint256));
        Listing storage listing = listings[tokenId];
        address seller = listing.seller;
        uint96 price = listing.price;
        
        require(seller != address(0), "NFT not listed");
        require(amount >= price, "Insufficient payment");

        // 优化：先清除存储
        delete listings[tokenId];

        // 优化：只在需要时进行退款
        unchecked {
            if (amount > price) {
                require(
                    token.transfer(sender, amount - price),
                    "Refund failed"
                );
            }
        }

        // 转移 NFT
        nft.safeTransferFrom(seller, sender, tokenId);

        emit NFTBought(tokenId, sender, price);
    }

    // 实现 ERC721 接收方法
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // 优化：添加批量上架功能
    function batchList(uint256[] calldata tokenIds, uint96[] calldata prices) external {
        require(tokenIds.length == prices.length, "Array length mismatch");
        
        uint256 length = tokenIds.length;
        for (uint256 i = 0; i < length;) {
            uint256 tokenId = tokenIds[i];
            uint96 price = prices[i];
            
            // 检查所有权和授权
            require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
            require(
                nft.getApproved(tokenId) == address(this) ||
                    nft.isApprovedForAll(msg.sender, address(this)),
                "Not approved"
            );

            listings[tokenId].seller = msg.sender;
            listings[tokenId].price = price;

            emit NFTListed(tokenId, msg.sender, price);
            
            unchecked {
                ++i;
            }
        }
    }

    // 优化：添加取消上架功能
    function cancelListing(uint256 tokenId) external {
        require(listings[tokenId].seller == msg.sender, "Not your listing");
        delete listings[tokenId];
    }

    // 优化：添加查询函数，避免重复的存储读取
    function getListing(uint256 tokenId) external view returns (address seller, uint96 price) {
        Listing storage listing = listings[tokenId];
        return (listing.seller, listing.price);
    }
}