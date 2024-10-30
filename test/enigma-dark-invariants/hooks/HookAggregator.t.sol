// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Hook Contracts
import {DefaultBeforeAfterHooks} from "./DefaultBeforeAfterHooks.t.sol";

/// @title HookAggregator
/// @notice Helper contract to aggregate all before / after hook contracts, inherited on each handler
abstract contract HookAggregator is DefaultBeforeAfterHooks {
    /// @notice Initializer for the hooks
    function _setUpHooks() internal {
        _setUpDefaultHooks();
    }

    /// @notice Modular hook selector, per module
    function _before() internal {
        _defaultHooksBefore();
    }

    /// @notice Modular hook selector, per module
    function _after() internal {
        _defaultHooksAfter();

        // POST-CONDITIONS
        _checkPostConditions();
    }

    /// @notice Postconditions for the handlers
    function _checkPostConditions() internal {
        // BASE
        assert_GPOST_BASE_A();
        assert_GPOST_BASE_B();
        // INTEREST
        assert_GPOST_INTEREST_A();
        assert_GPOST_INTEREST_B();
        // STRATEGY
        assert_GPOST_STRATEGIES_A();
        assert_GPOST_STRATEGIES_H();
    }
}
