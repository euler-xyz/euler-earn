// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IBorrowing} from "lib/euler-vault-kit/src/EVault/modules/Borrowing.sol";
import {IEVault} from "lib/euler-vault-kit/src/EVault/IEVault.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title BorrowingModuleHandler
/// @notice Handler test contract for a set of actions
abstract contract BorrowingModuleHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    ACTIONS: BORROWING                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function borrow(uint256 assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        target = _getRandomLoanVault(j);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeCall(IBorrowing.borrow, (assets, receiver)));

        if (success) {
            _after();
        } else {
            revert("BorrowingModuleHandler: borrow failed");
        }
    }

    function repay(uint256 assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        target = _getRandomLoanVault(j);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeCall(IBorrowing.repay, (assets, receiver)));

        if (success) {
            _after();
        } else {
            revert("BorrowingModuleHandler: repay failed");
        }
    }

    function repayWithShares(uint256 amount, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        target = _getRandomLoanVault(j);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeCall(IBorrowing.repayWithShares, (amount, receiver)));

        if (success) {
            _after();
        } else {
            revert("BorrowingModuleHandler: repayWithShares failed");
        }
    }

    function pullDebt(uint256 assets, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address from = _getRandomActor(i);

        target = _getRandomLoanVault(j);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeCall(IBorrowing.pullDebt, (assets, from)));

        if (success) {
            _after();
        } else {
            revert("BorrowingModuleHandler: pullDebt failed");
        }
    }

    function touch(uint8 i) external {
        target = _getRandomEVault(i);

        _before();
        IEVault(target).touch();
        _after();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
