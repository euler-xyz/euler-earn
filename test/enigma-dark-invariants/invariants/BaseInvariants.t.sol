// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {ConstantsLib as Constants} from "src/lib/ConstantsLib.sol";

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Contracts
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

import "forge-std/console.sol";

/// @title BaseInvariants
/// @notice Implements Invariants for the protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract BaseInvariants is HandlerAggregator {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_BASE_A() internal {
        (, uint256 performanceFee) = eulerEulerEarnVault.performanceFeeConfig();
        assertLe(performanceFee, Constants.MAX_PERFORMANCE_FEE, INV_BASE_A);
    }

    function assert_INV_BASE_B() internal {
        uint256 sumActorBalances;
        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            sumActorBalances += eulerEulerEarnVault.balanceOf(actorAddresses[i]);
        }
        assertEq(
            eulerEulerEarnVault.totalSupply(),
            sumActorBalances + eulerEulerEarnVault.balanceOf(feeRecipient),
            INV_BASE_B
        );
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        ASSETS                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_ASSETS_A() internal {
        (,, uint168 interestLeft) = eulerEulerEarnVault.getEulerEarnSavingRate();

        uint256 totalAssetsDeposited = eulerEulerEarnVault.totalAssetsDeposited();

        if (eulerEulerEarnVault.totalAssetsAllocatable() - totalAssetsDeposited - interestLeft == 0) {
            assertGe(totalAssetsDeposited + interestLeft, eulerEulerEarnVault.totalAllocated(), INV_ASSETS_A);
        }
    }

    function assert_INV_ASSETS_B(uint256 sumStrategiesAllocated) internal {
        assertEq(eulerEulerEarnVault.totalAllocated(), sumStrategiesAllocated, INV_ASSETS_B);
    }

    function assert_INV_ASSETS_D() internal {
        assertGe(eulerEulerEarnVault.totalAssetsAllocatable(), eulerEulerEarnVault.totalAssets(), INV_ASSETS_D);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       STRATEGIES                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_STRATEGIES_A(uint256 sumStrategyAllocatedPoints) internal {
        assertGe(
            eulerEulerEarnVault.totalAllocationPoints(),
            sumStrategyAllocatedPoints + eulerEulerEarnVault.getStrategy(address(0)).allocationPoints,
            INV_STRATEGIES_A
        );
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        INTEREST                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_INTEREST_A() internal {
        (, uint40 interestSmearEnd,) = eulerEulerEarnVault.getEulerEarnSavingRate();
        assertLe(interestSmearEnd, block.timestamp + INTEREST_SMEAR, INV_INTEREST_A);
    }

    function assert_INV_INTEREST_B() internal {
        (,, uint168 interestLeft) = eulerEulerEarnVault.getEulerEarnSavingRate();
        assertGe(
            eulerEulerEarnVault.totalAssetsAllocatable(),
            eulerEulerEarnVault.totalAssetsDeposited() + interestLeft,
            INV_INTEREST_B
        );
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     WITHDRAW QUEUE                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_INV_WITHDRAW_QUEUE_A() internal {
        address[] memory withdrawalQueue = eulerEulerEarnVault.withdrawalQueue();

        for (uint256 i; i < withdrawalQueue.length; i++) {
            assertGt(uint256(eulerEulerEarnVault.getStrategy(withdrawalQueue[i]).status), 0, INV_WITHDRAW_QUEUE_A);
        }

        for (uint256 i; i < strategies.length; i++) {
            if (uint256(eulerEulerEarnVault.getStrategy(strategies[i]).status) > 0) {
                bool found;
                for (uint256 j; j < withdrawalQueue.length; j++) {
                    if (withdrawalQueue[j] == strategies[i]) {
                        found = true;
                        break;
                    }
                }
                assertTrue(found, INV_WITHDRAW_QUEUE_A);
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          VIEWS                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_NR_ASSETS_A() internal {
        try eulerEulerEarnVault.totalAssetsAllocatable() {}
        catch {
            fail(NR_ASSETS_A);
        }
    }

    function assert_NR_ASSETS_B() internal {
        try eulerEulerEarnVault.totalAssets() {}
        catch {
            fail(NR_ASSETS_B);
        }
    }
}
