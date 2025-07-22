// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MyTokenWithHook} from "../src/MyTokenWithHook.sol";

contract MyTokenWithHookScript is Script {
    MyTokenWithHook public myTokenWithHook;

    function setUp() public {}

    function run() public {
        uint256 initialSupply = 1_000_000 ether; // 可根据需要修改初始发行量
        vm.startBroadcast();

        myTokenWithHook = new MyTokenWithHook(initialSupply);

        vm.stopBroadcast();
    }
}
