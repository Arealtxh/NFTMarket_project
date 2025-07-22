// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyNFT.sol";
import "./ERC20withHook.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTMarket is IERC20Callback, IERC721Receiver {
    MyNFT public nft;
    ERC20withHook public token;

    struct Listing {
        address seller;
        uint256 price;
    }

    mapping(uint256 => Listing) public listings;

    event NFTListed(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    event NFTBought(
        uint256 indexed tokenId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );

    constructor(address _nft, address _token) {
        nft = MyNFT(_nft);
        token = ERC20withHook(_token);
    }

    // 上架 NFT
    function list(uint256 tokenId, uint256 price) external {
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(
            nft.getApproved(tokenId) == address(this) ||
                nft.isApprovedForAll(msg.sender, address(this)),
            "Not approved"
        );

        listings[tokenId] = Listing({seller: msg.sender, price: price});

        emit NFTListed(tokenId, msg.sender, price);
    }

    // 普通购买 NFT 功能
    function buyNFT(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "NFT not listed");

        // 转移 Token
        require(
            token.transferFrom(msg.sender, listing.seller, listing.price),
            "Token transfer failed"
        );

        // 转移 NFT
        nft.safeTransferFrom(listing.seller, msg.sender, tokenId);

        // 清除上架信息
        delete listings[tokenId];

        emit NFTBought(tokenId, msg.sender, listing.seller, listing.price);
    }

    // 实现 ERC20 扩展的 tokensReceived 方法
    function tokensReceived(address sender, uint256 amount) external override {
        require(msg.sender == address(token), "Only accept specific token");

        // 由于原始接口没有数据参数，我们需要使用 msg.data 来获取额外信息
        // 这里假设调用者使用 transferWithCallback 并附加了 tokenId 作为数据
        // 实际应用中可能需要更复杂的数据编码/解码
        require(msg.data.length >= 32, "Missing tokenId in data");
        uint256 tokenId = abi.decode(msg.data[4:], (uint256));

        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "NFT not listed");
        require(amount >= listing.price, "Insufficient payment");

        // 如果支付金额大于定价，退还多余部分
        if (amount > listing.price) {
            require(
                token.transfer(sender, amount - listing.price),
                "Refund failed"
            );
        }

        // 转移 NFT
        nft.safeTransferFrom(listing.seller, sender, tokenId);

        // 清除上架信息
        delete listings[tokenId];

        emit NFTBought(tokenId, sender, listing.seller, listing.price);
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
}
