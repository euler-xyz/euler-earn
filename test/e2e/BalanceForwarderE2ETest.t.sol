// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {TrackingRewardStreams} from "reward-streams/TrackingRewardStreams.sol";
import {
    EulerAggregationVaultBase,
    EulerAggregationVault,
    console2,
    EVault,
    IEVault,
    IRMTestDefault,
    TestERC20,
    EulerAggregationVaultFactory,
    Rewards
} from "../common/EulerAggregationVaultBase.t.sol";

contract BalanceForwarderE2ETest is EulerAggregationVaultBase {
    uint256 user1InitialBalance = 100000e18;

    address trackingReward;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(deployer);
        trackingReward = address(new TrackingRewardStreams(address(evc), 2 weeks));

        EulerAggregationVaultFactory.FactoryParams memory factoryParams = EulerAggregationVaultFactory.FactoryParams({
            balanceTracker: trackingReward,
            rewardsModuleImpl: address(rewardsImpl),
            hooksModuleImpl: address(hooksImpl),
            feeModuleImpl: address(feeModuleImpl),
            allocationPointsModuleImpl: address(allocationPointsModuleImpl),
            rebalancer: address(rebalancer),
            withdrawalQueueImpl: address(withdrawalQueueImpl)
        });
        eulerAggregationVaultFactory = new EulerAggregationVaultFactory(factoryParams);
        eulerAggregationVault = EulerAggregationVault(
            eulerAggregationVaultFactory.deployEulerAggregationVault(
                address(assetTST), "assetTST_Agg", "assetTST_Agg", CASH_RESERVE_ALLOCATION_POINTS
            )
        );

        // grant admin roles to deployer
        eulerAggregationVault.grantRole(eulerAggregationVault.ALLOCATIONS_MANAGER_ADMIN(), deployer);
        // eulerAggregationVault.grantRole(eulerAggregationVault.WITHDRAW_QUEUE_MANAGER_ADMIN(), deployer);
        eulerAggregationVault.grantRole(eulerAggregationVault.STRATEGY_ADDER_ADMIN(), deployer);
        eulerAggregationVault.grantRole(eulerAggregationVault.STRATEGY_REMOVER_ADMIN(), deployer);
        eulerAggregationVault.grantRole(eulerAggregationVault.AGGREGATION_LAYER_MANAGER_ADMIN(), deployer);

        // grant roles to manager
        eulerAggregationVault.grantRole(eulerAggregationVault.ALLOCATIONS_MANAGER(), manager);
        // eulerAggregationVault.grantRole(eulerAggregationVault.WITHDRAW_QUEUE_MANAGER(), manager);
        eulerAggregationVault.grantRole(eulerAggregationVault.STRATEGY_ADDER(), manager);
        eulerAggregationVault.grantRole(eulerAggregationVault.STRATEGY_REMOVER(), manager);
        eulerAggregationVault.grantRole(eulerAggregationVault.AGGREGATION_LAYER_MANAGER(), manager);
        vm.stopPrank();

        uint256 initialStrategyAllocationPoints = 500e18;
        _addStrategy(manager, address(eTST), initialStrategyAllocationPoints);
        assetTST.mint(user1, user1InitialBalance);

        // deposit into aggregator
        uint256 amountToDeposit = 10000e18;
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
    }

    function testBalanceForwarderrAddress_Integrity() public view {
        assertEq(eulerAggregationVault.balanceTrackerAddress(), trackingReward);
    }

    function testEnableBalanceForwarder() public {
        vm.prank(user1);
        eulerAggregationVault.enableBalanceForwarder();

        assertTrue(eulerAggregationVault.balanceForwarderEnabled(user1));
        assertEq(
            TrackingRewardStreams(trackingReward).balanceOf(user1, address(eulerAggregationVault)),
            eulerAggregationVault.balanceOf(user1)
        );
    }

    function testDisableBalanceForwarder() public {
        vm.prank(user1);
        eulerAggregationVault.enableBalanceForwarder();

        assertTrue(eulerAggregationVault.balanceForwarderEnabled(user1));

        vm.prank(user1);
        eulerAggregationVault.disableBalanceForwarder();

        assertFalse(eulerAggregationVault.balanceForwarderEnabled(user1));
        assertEq(TrackingRewardStreams(trackingReward).balanceOf(user1, address(eulerAggregationVault)), 0);
    }

    function testHookWhenReceiverEnabled() public {
        vm.prank(user1);
        eulerAggregationVault.enableBalanceForwarder();

        // deposit into aggregator
        uint256 amountToDeposit = 10000e18;
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

            assertEq(
                TrackingRewardStreams(trackingReward).balanceOf(user1, address(eulerAggregationVault)),
                eulerAggregationVault.balanceOf(user1)
            );
        }
    }

    function testHookWhenSenderEnabled() public {
        vm.prank(user1);
        eulerAggregationVault.enableBalanceForwarder();

        // deposit into aggregator
        uint256 amountToDeposit = 10000e18;
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

            assertEq(
                TrackingRewardStreams(trackingReward).balanceOf(user1, address(eulerAggregationVault)),
                eulerAggregationVault.balanceOf(user1)
            );
        }

        {
            uint256 amountToWithdraw = eulerAggregationVault.balanceOf(user1);
            uint256 totalAssetsDepositedBefore = eulerAggregationVault.totalAssetsDeposited();
            uint256 aggregatorTotalSupplyBefore = eulerAggregationVault.totalSupply();
            uint256 user1AssetTSTBalanceBefore = assetTST.balanceOf(user1);

            vm.prank(user1);
            eulerAggregationVault.redeem(amountToWithdraw, user1, user1);

            assertEq(eTST.balanceOf(address(eulerAggregationVault)), 0);
            assertEq(eulerAggregationVault.totalAssetsDeposited(), totalAssetsDepositedBefore - amountToWithdraw);
            assertEq(eulerAggregationVault.totalSupply(), aggregatorTotalSupplyBefore - amountToWithdraw);
            assertEq(
                assetTST.balanceOf(user1),
                user1AssetTSTBalanceBefore + eulerAggregationVault.convertToAssets(amountToWithdraw)
            );
            assertEq(TrackingRewardStreams(trackingReward).balanceOf(user1, address(eulerAggregationVault)), 0);
        }
    }
}
