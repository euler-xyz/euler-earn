// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEulerEarn} from "src/interface/IEulerEarn.sol";

// Libraries
import "forge-std/console.sol";
import {ErrorsLib} from "src/lib/ErrorsLib.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title EulerEarnVaultModuleHandler
/// @notice Handler test contract for a set of actions
contract EulerEarnVaultModuleHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function rebalance(uint8 i, uint8 j, uint8 k) external {
        address[] memory _strategies = new address[](3);
        _strategies[0] = _getRandomStrategy(i);
        _strategies[1] = _getRandomStrategy(j);
        _strategies[2] = _getRandomStrategy(k);

        _before();
        try eulerEulerEarnVault.rebalance(_strategies) {
            _after();
        } catch {
            assertTrue(false, NR_BASE_C);
        }
    }

    function harvest() external {
        _before();
        try eulerEulerEarnVault.harvest() {
            _after();
        } catch (bytes memory reason) {
            bytes4 desiredSelector = ErrorsLib.ERC20ExceededSafeSupply.selector;
            bytes4 receivedSelector = bytes4(reason);
            if (desiredSelector != receivedSelector) {
                assertTrue(false, NR_BASE_B);
            }
        }
    }

    function updateInterestAccrued() external {
        _before();
        try eulerEulerEarnVault.updateInterestAccrued() {
            _after();
        } catch {
            assertTrue(false, NR_BASE_A);
        }
    }

    function gulp() external {
        _before();
        try eulerEulerEarnVault.gulp() {
            _after();
        } catch {
            assertTrue(false, NR_BASE_D);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
