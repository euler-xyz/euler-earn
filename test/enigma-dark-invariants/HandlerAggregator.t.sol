// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// modules Actions Handler contracts,
import {ERC20Handler} from "./handlers/modules/ERC20Handler.t.sol";
import {ERC4626Handler} from "./handlers/modules/ERC4626Handler.t.sol";
import {EulerEarnVaultModuleHandler} from "./handlers/modules/EulerEarnVaultModuleHandler.t.sol";
import {FeeModuleHandler} from "./handlers/modules/FeeModuleHandler.t.sol";
import {RewardsModuleHandler} from "./handlers/modules/RewardsModuleHandler.t.sol";
import {StrategyModuleModuleHandler} from "./handlers/modules/StrategyModuleModuleHandler.t.sol";
import {WithdrawalQueueModuleHandler} from "./handlers/modules/WithdrawalQueueModuleHandler.t.sol";
import {NegativeYieldHandler} from "./handlers/simulators/NegativeYieldHandler.t.sol";

// Simulator Handler contracts,
import {DonationAttackHandler} from "./handlers/simulators/DonationAttackHandler.t.sol";

/// @notice Helper contract to aggregate all handler contracts, inherited in BaseInvariants
abstract contract HandlerAggregator is
    ERC20Handler, // Module handlers
    ERC4626Handler,
    EulerEarnVaultModuleHandler,
    FeeModuleHandler,
    RewardsModuleHandler,
    StrategyModuleModuleHandler,
    WithdrawalQueueModuleHandler,
    DonationAttackHandler, // Simulator handlers
    NegativeYieldHandler
{
    /// @notice Helper function in case any handler requires additional setup
    function _setUpHandlers() internal {}
}
