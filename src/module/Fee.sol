// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// interfaces
import {IBalanceForwarder} from "../interface/IBalanceForwarder.sol";
import {IBalanceTracker} from "reward-streams/interfaces/IBalanceTracker.sol";
import {IRewardStreams} from "reward-streams/interfaces/IRewardStreams.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// contracts
import {Shared} from "../Shared.sol";
// libs
import {StorageLib, AggregationVaultStorage} from "../lib/StorageLib.sol";
import {ErrorsLib} from "../lib/ErrorsLib.sol";
import {EventsLib} from "../lib/EventsLib.sol";

abstract contract FeeModule is Shared {
    /// @dev The maximum performanceFee the vault can have is 50%
    uint256 internal constant MAX_PERFORMANCE_FEE = 0.5e18;

    /// @notice Set performance fee recipient address
    /// @notice @param _newFeeRecipient Recipient address
    function setFeeRecipient(address _newFeeRecipient) external {
        AggregationVaultStorage storage $ = StorageLib._getAggregationVaultStorage();
        address feeRecipientCached = $.feeRecipient;

        if (_newFeeRecipient == feeRecipientCached) revert ErrorsLib.FeeRecipientAlreadySet();

        emit EventsLib.SetFeeRecipient(feeRecipientCached, _newFeeRecipient);

        $.feeRecipient = _newFeeRecipient;
    }

    /// @notice Set performance fee (1e18 == 100%)
    /// @notice @param _newFee Fee rate
    function setPerformanceFee(uint256 _newFee) external {
        AggregationVaultStorage storage $ = StorageLib._getAggregationVaultStorage();

        uint256 performanceFeeCached = $.performanceFee;

        if (_newFee > MAX_PERFORMANCE_FEE) revert ErrorsLib.MaxPerformanceFeeExceeded();
        if ($.feeRecipient == address(0)) revert ErrorsLib.FeeRecipientNotSet();
        if (_newFee == performanceFeeCached) revert ErrorsLib.PerformanceFeeAlreadySet();

        emit EventsLib.SetPerformanceFee(performanceFeeCached, _newFee);

        $.performanceFee = _newFee;
    }
}

contract Fee is FeeModule {}
