// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../common/YieldAggregatorBase.t.sol";

contract BalanceForwarderTest is YieldAggregatorBase {
    uint256 user1InitialBalance = 100000e18;

    YieldAggregator eulerYieldAggregatorVaultNoTracker;

    function setUp() public virtual override {
        super.setUp();

        eulerYieldAggregatorVaultNoTracker = YieldAggregator(
            eulerYieldAggregatorVaultFactory.deployYieldAggregator(
                address(assetTST), "assetTST_Agg", "assetTST_Agg", CASH_RESERVE_ALLOCATION_POINTS
            )
        );

        vm.startPrank(deployer);
        balanceTracker = address(new MockBalanceTracker());

        YieldAggregatorFactory.FactoryParams memory factoryParams = YieldAggregatorFactory.FactoryParams({
            evc: address(evc),
            balanceTracker: balanceTracker,
            yieldAggregatorVaultModule: address(yieldAggregatorVaultModule),
            rewardsModule: address(rewardsModule),
            hooksModule: address(hooksModule),
            feeModule: address(feeModuleModule),
            strategyModule: address(strategyModuleModule),
            withdrawalQueueModule: address(withdrawalQueueModuleModule)
        });
        eulerYieldAggregatorVaultFactory = new YieldAggregatorFactory(factoryParams);

        eulerYieldAggregatorVault = YieldAggregator(
            eulerYieldAggregatorVaultFactory.deployYieldAggregator(
                address(assetTST), "assetTST_Agg", "assetTST_Agg", CASH_RESERVE_ALLOCATION_POINTS
            )
        );

        // grant admin roles to deployer
        eulerYieldAggregatorVault.grantRole(ConstantsLib.GUARDIAN_ADMIN, deployer);
        eulerYieldAggregatorVault.grantRole(ConstantsLib.STRATEGY_OPERATOR_ADMIN, deployer);
        eulerYieldAggregatorVault.grantRole(ConstantsLib.YIELD_AGGREGATOR_MANAGER_ADMIN, deployer);
        eulerYieldAggregatorVault.grantRole(ConstantsLib.WITHDRAWAL_QUEUE_MANAGER_ADMIN, deployer);

        // grant roles to manager
        eulerYieldAggregatorVault.grantRole(ConstantsLib.GUARDIAN, manager);
        eulerYieldAggregatorVault.grantRole(ConstantsLib.STRATEGY_OPERATOR, manager);
        eulerYieldAggregatorVault.grantRole(ConstantsLib.YIELD_AGGREGATOR_MANAGER, manager);
        eulerYieldAggregatorVault.grantRole(ConstantsLib.WITHDRAWAL_QUEUE_MANAGER, manager);
        vm.stopPrank();
    }

    function testBalanceForwarderrAddress_Integrity() public view {
        assertEq(eulerYieldAggregatorVault.balanceTrackerAddress(), balanceTracker);
    }

    function testEnableBalanceForwarder() public {
        vm.expectEmit();
        emit EventsLib.EnableBalanceForwarder(user1);
        vm.prank(user1);
        eulerYieldAggregatorVault.enableBalanceForwarder();

        assertTrue(eulerYieldAggregatorVault.balanceForwarderEnabled(user1));
        assertEq(MockBalanceTracker(balanceTracker).numCalls(), 1);
        assertEq(MockBalanceTracker(balanceTracker).calls(user1, 0, false), 1);
    }

    function test_EnableBalanceForwarder_AlreadyEnabledOk() public {
        vm.prank(user1);
        eulerYieldAggregatorVault.enableBalanceForwarder();
        vm.prank(user1);
        eulerYieldAggregatorVault.enableBalanceForwarder();

        assertTrue(eulerYieldAggregatorVault.balanceForwarderEnabled(user1));
    }

    function testEnableBalanceForwarderYieldAggregatorRewardsNotSupported() public {
        vm.expectRevert(ErrorsLib.YieldAggregatorRewardsNotSupported.selector);
        vm.prank(user1);
        eulerYieldAggregatorVaultNoTracker.enableBalanceForwarder();
    }

    function testDisableBalanceForwarder() public {
        vm.prank(user1);
        eulerYieldAggregatorVault.enableBalanceForwarder();

        vm.expectEmit();
        emit EventsLib.DisableBalanceForwarder(user1);
        vm.prank(user1);
        eulerYieldAggregatorVault.disableBalanceForwarder();

        assertFalse(eulerYieldAggregatorVault.balanceForwarderEnabled(user1));
        assertEq(MockBalanceTracker(balanceTracker).numCalls(), 2);
        assertEq(MockBalanceTracker(balanceTracker).calls(user1, 0, false), 2);
    }

    function testDisableBalanceForwarder_AlreadyDisabledOk() public {
        assertFalse(eulerYieldAggregatorVault.balanceForwarderEnabled(user1));
        vm.prank(user1);
        eulerYieldAggregatorVault.disableBalanceForwarder();

        assertFalse(eulerYieldAggregatorVault.balanceForwarderEnabled(user1));
    }

    function testDisableBalanceForwarder_RevertsWhen_NoBalanceTracker() public {
        vm.expectRevert(ErrorsLib.YieldAggregatorRewardsNotSupported.selector);
        vm.prank(user1);
        eulerYieldAggregatorVaultNoTracker.disableBalanceForwarder();
    }
}
