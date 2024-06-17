// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {HooksLib} from "./lib/HooksLib.sol";
import {IHookTarget} from "evk/src/interfaces/IHookTarget.sol";

abstract contract Hooks {
    using HooksLib for uint32;

    error InvalidHooksTarget();
    error NotHooksContract();
    error InvalidHookedFns();
    error EmptyError();

    uint32 public constant DEPOSIT = 1 << 0;
    uint32 public constant WITHDRAW = 1 << 1;
    uint32 public constant ADD_STRATEGY = 1 << 2;
    uint32 public constant REMOVE_STRATEGY = 1 << 3;
    uint32 constant ACTIONS_COUNTER = 1 << 4;

    uint256 constant HOOKS_MASK = 0x00000000000000000000000000000000000000000000000000000000FFFFFFFF;

    struct HooksStorage {
        /// @dev storing the hooks target and kooked functions.
        uint256 hooksConfig;
    }

    // keccak256(abi.encode(uint256(keccak256("euler_aggregation_vault.storage.Hooks")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant HooksStorageLocation = 0x7daefa3ee1567d8892b825e51ce683a058a5785193bcc2ca50940db02ccbf700;

    event SetHooksConfig(address indexed hooksTarget, uint32 hookedFns);

    /// @notice Get the hooks contract and the hooked functions.
    /// @return address Hooks contract.
    /// @return uint32 Hooked functions.
    function getHooksConfig() external view returns (address, uint32) {
        HooksStorage storage $ = _getHooksStorage();

        return _getHooksConfig($.hooksConfig);
    }

    /// @notice Set hooks contract and hooked functions.
    /// @dev This funtion should be overriden to implement access control and call _setHooksConfig().
    /// @param _hooksTarget Hooks contract.
    /// @param _hookedFns Hooked functions.
    function setHooksConfig(address _hooksTarget, uint32 _hookedFns) public virtual;

    /// @notice Set hooks contract and hooked functions.
    /// @dev This funtion should be called when implementing setHooksConfig().
    /// @param _hooksTarget Hooks contract.
    /// @param _hookedFns Hooked functions.
    function _setHooksConfig(address _hooksTarget, uint32 _hookedFns) internal {
        if (_hooksTarget != address(0) && IHookTarget(_hooksTarget).isHookTarget() != IHookTarget.isHookTarget.selector)
        {
            revert NotHooksContract();
        }
        if (_hookedFns != 0 && _hooksTarget == address(0)) {
            revert InvalidHooksTarget();
        }
        if (_hookedFns >= ACTIONS_COUNTER) revert InvalidHookedFns();

        HooksStorage storage $ = _getHooksStorage();
        $.hooksConfig = (uint256(uint160(_hooksTarget)) << 32) | uint256(_hookedFns);

        emit SetHooksConfig(_hooksTarget, _hookedFns);
    }

    /// @notice Checks whether a hook has been installed for the function and if so, invokes the hook target.
    /// @param _fn Function to call the hook for.
    /// @param _caller Caller's address.
    function _callHooksTarget(uint32 _fn, address _caller) internal {
        HooksStorage storage $ = _getHooksStorage();

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

        revert EmptyError();
    }

    function _getHooksStorage() private pure returns (HooksStorage storage $) {
        assembly {
            $.slot := HooksStorageLocation
        }
    }
}
