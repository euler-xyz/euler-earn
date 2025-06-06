// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "../interfaces/IAllowanceTransfer.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title SafeERC20Permit2Lib Library
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice The library provides a helper for ERC20 transferFrom with use of Permit2
library SafeERC20Permit2Lib {
    function forceApproveWithPermit2(IERC20 token, address spender, uint256 value, address permit2) internal {
        if (permit2 != address(0) && value <= type(uint160).max) {
            // it's safe to down-cast value to uint160
            IAllowanceTransfer(permit2).approve(address(token), spender, uint160(value), 0);
        } else {
            SafeERC20.forceApprove(token, spender, value);
        }
    }

    function safeTransferFromWithPermit2(IERC20 token, address from, address to, uint256 value, address permit2)
        internal
    {
        uint160 permit2Amount;
        uint48 permit2Expiration;

        if (permit2 != address(0)) {
            (permit2Amount, permit2Expiration,) =
                IAllowanceTransfer(permit2).allowance(from, address(token), address(this));
        }

        if (permit2Amount >= value && permit2Expiration >= block.timestamp) {
            // it's safe to down-cast value to uint160
            IAllowanceTransfer(permit2).transferFrom(from, to, uint160(value), address(token));
        } else {
            SafeERC20.safeTransferFrom(token, from, to, value);
        }
    }
}
