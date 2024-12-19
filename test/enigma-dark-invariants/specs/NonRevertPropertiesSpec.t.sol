// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title NonRevertPropertiesSpec
/// @notice Properties specification for the protocol
/// @dev Contains pseudo code and description for the invariant properties in the protocol
abstract contract NonRevertPropertiesSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - NON REVERT (NR): 
    ///   - Properties that assert a specific function should never revert, or only revert under 
    ///   certain defined conditions.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // EulerEarnVaultModuleHandler.sol
    string constant NR_BASE_A = "NR_BASE_A: updateInterestAccrued should not revert";

    // EulerEarnVaultModuleHandler.sol
    string constant NR_BASE_B = "NR_BASE_B: harvest should not revert";

    // EulerEarnVaultModuleHandler.sol
    string constant NR_BASE_C = "NR_BASE_C: rebalance should not revert";

    // EulerEarnVaultModuleHandler.sol
    string constant NR_BASE_D = "NR_BASE_D: gulp should not revert";

    // StrategyModuleModuleHandler.sol
    string constant NR_BASE_E = "NR_BASE_E: toggleStrategyEmergencyStatus for an active strategy should not revert";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ASSETS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant NR_ASSETS_A = "NR_ASSETS_A: totalAssetsAllocatable should not revert";

    string constant NR_ASSETS_B = "NR_ASSETS_B: totalAssets should not revert";
}
