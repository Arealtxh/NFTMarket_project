// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title BigNFTMarket 多币种多NFT市场
/// @notice 支持任意ERC721和任意ERC20定价上架NFT和用ERC20购买NFT
contract BigNFTMarket {
    /// @dev 上架信息结构体
    struct Listing {
        address seller; // 卖家地址
        address erc20; // 支付用的ERC20合约地址
        uint256 price; // NFT价格
    }

    /// @dev NFT合约地址 => tokenId => 上架信息
    mapping(address => mapping(uint256 => Listing)) public listings;

    /// @dev 上架事件
    event NFTListed(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed seller,
        address erc20,
        uint256 price
    );
    /// @dev 购买事件
    event NFTBought(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        address erc20,
        uint256 price
    );

    /// @notice 上架NFT到市场
    /// @param nft NFT合约地址
    /// @param tokenId NFT的tokenId
    /// @param erc20 支付用的ERC20合约地址
    /// @param price NFT价格
    function list(
        address nft,
        uint256 tokenId,
        address erc20,
        uint256 price
    ) external {
        IERC721 nftContract = IERC721(nft);
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(
            nftContract.getApproved(tokenId) == address(this) ||
                nftContract.isApprovedForAll(msg.sender, address(this)),
            "Not approved"
        );
        listings[nft][tokenId] = Listing(msg.sender, erc20, price);
        emit NFTListed(nft, tokenId, msg.sender, erc20, price);
    }

    /// @notice 购买指定NFT
    /// @param nft NFT合约地址
    /// @param tokenId NFT的tokenId
    function buy(address nft, uint256 tokenId) external {
        Listing memory listing = listings[nft][tokenId];
        require(listing.seller != address(0), "NFT not listed");
        require(listing.seller != msg.sender, "Cannot buy your own NFT");

        IERC20 token = IERC20(listing.erc20);
        require(
            token.transferFrom(msg.sender, listing.seller, listing.price),
            "Token transfer failed"
        );

        IERC721(nft).safeTransferFrom(listing.seller, msg.sender, tokenId);

        delete listings[nft][tokenId];
        emit NFTBought(
            nft,
            tokenId,
            msg.sender,
            listing.seller,
            listing.erc20,
            listing.price
        );
    }
}
