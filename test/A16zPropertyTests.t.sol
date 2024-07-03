// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// a16z properties tests
import {ERC4626Test} from "erc4626-tests/ERC4626.test.sol";
// contracts
import {EulerAggregationLayer} from "../src/core/EulerAggregationLayer.sol";
import {Rebalancer} from "../src/plugin/Rebalancer.sol";
import {Hooks} from "../src/core/module/Hooks.sol";
import {Rewards} from "../src/core/module/Rewards.sol";
import {Fee} from "../src/core/module/Fee.sol";
import {EulerAggregationLayerFactory} from "../src/core/EulerAggregationLayerFactory.sol";
import {WithdrawalQueue} from "../src/plugin/WithdrawalQueue.sol";
import {AllocationPoints} from "../src/core/module/AllocationPoints.sol";
// mocks
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract A16zPropertyTests is ERC4626Test {
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

    function setUp() public override {
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

        _underlying_ = address(new ERC20Mock());
        _vault_ = eulerAggregationLayerFactory.deployEulerAggregationLayer(
            _underlying_, "E20M_Agg", "E20M_Agg", CASH_RESERVE_ALLOCATION_POINTS
        );
        _delta_ = 0;
        _vaultMayBeEmpty = false;
        _unlimitedAmount = false;
    }

    function testToAvoidCoverage() public pure {
        return;
    }
}
