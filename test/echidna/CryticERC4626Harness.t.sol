// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// echidna erc-4626 properties tests
import {CryticERC4626PropertyTests} from "crytic-properties/ERC4626/ERC4626PropertyTests.sol";
// contracts
import {EulerAggregationLayer} from "../../src/core/EulerAggregationLayer.sol";
import {Rebalancer} from "../../src/plugin/Rebalancer.sol";
import {Hooks} from "../../src/core/module/Hooks.sol";
import {Rewards} from "../../src/core/module/Rewards.sol";
import {Fee} from "../../src/core/module/Fee.sol";
import {EulerAggregationLayerFactory} from "../../src/core/EulerAggregationLayerFactory.sol";
import {WithdrawalQueue} from "../../src/plugin/WithdrawalQueue.sol";
import {AllocationPoints} from "../../src/core/module/AllocationPoints.sol";
import {TestERC20Token} from "crytic-properties/ERC4626/util/TestERC20Token.sol";

contract CryticERC4626Harness is CryticERC4626PropertyTests {
    uint256 public constant CASH_RESERVE_ALLOCATION_POINTS = 1000e18;

    // core modules
    Rewards rewardsImpl;
    Hooks hooksImpl;
    Fee feeModuleImpl;
    AllocationPoints allocationPointsModuleImpl;
    // plugins
    Rebalancer rebalancerPlugin;
    WithdrawalQueue withdrawalQueuePluginImpl;

    EulerAggregationLayerFactory eulerAggregationLayerFactory;
    EulerAggregationLayer eulerAggregationLayer;

    constructor() {
        rewardsImpl = new Rewards();
        hooksImpl = new Hooks();
        feeModuleImpl = new Fee();
        allocationPointsModuleImpl = new AllocationPoints();

        rebalancerPlugin = new Rebalancer();
        withdrawalQueuePluginImpl = new WithdrawalQueue();

        EulerAggregationLayerFactory.FactoryParams memory factoryParams = EulerAggregationLayerFactory.FactoryParams({
            balanceTracker: address(0),
            rewardsModuleImpl: address(rewardsImpl),
            hooksModuleImpl: address(hooksImpl),
            feeModuleImpl: address(feeModuleImpl),
            allocationPointsModuleImpl: address(allocationPointsModuleImpl),
            rebalancer: address(rebalancerPlugin),
            withdrawalQueueImpl: address(withdrawalQueuePluginImpl)
        });
        eulerAggregationLayerFactory = new EulerAggregationLayerFactory(factoryParams);

        TestERC20Token _asset = new TestERC20Token("Test Token", "TT", 18);
        address _vault = eulerAggregationLayerFactory.deployEulerAggregationLayer(
            address(_asset), "TT_Agg", "TT_Agg", CASH_RESERVE_ALLOCATION_POINTS
        );

        initialize(address(_vault), address(_asset), false);
    }
}
