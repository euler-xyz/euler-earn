// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {EulerAggregationLayerBase, EulerAggregationLayer} from "../common/EulerAggregationLayerBase.t.sol";

contract AddStrategyTest is EulerAggregationLayerBase {
    function setUp() public virtual override {
        super.setUp();
    }

    function testAddStrategy() public {
        uint256 allocationPoints = 500e18;
        uint256 totalAllocationPointsBefore = eulerAggregationLayer.totalAllocationPoints();

        assertEq(_getWithdrawalQueueLength(), 0);

        _addStrategy(manager, address(eTST), allocationPoints);

        assertEq(eulerAggregationLayer.totalAllocationPoints(), allocationPoints + totalAllocationPointsBefore);
        assertEq(_getWithdrawalQueueLength(), 1);
    }

    function testAddStrategy_FromUnauthorizedAddress() public {
        uint256 allocationPoints = 500e18;

        assertEq(_getWithdrawalQueueLength(), 0);

        vm.expectRevert();
        _addStrategy(deployer, address(eTST), allocationPoints);
    }

    function testAddStrategy_WithInvalidAsset() public {
        uint256 allocationPoints = 500e18;

        assertEq(_getWithdrawalQueueLength(), 0);

        vm.expectRevert();
        _addStrategy(manager, address(eTST2), allocationPoints);
    }

    function testAddStrategy_AlreadyAddedStrategy() public {
        uint256 allocationPoints = 500e18;
        uint256 totalAllocationPointsBefore = eulerAggregationLayer.totalAllocationPoints();

        assertEq(_getWithdrawalQueueLength(), 0);

        _addStrategy(manager, address(eTST), allocationPoints);

        assertEq(eulerAggregationLayer.totalAllocationPoints(), allocationPoints + totalAllocationPointsBefore);
        assertEq(_getWithdrawalQueueLength(), 1);

        vm.expectRevert();
        _addStrategy(manager, address(eTST), allocationPoints);
    }
}
