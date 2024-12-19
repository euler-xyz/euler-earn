// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEulerEarn} from "src/interface/IEulerEarn.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title StrategyModuleModuleHandler
/// @notice Handler test contract for a set of actions
contract StrategyModuleModuleHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function adjustAllocationPoints(uint256 _newPoints, uint8 i) external {
        address strategy = _getRandomStrategy(i);
        targetStrategy = strategy;

        _before();
        eulerEulerEarnVault.adjustAllocationPoints(strategy, _newPoints);
        _after();

        assert(true);
    }

    function setStrategyCap(uint16 _cap, uint8 i) external {
        address strategy = _getRandomStrategy(i);
        targetStrategy = strategy;

        _before();
        eulerEulerEarnVault.setStrategyCap(strategy, _cap);
        _after();

        assert(true);
    }

    function toggleStrategyEmergencyStatus(uint8 i) external {
        address strategy = _getRandomStrategy(i);
        targetStrategy = strategy;

        IEulerEarn.StrategyStatus status = eulerEulerEarnVault.getStrategy(strategy).status;

        _before();
        if (uint256(status) > 0) {
            try eulerEulerEarnVault.toggleStrategyEmergencyStatus(strategy) {
                _after();
            } catch {
                assertTrue(false, NR_BASE_E);
            }
        } else {
            eulerEulerEarnVault.toggleStrategyEmergencyStatus(strategy);
        }
        _after();
    }

    function addStrategy(uint256 _allocationPoints, uint8 i) external {
        address strategy = _getRandomStrategy(i);
        targetStrategy = strategy;

        _before();
        eulerEulerEarnVault.addStrategy(strategy, _allocationPoints);
        _after();

        assert(true);
    }

    function removeStrategy(uint8 i) external {
        address strategy = _getRandomStrategy(i);
        targetStrategy = strategy;

        _before();
        eulerEulerEarnVault.removeStrategy(strategy);
        _after();

        assert(true);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
