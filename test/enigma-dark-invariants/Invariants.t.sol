// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEulerEarn} from "src/interface/IEulerEarn.sol";

// Invariant Contracts
import {BaseInvariants} from "./invariants/BaseInvariants.t.sol";
import {ERC4626Invariants} from "./invariants/ERC4626Invariants.t.sol";

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in each invariants contract
/// @dev recognised by Echidna when property mode is activated
/// @dev Inherits BaseInvariants
abstract contract Invariants is BaseInvariants, ERC4626Invariants {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     BASE INVARIANTS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_NR_ASSETS_INVARIANTS() public returns (bool) {
        assert_NR_ASSETS_A();
        assert_NR_ASSETS_B();

        return true;
    }

    function echidna_INV_BASE_INVARIANTS() public returns (bool) {
        assert_INV_BASE_A();
        assert_INV_BASE_B();

        return true;
    }

    function echidna_INV_ASSETS_INVARIANTS() public returns (bool) {
        assert_INV_ASSETS_A(); //-> @audit-issue test_echidna_INV_ASSETS_INVARIANTS2
        assert_INV_ASSETS_D();

        uint256 sumStrategiesAllocated;
        for (uint256 i; i < strategies.length; i++) {
            IEulerEarn.Strategy memory strategy = eulerEulerEarnVault.getStrategy(strategies[i]);
            if (strategy.status == IEulerEarn.StrategyStatus.Active) {
                sumStrategiesAllocated += eulerEulerEarnVault.getStrategy(strategies[i]).allocated;
            }
        }

        assert_INV_ASSETS_B(sumStrategiesAllocated);
        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   STRATEGIES INVARIANTS                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_INV_STRATEGIES_INVARIANTS() public returns (bool) {
        uint256 sumAllocationPointsActiveStrategies;
        for (uint256 i; i < strategies.length; i++) {
            IEulerEarn.Strategy memory strategy = eulerEulerEarnVault.getStrategy(strategies[i]);
            if (strategy.status == IEulerEarn.StrategyStatus.Active) {
                sumAllocationPointsActiveStrategies += eulerEulerEarnVault.getStrategy(strategies[i]).allocationPoints;
            }
        }
        assert_INV_STRATEGIES_A(sumAllocationPointsActiveStrategies);

        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    INTEREST INVARIANTS                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_INV_INTEREST_INVARIANTS() public returns (bool) {
        assert_INV_INTEREST_A();
        assert_INV_INTEREST_B();

        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 WITHDRAW QUEUE INVARIANTS                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_INV_WITHDRAW_QUEUE_INVARIANTS() public returns (bool) {
        assert_INV_WITHDRAW_QUEUE_A();

        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    ERC4626 INVARIANTS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_ERC4626_ASSETS_INVARIANTS() public returns (bool) {
        assert_ERC4626_ASSETS_INVARIANT_A();
        assert_ERC4626_ASSETS_INVARIANT_B();
        assert_ERC4626_ASSETS_INVARIANT_C();
        assert_ERC4626_ASSETS_INVARIANT_D();

        return true;
    }

    function echidna_ERC4626_ACTIONS_INVARIANTS() public returns (bool) {
        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            // Deposit
            assert_ERC4626_DEPOSIT_INVARIANT_A(actorAddresses[i]);
            // Mint
            assert_ERC4626_MINT_INVARIANT_A(actorAddresses[i]);
            // Withdraw
            assert_ERC4626_WITHDRAW_INVARIANT_A(actorAddresses[i]);
            // Redeem
            assert_ERC4626_REDEEM_INVARIANT_A(actorAddresses[i]);
        }
        return true;
    }
}
