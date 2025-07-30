// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NFTMarketOptimized.sol";
import "../src/MyNFT.sol";
import "../src/MyTokenWithHook.sol";

contract NFTMarketOptimizedTest is Test {
    NFTMarketOptimized market;
    MyNFT nft;
    MyTokenWithHook token;
    
    address seller = address(0x1);
    address buyer = address(0x2);
    uint256 tokenId = 0;
    uint96 price = 100 ether;

    function setUp() public {
        // 部署合约
        nft = new MyNFT();
        token = new MyTokenWithHook(1000000 ether);
        market = new NFTMarketOptimized(address(nft), address(token));
        
        // 给seller铸造NFT
        vm.prank(address(this));
        nft.awardItem(seller, "test-uri");
        
        // 给buyer一些代币
        token.transfer(buyer, 1000 ether);
        
        // seller授权市场合约
        vm.prank(seller);
        nft.approve(address(market), tokenId);
        
        // buyer授权市场合约
        vm.prank(buyer);
        token.approve(address(market), 1000 ether);
    }

    function testListSuccess() public {
        vm.prank(seller);
        market.list(tokenId, price);
        
        (address listingSeller, uint96 listingPrice) = market.getListing(tokenId);
        assertEq(listingSeller, seller);
        assertEq(listingPrice, price);
    }

    function testListFail_NotOwner() public {
        vm.prank(buyer);
        vm.expectRevert("Not the owner");
        market.list(tokenId, price);
    }

    function testListFail_NotApproved() public {
        // 撤销授权
        vm.prank(seller);
        nft.approve(address(0), tokenId);
        
        vm.prank(seller);
        vm.expectRevert("Not approved");
        market.list(tokenId, price);
    }

    function testBuyNFTSuccess() public {
        // 先上架
        vm.prank(seller);
        market.list(tokenId, price);
        
        // 购买
        vm.prank(buyer);
        market.buyNFT(tokenId);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(tokenId), buyer);
        
        // 验证代币转移
        assertEq(token.balanceOf(seller), price);
        
        // 验证上架信息被清除
        (address listingSeller,) = market.getListing(tokenId);
        assertEq(listingSeller, address(0));
    }

    function testBuyNFTFail_NotListed() public {
        vm.prank(buyer);
        vm.expectRevert("NFT not listed");
        market.buyNFT(tokenId);
    }

    function testBuyNFTFail_InsufficientToken() public {
        // 先上架
        vm.prank(seller);
        market.list(tokenId, price);
        
        // 减少buyer的代币余额
        vm.prank(buyer);
        token.transfer(address(0x3), 950 ether);
        
        vm.prank(buyer);
        vm.expectRevert();
        market.buyNFT(tokenId);
    }

    function testBatchListSuccess() public {
        // 铸造更多NFT
        nft.awardItem(seller, "test-uri-1");
        nft.awardItem(seller, "test-uri-2");
        
        // 授权
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        nft.approve(address(market), 2);
        
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        
        uint96[] memory prices = new uint96[](3);
        prices[0] = 100 ether;
        prices[1] = 200 ether;
        prices[2] = 300 ether;
        
        market.batchList(tokenIds, prices);
        vm.stopPrank();
        
        // 验证所有NFT都已上架
        for (uint256 i = 0; i < 3; i++) {
            (address listingSeller, uint96 listingPrice) = market.getListing(i);
            assertEq(listingSeller, seller);
            assertEq(listingPrice, prices[i]);
        }
    }

    function testBatchListFail_ArrayLengthMismatch() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint96[] memory prices = new uint96[](3);
        
        vm.prank(seller);
        vm.expectRevert("Array length mismatch");
        market.batchList(tokenIds, prices);
    }

    function testCancelListing() public {
        // 先上架
        vm.prank(seller);
        market.list(tokenId, price);
        
        // 取消上架
        vm.prank(seller);
        market.cancelListing(tokenId);
        
        // 验证上架信息被清除
        (address listingSeller,) = market.getListing(tokenId);
        assertEq(listingSeller, address(0));
    }

    function testCancelListingFail_NotYourListing() public {
        // 先上架
        vm.prank(seller);
        market.list(tokenId, price);
        
        // 其他人尝试取消
        vm.prank(buyer);
        vm.expectRevert("Not your listing");
        market.cancelListing(tokenId);
    }

    function testFuzz_ListAndBuy(uint96 fuzzPrice) public {
        // 限制价格范围
        vm.assume(fuzzPrice > 0 && fuzzPrice <= 1000 ether);
        
        // 上架
        vm.prank(seller);
        market.list(tokenId, fuzzPrice);
        
        // 确保buyer有足够代币
        if (token.balanceOf(buyer) < fuzzPrice) {
            token.transfer(buyer, fuzzPrice);
        }
        
        // 购买
        vm.prank(buyer);
        market.buyNFT(tokenId);
        
        // 验证
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), fuzzPrice);
    }

    function testMarketNoTokenBalance() public {
        // 先上架
        vm.prank(seller);
        market.list(tokenId, price);
        
        // 购买
        vm.prank(buyer);
        market.buyNFT(tokenId);
        
        // 验证市场合约没有代币余额
        assertEq(token.balanceOf(address(market)), 0);
    }

    function testOnERC721Received() public {
        bytes4 selector = market.onERC721Received(address(0), address(0), 0, "");
        assertEq(selector, IERC721Receiver.onERC721Received.selector);
    }

    function testGetListing() public {
        // 测试空上架
        (address seller1, uint96 price1) = market.getListing(999);
        assertEq(seller1, address(0));
        assertEq(price1, 0);
        
        // 上架后测试
        vm.prank(seller);
        market.list(tokenId, price);
        
        (address seller2, uint96 price2) = market.getListing(tokenId);
        assertEq(seller2, seller);
        assertEq(price2, price);
    }
}