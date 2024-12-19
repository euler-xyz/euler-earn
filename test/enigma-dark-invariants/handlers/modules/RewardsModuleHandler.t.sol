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

/// @title RewardsModuleHandler
/// @notice Handler test contract for a set of actions
contract RewardsModuleHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function optInStrategyRewards(uint8 i) external {
        address strategy = _getRandomStrategy(i);

        _before();
        eulerEulerEarnVault.optInStrategyRewards(strategy);
        _after();
    }

    function optOutStrategyRewards(uint8 i) external {
        address strategy = _getRandomStrategy(i);

        _before();
        eulerEulerEarnVault.optOutStrategyRewards(strategy);
        _after();
    }

    function enableRewardForStrategy(uint8 i) external setup {
        address strategy = _getRandomStrategy(i);

        address reward = address(assetTST);

        _before();
        eulerEulerEarnVault.enableRewardForStrategy(strategy, reward);
        _after();
    }

    function disableRewardForStrategy(uint8 i, bool forfeitRecentReward) external setup {
        address strategy = _getRandomStrategy(i);

        address reward = address(assetTST);

        _before();
        eulerEulerEarnVault.disableRewardForStrategy(strategy, reward, forfeitRecentReward);
        _after();
    }

    function claimStrategyReward(uint8 i, uint8 j, bool forfeitRecentReward) external setup {
        address strategy = _getRandomStrategy(i);

        address recipient = _getRandomActor(j);

        address reward = address(assetTST);

        _before();
        eulerEulerEarnVault.claimStrategyReward(strategy, reward, recipient, forfeitRecentReward);
        _after();
    }

    function enableBalanceForwarder() external setup {
        bool success;
        bytes memory returnData;

        address target = address(eulerEulerEarnVault);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(IEulerEarn.enableBalanceForwarder.selector));

        if (success) {
            _after();

            assert(true);
        }
    }

    function disableBalanceForwarder() external setup {
        bool success;
        bytes memory returnData;

        address target = address(eulerEulerEarnVault);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(IEulerEarn.disableBalanceForwarder.selector));

        if (success) {
            _after();

            assert(true);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
