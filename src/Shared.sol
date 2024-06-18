// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {StorageLib, AggregationVaultStorage} from "./lib/StorageLib.sol";
import {ErrorsLib} from "./lib/ErrorsLib.sol";
import {IEVC} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {IHookTarget} from "evk/src/interfaces/IHookTarget.sol";
import {HooksLib} from "./lib/HooksLib.sol";

contract Shared {
    using HooksLib for uint32;

    uint8 internal constant REENTRANCYLOCK__UNLOCKED = 1;
    uint8 internal constant REENTRANCYLOCK__LOCKED = 2;

    uint32 public constant DEPOSIT = 1 << 0;
    uint32 public constant WITHDRAW = 1 << 1;
    uint32 public constant ADD_STRATEGY = 1 << 2;
    uint32 public constant REMOVE_STRATEGY = 1 << 3;

    uint32 constant ACTIONS_COUNTER = 1 << 4;
    uint256 constant HOOKS_MASK = 0x00000000000000000000000000000000000000000000000000000000FFFFFFFF;

    modifier nonReentrant() {
        AggregationVaultStorage storage $ = StorageLib._getAggregationVaultStorage();

        if ($.locked == REENTRANCYLOCK__LOCKED) revert ErrorsLib.Reentrancy();

        $.locked = REENTRANCYLOCK__LOCKED;
        _;
        $.locked = REENTRANCYLOCK__UNLOCKED;
    }

    function _msgSender() internal view virtual returns (address) {
        address sender = msg.sender;
        AggregationVaultStorage storage $ = StorageLib._getAggregationVaultStorage();

        if (sender == address($.evc)) {
            (sender,) = IEVC($.evc).getCurrentOnBehalfOfAccount(address(0));
        }

        return sender;
    }

    function _setHooksConfig(address _hooksTarget, uint32 _hookedFns) internal {
        if (_hooksTarget != address(0) && IHookTarget(_hooksTarget).isHookTarget() != IHookTarget.isHookTarget.selector)
        {
            revert ErrorsLib.NotHooksContract();
        }
        if (_hookedFns != 0 && _hooksTarget == address(0)) {
            revert ErrorsLib.InvalidHooksTarget();
        }
        if (_hookedFns >= ACTIONS_COUNTER) revert ErrorsLib.InvalidHookedFns();

        AggregationVaultStorage storage $ = StorageLib._getAggregationVaultStorage();
        $.hooksConfig = (uint256(uint160(_hooksTarget)) << 32) | uint256(_hookedFns);
    }

    /// @notice Checks whether a hook has been installed for the function and if so, invokes the hook target.
    /// @param _fn Function to call the hook for.
    /// @param _caller Caller's address.
    function _callHooksTarget(uint32 _fn, address _caller) internal {
        AggregationVaultStorage storage $ = StorageLib._getAggregationVaultStorage();

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

    /// @dev Revert with call error or EmptyError
    /// @param _errorMsg call revert message
    function _revertBytes(bytes memory _errorMsg) private pure {
        if (_errorMsg.length > 0) {
            assembly {
                revert(add(32, _errorMsg), mload(_errorMsg))
            }
        }

        revert ErrorsLib.EmptyError();
    }
}