// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {Strings} from "../utils/Pretty.sol";
import {AmountCap, AmountCapLib} from "src/lib/AmountCapLib.sol";
import "forge-std/console.sol";

// Test Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEulerEarn} from "src/interface/IEulerEarn.sol";
import {IEulerEarnVaultModuleHandler} from "../handlers/interfaces/IEulerEarnVaultModuleHandler.sol";
import {IERC4626Handler} from "../handlers/interfaces/IERC4626Handler.sol";

/// @title Default Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract DefaultBeforeAfterHooks is BaseHooks {
    using Strings for string;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         STRUCTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    struct Strategy {
        uint120 allocated;
        uint96 allocationPoints;
        AmountCap cap;
        IEulerEarn.StrategyStatus status;
        uint256 eulerEarnStrategyBalance;
    }

    struct DefaultVars {
        // Vault Accounting
        uint256 totalSupply;
        uint256 totalAssets;
        uint256 totalAssetsAllocatable;
        uint256 totalAssetsDeposited;
        uint256 totalAllocated;
        // External Accounting
        uint256 balance;
        uint256 exchangeRate;
        uint256 toGulp;
        // Interest
        uint256 lastHarvestTimestamp;
        uint40 lastInterestUpdate;
        uint40 interestSmearingEnd;
        uint168 interestLeft;
        uint256 interestAccrued;
        // Strategies data
        mapping(address => Strategy) strategies;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HOOKS STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    DefaultVars defaultVarsBefore;
    DefaultVars defaultVarsAfter;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETUP                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Default hooks setup
    function _setUpDefaultHooks() internal {}

    /// @notice Helper to initialize storage arrays of default vars
    function _setUpDefaultVars(DefaultVars storage _dafaultVars) internal {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HOOKS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _defaultHooksBefore() internal {
        // Default values
        _setVaultValues(defaultVarsBefore);
        // Strategies data
        _setStrategiesData(defaultVarsBefore);
        // Health & user account data
        _setUserValues(defaultVarsBefore);
    }

    function _defaultHooksAfter() internal {
        // Default values
        _setVaultValues(defaultVarsAfter);
        // Strategies data
        _setStrategiesData(defaultVarsAfter);
        // Health & user account data
        _setUserValues(defaultVarsAfter);
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HELPERS                                             //
    /////////////////////////////////////////////////////////////////////////////////////////////*/

    function _setVaultValues(DefaultVars storage _defaultVars) internal {
        (uint40 lastInterestUpdate, uint40 interestSmearingEnd, uint168 interestLeft) =
            eulerEulerEarnVault.getEulerEarnSavingRate();

        // Vault Accounting
        _defaultVars.totalSupply = eulerEulerEarnVault.totalSupply();
        _defaultVars.totalAssets = eulerEulerEarnVault.totalAssets();
        _defaultVars.totalAssetsAllocatable = eulerEulerEarnVault.totalAssetsAllocatable();
        _defaultVars.totalAssetsDeposited = eulerEulerEarnVault.totalAssetsDeposited();
        _defaultVars.totalAllocated = eulerEulerEarnVault.totalAllocated();

        // External Accounting
        _defaultVars.balance = assetTST.balanceOf(address(eulerEulerEarnVault));
        _defaultVars.exchangeRate =
            (_defaultVars.totalSupply != 0) ? _defaultVars.totalAssets / _defaultVars.totalSupply : 0;
        _defaultVars.toGulp = _defaultVars.totalAssetsAllocatable - _defaultVars.totalAssetsDeposited - interestLeft;

        // Interest
        _defaultVars.lastHarvestTimestamp = eulerEulerEarnVault.lastHarvestTimestamp();
        _defaultVars.lastInterestUpdate = lastInterestUpdate;
        _defaultVars.interestSmearingEnd = interestSmearingEnd;
        _defaultVars.interestLeft = interestLeft;
        _defaultVars.interestAccrued = eulerEulerEarnVault.interestAccrued();
        //TODO add underlying balance tracker
    }

    function _setStrategiesData(DefaultVars storage _defaultVars) internal {
        for (uint256 i; i < strategies.length; i++) {
            IEulerEarn.Strategy memory strategy = eulerEulerEarnVault.getStrategy(strategies[i]);

            _defaultVars.strategies[strategies[i]] = Strategy({
                allocated: strategy.allocated,
                allocationPoints: strategy.allocationPoints,
                cap: strategy.cap,
                status: strategy.status,
                eulerEarnStrategyBalance: IERC20(strategies[i]).balanceOf(address(eulerEulerEarnVault))
            });
        }
    }

    function _setUserValues(DefaultVars storage _defaultVars) internal {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POST CONDITIONS: BASE                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_GPOST_BASE_A() internal {
        assertGe(defaultVarsAfter.lastHarvestTimestamp, defaultVarsBefore.lastHarvestTimestamp, GPOST_BASE_A);
    }

    function assert_GPOST_BASE_B() internal {
        if (defaultVarsAfter.lastHarvestTimestamp > defaultVarsBefore.lastHarvestTimestamp) {
            if (defaultVarsAfter.lastHarvestTimestamp == block.timestamp) {
                assertTrue(
                    msg.sig == IEulerEarnVaultModuleHandler.harvest.selector
                        || msg.sig == IERC4626Handler.redeem.selector || msg.sig == IERC4626Handler.withdraw.selector
                        || msg.sig == IEulerEarnVaultModuleHandler.rebalance.selector,
                    GPOST_BASE_B
                );
            }
        }
    }

    function assert_GPOST_BASE_C() internal {
        if (defaultVarsAfter.exchangeRate < defaultVarsBefore.exchangeRate) {
            // TODO add loss check
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POST CONDITIONS: INTEREST                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_GPOST_INTEREST_A() internal {
        if (_hasLastInterestUpdated()) {
            console.log("totalSupply", defaultVarsBefore.totalSupply);
            console.log("interestLeft", defaultVarsBefore.interestLeft);
            console.log("toGulp", defaultVarsBefore.toGulp);
            console.log("_totalAssetsAllocatable", defaultVarsBefore.totalAssetsAllocatable);
            console.log("totalAssetsDeposited", defaultVarsBefore.totalAssetsDeposited);
            assertTrue(
                (defaultVarsBefore.totalSupply != 0 && defaultVarsBefore.interestLeft != 0)
                    || defaultVarsBefore.toGulp != 0,
                GPOST_INTEREST_A
            ); //TODO account for not harveested stuff
        }
    }

    function assert_GPOST_INTEREST_B() internal {
        assertGe(defaultVarsAfter.lastInterestUpdate, defaultVarsBefore.lastInterestUpdate, GPOST_INTEREST_B);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  POST CONDITIONS: STRATEGIES                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_GPOST_STRATEGIES_A() internal {
        for (uint256 i; i < strategies.length; i++) {
            Strategy memory strategy = defaultVarsAfter.strategies[strategies[i]];

            if (strategy.status == IEulerEarn.StrategyStatus.Emergency) {
                assertLe(strategy.allocated, defaultVarsBefore.strategies[strategies[i]].allocated, GPOST_STRATEGIES_A);
            }
        }
    }

    function assert_GPOST_STRATEGIES_H() internal {
        for (uint256 i; i < strategies.length; i++) {
            Strategy memory strategyBefore = defaultVarsBefore.strategies[strategies[i]];
            Strategy memory strategyAfter = defaultVarsAfter.strategies[strategies[i]];

            if (strategyAfter.allocated > strategyBefore.allocated) {
                assertLe(strategyAfter.allocated, AmountCapLib.resolve(strategyAfter.cap), GPOST_STRATEGIES_H);
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _hasLastInterestUpdated() internal view returns (bool) {
        return defaultVarsAfter.lastInterestUpdate == block.timestamp
            && defaultVarsBefore.lastInterestUpdate != block.timestamp;
    }
}
