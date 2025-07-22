// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {MyTokenWithHook} from "../src/MyTokenWithHook.sol";

contract NFTMarketScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 先部署依赖合约
        MyNFT nft = new MyNFT();
        MyTokenWithHook token = new MyTokenWithHook(1_000_000 ether);

        // 部署NFTMarket，并传入上面两个合约的地址
        NFTMarket market = new NFTMarket(address(nft), address(token));

        vm.stopBroadcast();

        // 可选：打印合约地址
        console.log("MyNFT:", address(nft));
        console.log("MyTokenWithHook:", address(token));
        console.log("NFTMarket:", address(market));
    }
}
