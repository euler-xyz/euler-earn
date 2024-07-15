// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {
    EulerAggregationVaultBase,
    EulerAggregationVault,
    console2,
    EVault,
    IEVault,
    IRMTestDefault,
    TestERC20,
    IEulerAggregationVault,
    ErrorsLib
} from "../common/EulerAggregationVaultBase.t.sol";

contract ToggleStrategyEmergencyStatusE2ETest is EulerAggregationVaultBase {
    uint256 user1InitialBalance = 100000e18;

    IEVault eTSTsecondary;

    function setUp() public virtual override {
        super.setUp();

        uint256 initialStrategyAllocationPoints = 500e18;
        _addStrategy(manager, address(eTST), initialStrategyAllocationPoints);

        {
            eTSTsecondary = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTsecondary.setInterestRateModel(address(new IRMTestDefault()));
            eTSTsecondary.setMaxLiquidationDiscount(0.2e4);
            eTSTsecondary.setFeeReceiver(feeReceiver);

            _addStrategy(manager, address(eTSTsecondary), 1000e18);
        }

        assetTST.mint(user1, user1InitialBalance);
    }

    function testToggleStrategyEmergencyStatus() public {
        uint256 totalAllocationPointsBefore = eulerAggregationVault.totalAllocationPoints();

        vm.prank(manager);
        eulerAggregationVault.toggleStrategyEmergencyStatus(address(eTSTsecondary));

        IEulerAggregationVault.Strategy memory strategyAfter = eulerAggregationVault.getStrategy(address(eTSTsecondary));

        assertEq(strategyAfter.status == IEulerAggregationVault.StrategyStatus.Emergency, true);
        assertEq(
            eulerAggregationVault.totalAllocationPoints(), totalAllocationPointsBefore - strategyAfter.allocationPoints
        );

        totalAllocationPointsBefore = eulerAggregationVault.totalAllocationPoints();

        vm.prank(manager);
        eulerAggregationVault.toggleStrategyEmergencyStatus(address(eTSTsecondary));

        strategyAfter = eulerAggregationVault.getStrategy(address(eTSTsecondary));
        assertEq(strategyAfter.status == IEulerAggregationVault.StrategyStatus.Active, true);
        assertEq(
            eulerAggregationVault.totalAllocationPoints(), totalAllocationPointsBefore + strategyAfter.allocationPoints
        );
    }

    function testToggleStrategyEmergencyStatusForInactiveStrategy() public {
        vm.startPrank(manager);
        vm.expectRevert(ErrorsLib.InactiveStrategy.selector);
        eulerAggregationVault.toggleStrategyEmergencyStatus(address(0x2));
        vm.stopPrank();
    }

    // this to test a scneraio where a startegy `withdraw()` start reverting.
    // Guardian will set the strategy in emergency mode, harvest and withdraw should execute,
    // user will be able to withdraw from other strategy, losses will only be in the faulty strategy.
    function testDepositRebalanceWithdrawWithFaultyStartegy() public {
        uint256 amountToDeposit = 10000e18;

        // deposit into aggregator
        {
            uint256 balanceBefore = eulerAggregationVault.balanceOf(user1);
            uint256 totalSupplyBefore = eulerAggregationVault.totalSupply();
            uint256 totalAssetsDepositedBefore = eulerAggregationVault.totalAssetsDeposited();
            uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

            vm.startPrank(user1);
            assetTST.approve(address(eulerAggregationVault), amountToDeposit);
            eulerAggregationVault.deposit(amountToDeposit, user1);
            vm.stopPrank();

            assertEq(eulerAggregationVault.balanceOf(user1), balanceBefore + amountToDeposit);
            assertEq(eulerAggregationVault.totalSupply(), totalSupplyBefore + amountToDeposit);
            assertEq(eulerAggregationVault.totalAssetsDeposited(), totalAssetsDepositedBefore + amountToDeposit);
            assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - amountToDeposit);
        }

        // rebalance into strategy
        // 2500 total points; 1000 for reserve(40%), 500(20%) for eTST, 1000(40%) for eTSTsecondary
        // 10k deposited; 4k for reserve, 2k for eTST, 4k for eTSTsecondary
        vm.warp(block.timestamp + 86400);
        {
            IEulerAggregationVault.Strategy memory eTSTstrategyBefore = eulerAggregationVault.getStrategy(address(eTST));
            IEulerAggregationVault.Strategy memory eTSTsecondarystrategyBefore =
                eulerAggregationVault.getStrategy(address(eTSTsecondary));

            assertEq(eTST.convertToAssets(eTST.balanceOf(address(eulerAggregationVault))), eTSTstrategyBefore.allocated);
            assertEq(
                eTSTsecondary.convertToAssets(eTSTsecondary.balanceOf(address(eulerAggregationVault))),
                eTSTsecondarystrategyBefore.allocated
            );

            uint256 expectedeTSTStrategyCash = eulerAggregationVault.totalAssetsAllocatable()
                * eTSTstrategyBefore.allocationPoints / eulerAggregationVault.totalAllocationPoints();
            uint256 expectedeTSTsecondaryStrategyCash = eulerAggregationVault.totalAssetsAllocatable()
                * eTSTsecondarystrategyBefore.allocationPoints / eulerAggregationVault.totalAllocationPoints();

            assertTrue(expectedeTSTStrategyCash != 0);
            assertTrue(expectedeTSTsecondaryStrategyCash != 0);

            address[] memory strategiesToRebalance = new address[](2);
            strategiesToRebalance[0] = address(eTST);
            strategiesToRebalance[1] = address(eTSTsecondary);
            vm.prank(user1);
            rebalancer.executeRebalance(address(eulerAggregationVault), strategiesToRebalance);

            assertEq(
                eulerAggregationVault.totalAllocated(), expectedeTSTStrategyCash + expectedeTSTsecondaryStrategyCash
            );
            assertEq(eTST.convertToAssets(eTST.balanceOf(address(eulerAggregationVault))), expectedeTSTStrategyCash);
            assertEq(
                eTSTsecondary.convertToAssets(eTSTsecondary.balanceOf(address(eulerAggregationVault))),
                expectedeTSTsecondaryStrategyCash
            );
            assertEq((eulerAggregationVault.getStrategy(address(eTST))).allocated, expectedeTSTStrategyCash);
            assertEq(
                (eulerAggregationVault.getStrategy(address(eTSTsecondary))).allocated, expectedeTSTsecondaryStrategyCash
            );
            assertEq(
                assetTST.balanceOf(address(eulerAggregationVault)),
                amountToDeposit - (expectedeTSTStrategyCash + expectedeTSTsecondaryStrategyCash)
            );
        }

        // set eTST in emergency mode
        vm.prank(manager);
        eulerAggregationVault.toggleStrategyEmergencyStatus(address(eTST));

        // full withdraw, will have to withdraw from strategy as cash reserve is not enough, user should be able to withdraw
        {
            uint256 amountToWithdraw = eulerAggregationVault.balanceOf(user1);
            uint256 user1AssetTSTBalanceBefore = assetTST.balanceOf(user1);
            uint256 expectedAssets = eulerAggregationVault.convertToAssets(amountToWithdraw);

            vm.prank(user1);
            eulerAggregationVault.redeem(amountToWithdraw, user1, user1);

            assertTrue(eTST.balanceOf(address(eulerAggregationVault)) != 0);
            assertEq(eulerAggregationVault.totalAssetsDeposited(), 0);
            assertEq(eulerAggregationVault.totalSupply(), 0);
            assertEq(
                assetTST.balanceOf(user1),
                user1AssetTSTBalanceBefore + expectedAssets
            );
        }
    }

    function testToggleCashReserveStrategyStatus() public {
        vm.startPrank(manager);
        vm.expectRevert(ErrorsLib.CanNotToggleStrategyEmergencyStatus.selector);
        eulerAggregationVault.toggleStrategyEmergencyStatus(address(0));
        vm.stopPrank();
    }

    function testRemoveStrategyInEmergencyStatus() public {
        vm.prank(manager);
        eulerAggregationVault.toggleStrategyEmergencyStatus(address(eTSTsecondary));

        vm.prank(manager);
        vm.expectRevert(ErrorsLib.CanNotRemoveStrategyInEmergencyStatus.selector);
        eulerAggregationVault.removeStrategy(address(eTSTsecondary));
    }
}
