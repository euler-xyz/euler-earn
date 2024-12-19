// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {TestERC20} from "../../utils/mocks/TestERC20.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title NegativeYieldHandler
/// @notice Handler test contract for a set of actions
contract NegativeYieldHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice This function transfers any amount of assets to a contract in the system simulating
    /// a big range of donation attacks
    function forceLooseAssets(uint256 amount, uint8 i) external {
        address strategy = _getRandomStrategy(i);

        vm.prank(address(eulerEulerEarnVault));
        IERC20(strategy).transfer(address(0), amount);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
