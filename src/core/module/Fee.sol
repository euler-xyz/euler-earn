// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// interfaces
import {IBalanceForwarder} from "../interface/IBalanceForwarder.sol";
import {IBalanceTracker} from "reward-streams/interfaces/IBalanceTracker.sol";
import {IRewardStreams} from "reward-streams/interfaces/IRewardStreams.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// libs
import {StorageLib, AggregationVaultStorage} from "../lib/StorageLib.sol";
import {ErrorsLib as Errors} from "../lib/ErrorsLib.sol";
import {EventsLib as Events} from "../lib/EventsLib.sol";

/// @title FeeModule contract
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
abstract contract FeeModule {
    /// @dev The maximum performanceFee the vault can have is 50%
    uint256 internal constant MAX_PERFORMANCE_FEE = 0.5e18;

    /// @notice Set performance fee recipient address
    /// @param _newFeeRecipient Recipient address
    function setFeeRecipient(address _newFeeRecipient) external virtual {
        AggregationVaultStorage storage $ = StorageLib._getAggregationVaultStorage();

        emit Events.SetFeeRecipient($.feeRecipient, _newFeeRecipient);

        $.feeRecipient = _newFeeRecipient;
    }

    /// @notice Set performance fee (1e18 == 100%)
    /// @param _newFee Fee rate
    function setPerformanceFee(uint256 _newFee) external virtual {
        AggregationVaultStorage storage $ = StorageLib._getAggregationVaultStorage();

        uint256 performanceFeeCached = $.performanceFee;

        if (_newFee > MAX_PERFORMANCE_FEE) revert Errors.MaxPerformanceFeeExceeded();
        if ($.feeRecipient == address(0)) revert Errors.FeeRecipientNotSet();
        if (_newFee == performanceFeeCached) revert Errors.PerformanceFeeAlreadySet();

        emit Events.SetPerformanceFee(performanceFeeCached, _newFee);

        $.performanceFee = _newFee;
    }
}

contract Fee is FeeModule {}