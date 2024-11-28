// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title ERC20Handler
/// @notice Handler test contract for a set of actions
contract ERC20Handler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function approveTo(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address spender = _getRandomActor(i);

        address target = address(eulerEulerEarnVault);

        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(IERC20.approve.selector, spender, amount));

        if (success) {
            assert(true);
        }
    }

    function transferTo(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address to = _getRandomActor(i);

        address target = address(eulerEulerEarnVault);

        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(IERC20.transfer.selector, to, amount));

        if (success) {
            ghost_sumSharesBalancesPerUser[address(actor)] -= amount;
            ghost_sumSharesBalancesPerUser[to] += amount;
        }
    }

    function transferFromTo(uint256 amount, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address from = _getRandomActor(i);
        // Get one of the three actors randomly
        address to = _getRandomActor(j);

        address target = address(eulerEulerEarnVault);

        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));

        if (success) {
            ghost_sumSharesBalancesPerUser[from] -= amount;
            ghost_sumSharesBalancesPerUser[to] += amount;
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
