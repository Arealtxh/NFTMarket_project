// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract ERC20withHook is ERC20 {
    function transferWithCallback(
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        bool success = transfer(to, amount);
        if (isContract(to)) {
            try IERC20Callback(to).tokensReceived(msg.sender, amount) {
                // 回调成功
            } catch {
                // 回调失败不影响转账
            }
        }
        return success;
    }

    function isContract(address account) internal view returns (bool) {
        return (account.code.length > 0);
    }
}

interface IERC20Callback {
    function tokensReceived(address sender, uint256 amount) external;
}
