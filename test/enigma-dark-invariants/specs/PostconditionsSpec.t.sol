// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title PostconditionsSpec
/// @notice Postcoditions specification for the protocol
/// @dev Contains pseudo code and description for the postcondition properties in the protocol
abstract contract PostconditionsSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    
    /// - POSTCONDITIONS:
    ///   - Properties that should hold true after an action is executed.
    ///   - Implemented in the /hooks and /handlers folders.
    ///   - There are two types of POSTCONDITIONS:
    ///     - GLOBAL POSTCONDITIONS (GPOST): 
    ///       - Properties that should always hold true after any action is executed.
    ///       - Checked in the `_checkPostConditions` function within the HookAggregator contract.
    ///     - HANDLER-SPECIFIC POSTCONDITIONS (HSPOST): 
    ///       - Properties that should hold true after a specific action is executed in a specific context.
    ///       - Implemented within each handler function, under the HANDLER-SPECIFIC POSTCONDITIONS section.
    
    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant GPOST_BASE_A = "GPOST_BASE_A: lastHarvestTimestamp increases monotonically";

    string constant GPOST_BASE_B =
        "GPOST_BASE_B: if lastHarvestTimestamp is updated either `harvest`, `rebalance`, `withdraw` or `redeem` have been called";

    string constant GPOST_BASE_C =
        "GPOST_BASE_C: Exchange rate should never decrease unless a loss is reported by harvest";

    string constant GPOST_BASE_D =
        "GPOST_BASE_D: new shares should only be minted when there is a corresponding increase in assets"; // TODO

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        INTEREST                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant GPOST_INTEREST_A =
        "GPOST_INTEREST_A: lastInterestUpdate should only be updated if (totalSupplyBefore != 0 && interestLeftBefore != 0) || toGulpBefore != 0)";

    string constant GPOST_INTEREST_B = "GPOST_INTEREST_B: lastInterestUpdate increases monotonically";

    string constant GPOST_INTEREST_D =
        "GPOST_INTEREST_D: if vault is smearing => the amount added to the vault's assets each block should correspond to this distribution"; // TODO

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          USER                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant HSPOST_USER_A =
        "HSPOST_USER_A: After a deposit or mint, the amount should be credited to the cash reserve";

    string constant HSPOST_USER_B =
        "HSPOST_USER_B: After a withdraw or redeem, if cash reserve > amount, the amount should be withdrawn from the cash reserve";

    string constant HSPOST_USER_C =
        "HSPOST_USER_C: After a withdraw or redeem, if cash reserve < amount, the difference should be withdrawn from the strategies";

    string constant HSPOST_USER_D =
        "HSPOST_USER_D: After a deposit or mint, the totalAssets should increase by the amount deposited";

    string constant HSPOST_USER_E =
        "HSPOST_USER_E: After a withdraw or redeem, the totalAssets should decrease by the amount withdrawn";

    string constant HSPOST_USER_F =
        "HSPOST_USER_F: After a deposit or mint, the balance of the protocol should increase by the amount deposited";

    string constant HSPOST_USER_G =
        "HSPOST_USER_G: After a deposit or mint, the totalAssetsDeposited of the protocol should increase by the amount deposited";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STRATEGIES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant GPOST_STRATEGIES_A =
        "HSPOST_STRATEGIES_A: A strategy under Emergency mode must not receive any new allocations";

    string constant HSPOST_STRATEGIES_B =
        "HSPOST_STRATEGIES_B: After a rebalance assets are distributed across strategies according to their assigned allocation points"; // TODO

    string constant HSPOST_STRATEGIES_C =
        "HSPOST_STRATEGIES_C: After a harvest, if loss < interestLeft => totalAssets does not decrease"; // TODO

    string constant HSPOST_STRATEGIES_D =
        "HSPOST_STRATEGIES_D: After a harvest, if loss > interestLeft => totalAssets decreases by the loss - interestLeft"; // TODO

    string constant HSPOST_STRATEGIES_E = "HSPOST_STRATEGIES_E: Performance fee only applied on positive Yield"; // TODO

    string constant HSPOST_STRATEGIES_F =
        "HSPOST_STRATEGIES_F: Performance fee should be transferred to the feeRecipient"; // TODO

    string constant HSPOST_STRATEGIES_G =
        "HSPOST_STRATEGIES_G: After claiming underlying rewards, they are correctly distributed";

    string constant GPOST_STRATEGIES_H = "GPOST_STRATEGIES_H: allocated < allocated' => allocated < strategy.cap";
}
