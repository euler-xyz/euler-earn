// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title InvariantsSpec
/// @notice Invariants specification for the protocol
/// @dev Contains pseudo code and description for the invariant properties in the protocol
abstract contract InvariantsSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - INVARIANTS (INV): 
    ///   - Properties that should always hold true in the system. 
    ///   - Implemented in the /invariants folder.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         BASE                                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_BASE_A = "INV_BASE_A: performanceFee should be between bounds";

    string constant INV_BASE_B = "INV_BASE_B: totalSupply == sum[actors](actorBalance) + feeRecipientBalance";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        ASSETS                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_ASSETS_A = "INV_ASSETS_A: totalAssetsDeposited + interestLeft >= totalAllocated";

    string constant INV_ASSETS_B = "INV_ASSETS_B: totalAllocated == sum[active_strategies](allocated)";

    string constant INV_ASSETS_C = "INV_ASSETS_C: balanceOf(vault) >= cashReserve"; // TODO change

    string constant INV_ASSETS_D = "INV_ASSETS_D: totalAssetsAllocatable >= totalAssets";

    string constant INV_ASSETS_E = "INV_ASSETS_E: totalAssets >= sum[active_strategies](allocated)";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       STRATEGIES                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_STRATEGIES_A =
        "INV_STRATEGIES_A: totalAllocationPoints == sum[strategies](strategyAllocationPoints)";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        INTEREST                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_INTEREST_A = "INV_INTEREST_A: interestSmearEnd <=  block.timestamp + INTEREST_SMEAR";

    string constant INV_INTEREST_B = "INV_INTEREST_B: totalAssetsAllocatable >= totalAssetsdeposited + interestLeft";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     WITHDRAW QUEUE                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_WITHDRAW_QUEUE_A =
        "INV_WITHDRAW_QUEUE_A: strategy in withdrawalQueue <=> strategy in the protocol";
}
