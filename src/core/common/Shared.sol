// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// interfaces
import {IHookTarget} from "evk/src/interfaces/IHookTarget.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IEulerAggregationVault} from "../interface/IEulerAggregationVault.sol";
// libs
import {HooksLib} from "../lib/HooksLib.sol";
import {StorageLib as Storage, AggregationVaultStorage} from "../lib/StorageLib.sol";
import {ErrorsLib as Errors} from "../lib/ErrorsLib.sol";
import {EventsLib as Events} from "../lib/EventsLib.sol";

/// @title Shared contract
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
abstract contract Shared {
    using HooksLib for uint32;

    uint8 internal constant REENTRANCYLOCK__UNLOCKED = 1;
    uint8 internal constant REENTRANCYLOCK__LOCKED = 2;

    uint32 public constant DEPOSIT = 1 << 0;
    uint32 public constant WITHDRAW = 1 << 1;
    uint32 public constant MINT = 1 << 2;
    uint32 public constant REDEEM = 1 << 3;
    uint32 public constant ADD_STRATEGY = 1 << 4;
    uint32 public constant REMOVE_STRATEGY = 1 << 5;

    uint32 constant ACTIONS_COUNTER = 1 << 6;
    uint256 constant HOOKS_MASK = 0x00000000000000000000000000000000000000000000000000000000FFFFFFFF;

    /// @dev Interest rate smearing period
    uint256 public constant INTEREST_SMEAR = 2 weeks;
    /// @dev Minimum amount of shares to exist for gulp to be enabled
    uint256 public constant MIN_SHARES_FOR_GULP = 1e7;

    modifier nonReentrant() {
        AggregationVaultStorage storage $ = Storage._getAggregationVaultStorage();

        if ($.locked == REENTRANCYLOCK__LOCKED) revert Errors.Reentrancy();

        $.locked = REENTRANCYLOCK__LOCKED;
        _;
        $.locked = REENTRANCYLOCK__UNLOCKED;
    }

    function _deductLoss(uint256 _lostAmount) internal {
        AggregationVaultStorage storage $ = Storage._getAggregationVaultStorage();

        uint168 cachedInterestLeft = $.interestLeft;
        if (cachedInterestLeft >= _lostAmount) {
            // cut loss from interest left only
            cachedInterestLeft -= uint168(_lostAmount);
        } else {
            // cut the interest left and socialize the diff
            $.totalAssetsDeposited -= _lostAmount - cachedInterestLeft;
            cachedInterestLeft = 0;
        }
        $.interestLeft = cachedInterestLeft;
    }

    function _setHooksConfig(address _hooksTarget, uint32 _hookedFns) internal {
        if (_hooksTarget != address(0) && IHookTarget(_hooksTarget).isHookTarget() != IHookTarget.isHookTarget.selector)
        {
            revert Errors.NotHooksContract();
        }
        if (_hookedFns != 0 && _hooksTarget == address(0)) {
            revert Errors.InvalidHooksTarget();
        }
        if (_hookedFns >= ACTIONS_COUNTER) revert Errors.InvalidHookedFns();

        AggregationVaultStorage storage $ = Storage._getAggregationVaultStorage();
        $.hooksConfig = (uint256(uint160(_hooksTarget)) << 32) | uint256(_hookedFns);
    }

    /// @notice Checks whether a hook has been installed for the function and if so, invokes the hook target.
    /// @param _fn Function to call the hook for.
    /// @param _caller Caller's address.
    function _callHooksTarget(uint32 _fn, address _caller) internal {
        AggregationVaultStorage storage $ = Storage._getAggregationVaultStorage();

        (address target, uint32 hookedFns) = _getHooksConfig($.hooksConfig);

        if (hookedFns.isNotSet(_fn)) return;

        (bool success, bytes memory data) = target.call(abi.encodePacked(msg.data, _caller));

        if (!success) _revertBytes(data);
    }

    /// @notice Get the hooks contract and the hooked functions.
    /// @return address Hooks contract.
    /// @return uint32 Hooked functions.
    function _getHooksConfig(uint256 _hooksConfig) internal pure returns (address, uint32) {
        return (address(uint160(_hooksConfig >> 32)), uint32(_hooksConfig & HOOKS_MASK));
    }

    /// @dev gulp positive yield into interest left amd update accrued interest.
    function _gulp() internal {
        _updateInterestAccrued();

        AggregationVaultStorage storage $ = Storage._getAggregationVaultStorage();

        // Do not gulp if total supply is too low
        if (IERC4626(address(this)).totalSupply() < MIN_SHARES_FOR_GULP) return;

        uint256 toGulp =
            IEulerAggregationVault(address(this)).totalAssetsAllocatable() - $.totalAssetsDeposited - $.interestLeft;
        if (toGulp == 0) return;

        uint256 maxGulp = type(uint168).max - $.interestLeft;
        if (toGulp > maxGulp) toGulp = maxGulp; // cap interest, allowing the vault to function

        $.interestSmearEnd = uint40(block.timestamp + INTEREST_SMEAR);
        $.interestLeft += uint168(toGulp); // toGulp <= maxGulp <= max uint168

        emit Events.Gulp($.interestLeft, $.interestSmearEnd);
    }

    /// @notice update accrued interest.
    function _updateInterestAccrued() internal {
        uint256 accruedInterest = _interestAccruedFromCache();

        AggregationVaultStorage storage $ = Storage._getAggregationVaultStorage();
        // it's safe to down-cast because the accrued interest is a fraction of interest left
        $.interestLeft -= uint168(accruedInterest);
        $.lastInterestUpdate = uint40(block.timestamp);

        // Move interest accrued to totalAssetsDeposited
        $.totalAssetsDeposited += accruedInterest;
    }

    /// @dev Get accrued interest without updating it.
    /// @return uint256 Accrued interest.
    function _interestAccruedFromCache() internal view returns (uint256) {
        AggregationVaultStorage storage $ = Storage._getAggregationVaultStorage();

        // If distribution ended, full amount is accrued
        if (block.timestamp >= $.interestSmearEnd) {
            return $.interestLeft;
        }

        // If just updated return 0
        if ($.lastInterestUpdate == block.timestamp) {
            return 0;
        }

        // Else return what has accrued
        uint256 totalDuration = $.interestSmearEnd - $.lastInterestUpdate;
        uint256 timePassed = block.timestamp - $.lastInterestUpdate;

        return $.interestLeft * timePassed / totalDuration;
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
