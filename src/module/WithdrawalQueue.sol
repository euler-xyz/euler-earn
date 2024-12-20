// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// contracts
import {Shared} from "../common/Shared.sol";
// libs
import {StorageLib as Storage, EulerEarnStorage} from "../lib/StorageLib.sol";
import {ErrorsLib as Errors} from "../lib/ErrorsLib.sol";
import {EventsLib as Events} from "../lib/EventsLib.sol";

/// @title WithdrawalQueueModule contract
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
abstract contract WithdrawalQueueModule is Shared {
    /// @notice Swap two strategies indexes in the withdrawal queue.
    /// @param _index1 index of first strategy.
    /// @param _index2 index of second strategy.
    function reorderWithdrawalQueue(uint8 _index1, uint8 _index2) external virtual nonReentrant {
        EulerEarnStorage storage $ = Storage._getEulerEarnStorage();

        uint256 length = $.withdrawalQueue.length;
        require(_index1 < length && _index2 < length, Errors.OutOfBounds());

        require(_index1 != _index2, Errors.SameIndexes());

        ($.withdrawalQueue[_index1], $.withdrawalQueue[_index2]) =
            ($.withdrawalQueue[_index2], $.withdrawalQueue[_index1]);

        emit Events.ReorderWithdrawalQueue(_index1, _index2);
    }

    /// @notice Return the withdrawal queue.
    /// @return withdrawal queue array.
    function withdrawalQueue() public view virtual nonReentrantView returns (address[] memory) {
        EulerEarnStorage storage $ = Storage._getEulerEarnStorage();

        return $.withdrawalQueue;
    }
}

contract WithdrawalQueue is WithdrawalQueueModule {
    constructor(IntegrationsParams memory _integrationsParams) Shared(_integrationsParams) {}
}
