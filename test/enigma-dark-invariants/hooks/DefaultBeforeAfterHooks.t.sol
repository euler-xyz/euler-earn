// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";

// Interfaces
import {IERC4626, IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IERC20Handler} from "../handlers/interfaces/IERC20Handler.sol";
import {IEulerEarn} from "src/interfaces/IEulerEarn.sol";

/// @title Default Before After Hooks
/// @notice Helper contract for before and after hooks
/// @dev This contract is inherited by handlers
abstract contract DefaultBeforeAfterHooks is BaseHooks {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         STRUCTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    struct User {
        uint256 balance;
    }

    struct MarketData {
        uint256 nextCapTime;
        uint256 cap;
        uint256 removableAt;
        bool enabled;
    }

    struct EulerEarnData {
        // Times
        uint256 nextGuardianUpdateTime;
        uint256 nextTimelockDecreaseTime;
        // Markets
        mapping(IERC4626 => MarketData) markets;
        // Addresses
        address guardian;
        // Assets
        uint256 totalSupply;
        uint256 totalAssets;
        uint256 lastTotalAssets;
        uint256 yield;
        // Fees
        uint256 fee;
        uint256 feeRecipientBalance;
    }

    struct DefaultVars {
        EulerEarnData[EULER_EARN_VAULTS_NUM] eulerEarnVaults;
    }
    //mapping(address => User) users;

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
    function _setUpDefaultVars(DefaultVars storage _defaultVars) internal {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HOOKS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _defaultHooksBefore() internal {
        // Default values
        for (uint256 i; i < eulerEarnVaults.length; i++) {
            _setDefaultValues(defaultVarsBefore.eulerEarnVaults[i], IEulerEarn(eulerEarnVaults[i]));
        }
        // Health & user account data
        _setUserValues(defaultVarsBefore);
    }

    function _defaultHooksAfter() internal {
        // Default values
        for (uint256 i; i < eulerEarnVaults.length; i++) {
            _setDefaultValues(defaultVarsAfter.eulerEarnVaults[i], IEulerEarn(eulerEarnVaults[i]));
        }
        // Health & user account data
        _setUserValues(defaultVarsAfter);
    }

    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HELPERS                                             //
    /////////////////////////////////////////////////////////////////////////////////////////////*/

    function _setDefaultValues(EulerEarnData storage _eulerEarnData, IEulerEarn _vault) internal {
        // Times
        _eulerEarnData.nextGuardianUpdateTime = _vault.pendingGuardian().validAt;
        _eulerEarnData.nextTimelockDecreaseTime = _vault.pendingTimelock().validAt;

        // Markets
        /*         for (uint256 i; i < markets.length; i++) {TODO we should use other array for this 
            IERC4626 market = markets[i];
            _eulerEarnData.markets[market] = MarketData({
                nextCapTime: _vault.pendingCap(market).validAt,
                cap: _vault.pendingCap(market).validAt,
                removableAt: _vault.config(market).removableAt,
                enabled: _vault.config(market).enabled
            });
        } */

        // Asset
        _eulerEarnData.totalSupply = _vault.totalSupply();
        _eulerEarnData.totalAssets = _vault.totalAssets();
        _eulerEarnData.lastTotalAssets = _vault.lastTotalAssets();
        //_eulerEarnData.yield = _getUnAccountedYield(); TODO: revisit these, check whihch one we still need

        // Fees
        //_eulerEarnData.fee = _getAccruedFee(_eulerEarnData.yield); TODO: revisit these, check which one we still need
        _eulerEarnData.feeRecipientBalance = loanToken.balanceOf(_vault.feeRecipient());

        // Addresses
        _eulerEarnData.guardian = _vault.guardian();
    }

    function _setUserValues(DefaultVars storage _defaultVars) internal {
        /*         for (uint256 i; i < actorAddresses.length; i++) { TODO check if we need this
            _defaultVars.users[actorAddresses[i]].balance = vault.balanceOf(actorAddresses[i]);
        } */
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POST CONDITIONS: BASE                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*     function assert_GPOST_BASE_A() internal {// TODO revisit these
        assertGe(defaultVarsAfter.nextGuardianUpdateTime, defaultVarsBefore.nextGuardianUpdateTime, GPOST_BASE_A);

        if (_hasGuardianChanged()) {
            assertGt(block.timestamp, defaultVarsBefore.nextGuardianUpdateTime, GPOST_BASE_A);
        }
    }

    function assert_GPOST_BASE_B(IERC4626 market) internal {
        assertGe(
            defaultVarsAfter.markets[market].nextCapTime, defaultVarsBefore.markets[market].nextCapTime, GPOST_BASE_B
        );

        if (_hasCapIncreased(market)) {
            assertGt(block.timestamp, defaultVarsBefore.markets[market].nextCapTime, GPOST_BASE_B);
        }
    }

    function assert_GPOST_BASE_C() internal {
        assertGe(defaultVarsAfter.nextTimelockDecreaseTime, defaultVarsBefore.nextTimelockDecreaseTime, GPOST_BASE_C);

        if (_hasTimelockDecreased()) {
            assertGt(block.timestamp, defaultVarsBefore.nextTimelockDecreaseTime, GPOST_BASE_C);
        }
    }

    function assert_GPOST_BASE_D(IERC4626 market) internal {
        assertGe(
            defaultVarsAfter.markets[market].removableAt, defaultVarsBefore.markets[market].removableAt, GPOST_BASE_D
        );

        if (_hasMarketBeenRemoved(market)) {
            assertGt(block.timestamp, defaultVarsBefore.markets[market].removableAt, GPOST_BASE_D);
        }
    } */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POST CONDITIONS: FEES                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*     function assert_GPOST_FEES_A() internal {// Revisit these
        uint256 feeRecipientBalanceDelta =
            UtilsLib.zeroFloorSub(defaultVarsAfter.feeRecipientBalance, defaultVarsBefore.feeRecipientBalance);
        if (feeRecipientBalanceDelta != 0) {
            assertEq(feeRecipientBalanceDelta, defaultVarsBefore.fee, GPOST_FEES_A);
        }
    } */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 POST CONDITIONS: ACCOUNTING                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*     function assert_GPOST_ACCOUNTING_A() internal {//TODO revisit these
        if (msg.sig != IEulerEarnHandler.withdrawVault.selector && msg.sig != IEulerEarnHandler.redeemVault.selector) {
            assertGe(defaultVarsAfter.totalAssets, defaultVarsBefore.totalAssets, GPOST_ACCOUNTING_A);
        }
    }

    function assert_GPOST_ACCOUNTING_B() internal {
        if (defaultVarsAfter.totalAssets > defaultVarsBefore.totalAssets) {
            assertTrue(
                (msg.sig == IEulerEarnHandler.depositVault.selector || msg.sig == IEulerEarnHandler.mintVault.selector)
                    || defaultVarsBefore.yield != 0 || defaultVarsAfter.yield != 0,
                GPOST_ACCOUNTING_B
            );
        }
    }

    function assert_GPOST_ACCOUNTING_C() internal {
        if (defaultVarsAfter.totalSupply > defaultVarsBefore.totalSupply) {
            assertTrue(
                (msg.sig == IEulerEarnHandler.depositVault.selector || msg.sig == IEulerEarnHandler.mintVault.selector)
                    || defaultVarsBefore.fee != 0,
                GPOST_ACCOUNTING_C
            );
        }
    }

    function assert_GPOST_ACCOUNTING_D() internal {
        if (defaultVarsAfter.totalSupply < defaultVarsBefore.totalSupply) {
            assertTrue(
                msg.sig == IEulerEarnHandler.withdrawVault.selector || msg.sig == IEulerEarnHandler.redeemVault.selector,
                GPOST_ACCOUNTING_D
            );
        }
    }

    function assert_GPOST_ACCOUNTING_E() internal {
        if (_target == address(vault) || _target == address(publicAllocator)) {
            if (
                (msg.sig != IERC20Handler.approve.selector && msg.sig != IERC20Handler.transfer.selector)
                    && msg.sig != IERC20Handler.transferFrom.selector
            ) {
                //assertEq(defaultVarsAfter.lastTotalAssets, defaultVarsAfter.totalAssets, GPOST_ACCOUNTING_E); TODO: remove comment after testing
            }
        }
    } */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  POST CONDITIONS: REENTRANCY                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*     function assert_GPOST_REENTRANCY_A() internal { TODO check if we need this
        assertFalse(vault.reentrancyGuardEntered(), GPOST_REENTRANCY_A);
    } */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*     function _hasGuardianChanged() internal returns (bool) {
        return defaultVarsBefore.guardian != defaultVarsAfter.guardian;
    }

    function _hasCapIncreased(IERC4626 market) internal returns (bool) {
        return defaultVarsBefore.markets[market].cap < defaultVarsAfter.markets[market].cap;
    }

    function _hasTimelockDecreased() internal returns (bool) {
        return defaultVarsBefore.nextTimelockDecreaseTime > defaultVarsAfter.nextTimelockDecreaseTime;
    }

    function _hasMarketBeenRemoved(IERC4626 market) internal returns (bool) {
        return defaultVarsBefore.markets[market].enabled && !defaultVarsAfter.markets[market].enabled;
    }

    function _balanceHasNotChanged() internal returns (bool) {
        for (uint256 i; i < actorAddresses.length; i++) {
            if (defaultVarsBefore.users[actorAddresses[i]].balance != defaultVarsAfter.users[actorAddresses[i]].balance)
            {
                return false;
            }
        }

        return true;
    } */
}
