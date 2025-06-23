// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC4626, IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title EulerEarnHandler
/// @notice Handler test contract for a set of actions
abstract contract EulerEarnHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function depositEEV(uint256 _assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        target = _getRandomEulerEarnVault(j);

        uint256 previewedShares = IERC4626(target).previewDeposit(_assets);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeCall(IERC4626.deposit, (_assets, receiver)));

        if (success) {
            _after();

            uint256 shares = abi.decode(returnData, (uint256));

            ///////////////////////////////////////////////////////////////////////////////////////
            //                                        HSPOST                                     //
            ///////////////////////////////////////////////////////////////////////////////////////

            /* /// @dev ERC4626// TODO revisit properties
            assertLe(previewedShares, shares, ERC4626_DEPOSIT_INVARIANT_B);

            /// @dev USER
            assertEq(
                defaultVarsBefore.users[receiver].balance + shares,
                defaultVarsAfter.users[receiver].balance,
                HSPOST_USER_E
            );

            /// @dev ACCOUNTING
            assertEq(defaultVarsBefore.totalAssets + _assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_C); */
        } else {
            revert("EulerEarnHandler: deposit failed");
        }
    }

    function mintEEV(uint256 _shares, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        target = _getRandomEulerEarnVault(j);

        uint256 previewedAssets = IERC4626(target).previewMint(_shares);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeCall(IERC4626.mint, (_shares, receiver)));

        if (success) {
            _after();

            uint256 _assets = abi.decode(returnData, (uint256));

            ///////////////////////////////////////////////////////////////////////////////////////
            //                                        HSPOST                                     //
            ///////////////////////////////////////////////////////////////////////////////////////

            /* /// @dev ERC4626 // TODO revisit properties
            assertGe(previewedAssets, _assets, ERC4626_MINT_INVARIANT_B);

            /// @dev USER
            assertEq(
                defaultVarsBefore.users[receiver].balance + _shares,
                defaultVarsAfter.users[receiver].balance,
                HSPOST_USER_E
            );

            /// @dev ACCOUNTING
            assertEq(defaultVarsBefore.totalAssets + _assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_C); */
        } else {
            revert("EulerEarnHandler: mint failed");
        }
    }

    function withdrawEEV(uint256 _assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        target = _getRandomEulerEarnVault(j);

        // uint256 previewedShares = IERC4626(target).previewWithdraw(_assets);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeCall(IERC4626.withdraw, (_assets, receiver, address(actor))));

        if (success) {
            _after();

            uint256 _shares = abi.decode(returnData, (uint256));

            ///////////////////////////////////////////////////////////////////////////////////////
            //                                        HSPOST                                     //
            ///////////////////////////////////////////////////////////////////////////////////////

            /* /// @dev ERC4626 // TODO revisit properties
            assertGe(previewedShares, _shares, ERC4626_WITHDRAW_INVARIANT_B);

            /// @dev USER
            assertEq(
                defaultVarsBefore.users[address(actor)].balance - _shares,
                defaultVarsAfter.users[address(actor)].balance,
                HSPOST_USER_F
            );

            /// @dev ACCOUNTING
            assertGe(defaultVarsBefore.totalAssets - _assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_B);

            assertEq(defaultVarsBefore.totalAssets - _assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_D); */
        } else {
            revert("EulerEarnHandler: withdraw failed");
        }
    }

    function redeemEEV(uint256 _shares, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        target = _getRandomEulerEarnVault(j);

        // uint256 previewedAssets = IERC4626(target).previewRedeem(_shares);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeCall(IERC4626.redeem, (_shares, receiver, address(actor))));

        if (success) {
            _after();

            uint256 _assets = abi.decode(returnData, (uint256));

            ///////////////////////////////////////////////////////////////////////////////////////
            //                                        HSPOST                                     //
            ///////////////////////////////////////////////////////////////////////////////////////

            /* /// @dev ERC4626 // TODO revisit properties
            assertLe(previewedAssets, _assets, ERC4626_REDEEM_INVARIANT_B);

            /// @dev USER
            assertEq(
                defaultVarsBefore.users[address(actor)].balance - _shares,
                defaultVarsAfter.users[address(actor)].balance,
                HSPOST_USER_F
            );

            /// @dev ACCOUNTING
            assertGe(defaultVarsBefore.totalAssets - _assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_B);
            assertEq(defaultVarsBefore.totalAssets - _assets, defaultVarsAfter.totalAssets, HSPOST_ACCOUNTING_D); */
        } else {
            revert("EulerEarnHandler: redeem failed");
        }
    }
}
