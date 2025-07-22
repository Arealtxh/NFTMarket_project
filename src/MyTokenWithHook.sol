// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20withHook.sol";

contract MyTokenWithHook is ERC20withHook {
    constructor(uint256 initialSupply) ERC20("MyTokenWithHook", "MTH") {
        _mint(msg.sender, initialSupply);
    }

    // 重写标准 transfer 方法以包含回调功能
    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        bool success = super.transfer(to, amount);
        if (isContract(to)) {
            try IERC20Callback(to).tokensReceived(msg.sender, amount) {
                // 回调成功
            } catch {
                // 回调失败不影响转账
            }
        }
        return success;
    }
}
