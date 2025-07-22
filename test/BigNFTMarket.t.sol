// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BigNFTMarket.sol";
import "../src/MyNFT.sol";
import "../src/MyTokenWithHook.sol";

contract BigNFTMarketTest is Test {
    BigNFTMarket public market;
    MyNFT public nft;
    MyTokenWithHook public token;
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public carol = address(0x3);

    function setUp() public {
        market = new BigNFTMarket();
        nft = new MyNFT();
        token = new MyTokenWithHook(1_000_000 ether);
        // 给alice和bob分配token
        token.transfer(alice, 10000 ether);
        token.transfer(bob, 10000 ether);
    }

    function testListSuccess() public {
        vm.startPrank(alice);
        uint256 tokenId = nft.awardItem(alice, "uri");
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, address(token), 100 ether);
        (address seller, address erc20, uint256 price) = market.listings(
            address(nft),
            tokenId
        );
        assertEq(seller, alice);
        assertEq(erc20, address(token));
        assertEq(price, 100 ether);
        vm.stopPrank();
    }

    function testListFail_NotOwner() public {
        uint256 tokenId = nft.awardItem(alice, "uri");
        vm.startPrank(bob);
        vm.expectRevert("Not the owner");
        market.list(address(nft), tokenId, address(token), 100 ether);
        vm.stopPrank();
    }

    function testListFail_NotApproved() public {
        vm.startPrank(alice);
        uint256 tokenId = nft.awardItem(alice, "uri");
        // 未授权
        vm.expectRevert("Not approved");
        market.list(address(nft), tokenId, address(token), 100 ether);
        vm.stopPrank();
    }

    function testBuySuccess() public {
        vm.startPrank(alice);
        uint256 tokenId = nft.awardItem(alice, "uri");
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, address(token), 100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(market), 100 ether);
        market.buy(address(nft), tokenId);
        assertEq(nft.ownerOf(tokenId), bob);
        vm.stopPrank();
    }

    function testBuyFail_SelfBuy() public {
        vm.startPrank(alice);
        uint256 tokenId = nft.awardItem(alice, "uri");
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, address(token), 100 ether);
        token.approve(address(market), 100 ether);
        vm.expectRevert("Cannot buy your own NFT");
        market.buy(address(nft), tokenId);
        vm.stopPrank();
    }

    function testBuyFail_NotListed() public {
        vm.startPrank(bob);
        vm.expectRevert("NFT not listed");
        market.buy(address(nft), 1);
        vm.stopPrank();
    }

    function testBuyFail_InsufficientToken() public {
        vm.startPrank(alice);
        uint256 tokenId = nft.awardItem(alice, "uri");
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, address(token), 10000 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(market), 10000 ether);
        // bob只有10000，买10000，成功
        market.buy(address(nft), tokenId);
        // 再上架一个更贵的
        uint256 tokenId2 = nft.awardItem(alice, "uri2");
        vm.stopPrank();
        vm.startPrank(alice);
        nft.approve(address(market), tokenId2);
        market.list(address(nft), tokenId2, address(token), 20000 ether);
        vm.stopPrank();
        vm.startPrank(bob);
        token.approve(address(market), 20000 ether);
        vm.expectRevert();
        market.buy(address(nft), tokenId2);
        vm.stopPrank();
    }

    function testBuyFail_RepeatBuy() public {
        vm.startPrank(alice);
        uint256 tokenId = nft.awardItem(alice, "uri");
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, address(token), 100 ether);
        vm.stopPrank();
        vm.startPrank(bob);
        token.approve(address(market), 100 ether);
        market.buy(address(nft), tokenId);
        // 再买一次
        vm.expectRevert("NFT not listed");
        market.buy(address(nft), tokenId);
        vm.stopPrank();
    }

    function testFuzz_ListAndBuy(uint96 price, address buyer) public {
        price = uint96(bound(price, 1e16, 1e22)); // 0.01~10000 ether
        vm.assume(buyer != address(0) && buyer != alice);
        vm.assume(buyer.code.length == 0);
        vm.deal(buyer, 1 ether); // 给buyer一些ETH用于gas
        token.transfer(buyer, price);
        vm.startPrank(alice);
        uint256 tokenId = nft.awardItem(alice, "uri");
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, address(token), price);
        vm.stopPrank();
        vm.startPrank(buyer);
        token.approve(address(market), price);
        market.buy(address(nft), tokenId);
        assertEq(nft.ownerOf(tokenId), buyer);
        vm.stopPrank();
    }

    // 可选：不可变性测试，检查市场合约是否持有Token
    function testMarketNoTokenBalance() public {
        vm.startPrank(alice);
        uint256 tokenId = nft.awardItem(alice, "uri");
        nft.approve(address(market), tokenId);
        market.list(address(nft), tokenId, address(token), 100 ether);
        vm.stopPrank();
        vm.startPrank(bob);
        token.approve(address(market), 100 ether);
        market.buy(address(nft), tokenId);
        vm.stopPrank();
        assertEq(token.balanceOf(address(market)), 0);
    }
}
