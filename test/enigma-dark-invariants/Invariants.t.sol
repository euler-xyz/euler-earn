// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC4626, IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

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

    function echidna_INV_BASE() public returns (bool) {
        for (uint256 i; i < eulerEarnVaults.length; i++) {
            address eulerEarn = eulerEarnVaults[i];
            for (uint256 j; j < allMarkets[eulerEarn].length; j++) {
                IERC4626 market = allMarkets[eulerEarn][j];
                assert_INV_BASE_A(market, eulerEarn);
                assert_INV_BASE_C(market, eulerEarn);
                assert_INV_BASE_D(market, eulerEarn);
                assert_INV_BASE_E(market, eulerEarn);
            }

            assert_INV_BASE_F(eulerEarn);
        }

        return true;
    }

    function echidna_INV_QUEUES() public returns (bool) {
        for (uint256 i; i < eulerEarnVaults.length; i++) {
            address eulerEarn = eulerEarnVaults[i];
            assert_INV_QUEUES_AE(eulerEarn);
            assert_INV_QUEUES_B(eulerEarn);
        }

        return true;
    }

    function echidna_INV_TIMELOCK() public returns (bool) {
        for (uint256 i; i < eulerEarnVaults.length; i++) {
            address eulerEarn = eulerEarnVaults[i];
            assert_INV_TIMELOCK_A(eulerEarn);
            assert_INV_TIMELOCK_D(eulerEarn);
            assert_INV_TIMELOCK_E(eulerEarn);
            assert_INV_TIMELOCK_F(eulerEarn);
        }

        return true;
    }

    function echidna_INV_MARKETS() public returns (bool) {
        for (uint256 i; i < eulerEarnVaults.length; i++) {
            address eulerEarn = eulerEarnVaults[i];
            for (uint256 j; j < allMarkets[eulerEarn].length; j++) {
                assert_INV_MARKETS_AB(allMarkets[eulerEarn][j], eulerEarn);
            }
        }

        return true;
    }

    function echidna_INV_FEES() public returns (bool) {
        for (uint256 i; i < eulerEarnVaults.length; i++) {
            assert_INV_FEES_A(eulerEarnVaults[i]);
        }

        return true;
    }

    function echidna_INV_ACCOUNTING() public returns (bool) {
        for (uint256 i; i < eulerEarnVaults.length; i++) {
            address eulerEarn = eulerEarnVaults[i];
            assert_INV_ACCOUNTING_A(eulerEarn);
            //assert_INV_ACCOUNTING_C(eulerEarn); TODO revisit this invariant
        }

        return true;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    ERC4626 INVARIANTS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function echidna_ERC4626_ASSETS_INVARIANTS() public returns (bool) {
        for (uint256 i; i < eulerEarnVaults.length; i++) {
            address eulerEarn = eulerEarnVaults[i];
            assert_ERC4626_ASSETS_INVARIANT_A(eulerEarn);
            assert_ERC4626_ASSETS_INVARIANT_B(eulerEarn);
            assert_ERC4626_ASSETS_INVARIANT_C(eulerEarn);
            assert_ERC4626_ASSETS_INVARIANT_D(eulerEarn);
        }

        return true;
    }

    function echidna_ERC4626_USERS() public returns (bool) {
        for (uint256 i; i < eulerEarnVaults.length; i++) {
            address eulerEarn = eulerEarnVaults[i];
            for (uint256 j; j < actorAddresses.length; j++) {
                assert_ERC4626_DEPOSIT_INVARIANT_A(actorAddresses[j], eulerEarn);
                assert_ERC4626_MINT_INVARIANT_A(actorAddresses[j], eulerEarn);
                assert_ERC4626_WITHDRAW_INVARIANT_A(actorAddresses[j], eulerEarn);
                assert_ERC4626_REDEEM_INVARIANT_A(actorAddresses[j], eulerEarn);
            }
        }

        return true;
    }
}
