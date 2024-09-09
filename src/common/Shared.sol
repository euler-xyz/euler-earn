// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// interfaces
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// contracts
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {ERC20Upgradeable} from "@openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
// libs
import {StorageLib as Storage, YieldAggregatorStorage} from "../lib/StorageLib.sol";
import {ErrorsLib as Errors} from "../lib/ErrorsLib.sol";
import {EventsLib as Events} from "../lib/EventsLib.sol";
import {ConstantsLib as Constants} from "../lib/ConstantsLib.sol";

/// @title Shared contract
/// @dev Have common functions that is used in different contracts.
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
abstract contract Shared is EVCUtil {
    /// @dev Non-reentracy protection for state-changing functions.
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    /// @dev Non-reentracy protection for view functions.
    modifier nonReentrantView() {
        _nonReentrantViewBefore();
        _;
    }

    constructor(address _evc) EVCUtil(_evc) {}

    /// @dev Deduct _lossAmount from the not-distributed amount, if not enough, socialize loss.
    /// @dev The not distributed amount is amount available to gulp + interest left.
    /// @param _lossAmount Amount lost.
    function _deductLoss(uint256 _lossAmount) internal {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        uint256 totalAssetsDepositedCache = $.totalAssetsDeposited;
        uint256 totalNotDistributed = _totalAssetsAllocatable() - totalAssetsDepositedCache;

        // set interestLeft to zero, will be updated to the right value during _gulp()
        $.interestLeft = 0;
        if (_lossAmount > totalNotDistributed) {
            _lossAmount -= totalNotDistributed;

            // socialize the loss
            $.totalAssetsDeposited = totalAssetsDepositedCache - _lossAmount;

            emit Events.DeductLoss(_lossAmount);
        }
    }

    /// @dev Checks whether a hook has been installed for the function and if so, invokes the hook target.
    /// @param _fn Function to call the hook for.
    /// @param _caller Caller's address.
    function _callHooksTarget(uint32 _fn, address _caller) internal {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        (address target, uint32 hookedFns) = ($.hooksTarget, $.hookedFns);

        if ((hookedFns & _fn) == 0) return;

        (bool success, bytes memory data) = target.call(abi.encodePacked(msg.data, _caller));

        if (!success) _revertBytes(data);
    }

    /// @dev gulp positive yield into interest left amd update accrued interest.
    function _gulp() internal {
        _updateInterestAccrued();

        // Do not gulp if total supply is too low
        if (_totalSupply() < Constants.MIN_SHARES_FOR_GULP) return;

        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        uint256 toGulp = _totalAssetsAllocatable() - $.totalAssetsDeposited - $.interestLeft;
        if (toGulp == 0) return;

        uint256 maxGulp = type(uint168).max - $.interestLeft;
        if (toGulp > maxGulp) toGulp = maxGulp; // cap interest, allowing the vault to function

        $.lastInterestUpdate = uint40(block.timestamp);
        $.interestSmearEnd = uint40(block.timestamp + Constants.INTEREST_SMEAR);
        $.interestLeft += uint168(toGulp); // toGulp <= maxGulp <= max uint168

        emit Events.Gulp($.interestLeft, $.interestSmearEnd);
    }

    /// @dev update accrued interest.
    function _updateInterestAccrued() internal {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        uint256 accruedInterest = _interestAccruedFromCache($.interestLeft);

        if (accruedInterest > 0) {
            // it's safe to down-cast because the accrued interest is a fraction of interest left
            $.interestLeft -= uint168(accruedInterest);
            $.lastInterestUpdate = uint40(block.timestamp);

            // Move interest accrued to totalAssetsDeposited
            $.totalAssetsDeposited += accruedInterest;

            emit Events.InterestUpdated(accruedInterest, $.interestLeft);
        }
    }

    /// @dev Get accrued interest without updating it.
    /// @return Accrued interest.
    function _interestAccruedFromCache(uint168 _interestLeft) internal view returns (uint256) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        uint40 interestSmearEndCached = $.interestSmearEnd;
        // If distribution ended, full amount is accrued
        if (block.timestamp >= interestSmearEndCached) {
            return _interestLeft;
        }

        uint40 lastInterestUpdateCached = $.lastInterestUpdate;
        // If just updated return 0
        if (lastInterestUpdateCached == block.timestamp) {
            return 0;
        }

        // Else return what has accrued
        uint256 totalDuration = interestSmearEndCached - lastInterestUpdateCached;
        uint256 timePassed = block.timestamp - lastInterestUpdateCached;

        return _interestLeft * timePassed / totalDuration;
    }

    /// @dev Return total assets allocatable.
    /// @dev The total assets allocatable is the current balanceOf + total amount already allocated.
    /// @return total assets allocatable.
    function _totalAssetsAllocatable() internal view returns (uint256) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        return IERC20(IERC4626(address(this)).asset()).balanceOf(address(this)) + $.totalAllocated;
    }

    /// @dev Override for _msgSender() to use the EVC authentication.
    /// @return Sender address.
    function _msgSender() internal view virtual override (EVCUtil) returns (address) {
        return EVCUtil._msgSender();
    }

    /// @dev Retrieves boolean indicating if the account opted in to forward balance changes to the rewards contract
    /// @param _account Address to query
    /// @return True if balance forwarder is enabled
    function _balanceForwarderEnabled(address _account) internal view returns (bool) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        return $.isBalanceForwarderEnabled[_account];
    }

    /// @dev Retrieve the address of rewards contract, tracking changes in account's balances.
    /// @return The balance tracker address.
    function _balanceTrackerAddress() internal view returns (address) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        return address($.balanceTracker);
    }

    /// @dev Read `_balances` from storage.
    /// @return _account balance.
    function _balanceOf(address _account) internal view returns (uint256) {
        ERC20Upgradeable.ERC20Storage storage $ = _getInheritedERC20Storage();
        return $._balances[_account];
    }

    /// @dev Read `_totalSupply` from storage.
    /// @return Yield aggregator total supply.
    function _totalSupply() internal view returns (uint256) {
        ERC20Upgradeable.ERC20Storage storage $ = _getInheritedERC20Storage();
        return $._totalSupply;
    }

    /// @dev Used by the nonReentrant before returning the execution flow to the original function.
    function _nonReentrantBefore() private {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        if ($.locked == Constants.REENTRANCYLOCK__LOCKED) revert Errors.Reentrancy();

        $.locked = Constants.REENTRANCYLOCK__LOCKED;
    }

    /// @dev Used by the nonReentrant after returning the execution flow to the original function.
    function _nonReentrantAfter() private {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        $.locked = Constants.REENTRANCYLOCK__UNLOCKED;
    }

    /// @dev Used by the nonReentrantView before returning the execution flow to the original function.
    function _nonReentrantViewBefore() private view {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        if ($.locked == Constants.REENTRANCYLOCK__LOCKED) {
            // The hook target is allowed to bypass the RO-reentrancy lock.
            if (msg.sender != $.hooksTarget && msg.sender != address(this)) {
                revert Errors.Reentrancy();
            }
        }
    }

    /// @dev Return ERC20StorageLocation pointer.
    ///      This is copied from ERC20Upgradeable OZ implementation to be able to access ERC20 storage and override functions.
    ///      keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    function _getInheritedERC20Storage() private pure returns (ERC20Upgradeable.ERC20Storage storage $) {
        assembly {
            $.slot := 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00
        }
    }

    /// @dev Revert with call error or EmptyError
    /// @param _errorMsg call revert message
    function _revertBytes(bytes memory _errorMsg) private pure {
        if (_errorMsg.length > 0) {
            assembly {
                revert(add(32, _errorMsg), mload(_errorMsg))
            }
        }

        revert Errors.EmptyError();
    }
}
