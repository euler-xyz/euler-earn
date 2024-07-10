// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {
    EulerAggregationVaultBase,
    EulerAggregationVault,
    IWithdrawalQueue,
    IEVault,
    TestERC20
} from "../common/EulerAggregationVaultBase.t.sol";
import {Actor} from "./util/Actor.sol";
import {Strategy} from "./util/Strategy.sol";
import {EulerAggregationVaultHandler} from "./handler/EulerAggregationVaultHandler.sol";
import {RebalancerHandler} from "./handler/RebalancerHandler.sol";
import {WithdrawalQueueHandler} from "./handler/WithdrawalQueueHandler.sol";

contract EulerAggregationVaultInvariants is EulerAggregationVaultBase {
    Actor internal actorUtil;
    Strategy internal strategyUtil;

    EulerAggregationVaultHandler internal eulerAggregationVaultHandler;
    RebalancerHandler internal rebalancerHandler;
    WithdrawalQueueHandler internal withdrawalQueueHandler;

    // other strategies
    IEVault eTSTsecond;
    IEVault eTSTthird;
    IEVault eTSTforth;
    IEVault eTSTfifth;
    IEVault eTSTsixth;

    function setUp() public override {
        super.setUp();

        actorUtil = new Actor();
        actorUtil.includeActor(manager);
        actorUtil.includeActor(deployer);
        actorUtil.includeActor(user1);
        actorUtil.includeActor(user2);

        strategyUtil = new Strategy();
        strategyUtil.includeStrategy(address(eTST));
        _deployOtherStrategies();
        strategyUtil.includeStrategy(address(eTSTsecond));
        strategyUtil.includeStrategy(address(eTSTthird));
        strategyUtil.includeStrategy(address(eTSTforth));
        strategyUtil.includeStrategy(address(eTSTfifth));
        strategyUtil.includeStrategy(address(eTSTsixth));
        // cash reserve strategy
        strategyUtil.includeStrategy(address(0));

        eulerAggregationVaultHandler =
            new EulerAggregationVaultHandler(eulerAggregationVault, actorUtil, strategyUtil, withdrawalQueue);
        rebalancerHandler =
            new RebalancerHandler(eulerAggregationVault, rebalancer, actorUtil, strategyUtil, withdrawalQueue);
        withdrawalQueueHandler =
            new WithdrawalQueueHandler(eulerAggregationVault, actorUtil, strategyUtil, withdrawalQueue);

        targetContract(address(eulerAggregationVaultHandler));
        targetContract(address(rebalancerHandler));
        targetContract(address(withdrawalQueueHandler));
    }

    // Right after gulp, total assets allocatable should be always equal to total assets deposited + interest left.
    function invariant_gulp() public {
        eulerAggregationVault.gulp();

        assertEq(
            eulerAggregationVault.totalAssetsAllocatable(),
            eulerAggregationVault.totalAssetsDeposited()
                + (eulerAggregationVault.getAggregationVaultSavingRate()).interestLeft
        );
    }

    // totalAssetsDeposited should be equal to the totalAssetsAllocatable after SMEAR has passed.
    function invariant_totalAssets() public {
        eulerAggregationVault.gulp();
        skip(eulerAggregationVault.INTEREST_SMEAR()); // make sure smear has passed
        eulerAggregationVault.updateInterestAccrued();

        assertEq(eulerAggregationVault.totalAssets(), eulerAggregationVault.totalAssetsAllocatable());
    }

    // total allocation points should be equal to the sum of the allocation points of all strategies.
    function invariant_totalAllocationPoints() public view {
        address withdrawalQueueAddr = eulerAggregationVault.withdrawalQueue();

        (address[] memory withdrawalQueueArray, uint256 withdrawalQueueLength) =
            IWithdrawalQueue(withdrawalQueueAddr).getWithdrawalQueueArray();

        uint256 expectedTotalAllocationpoints;
        expectedTotalAllocationpoints += (eulerAggregationVault.getStrategy(address(0))).allocationPoints;
        for (uint256 i; i < withdrawalQueueLength; i++) {
            expectedTotalAllocationpoints +=
                (eulerAggregationVault.getStrategy(withdrawalQueueArray[i])).allocationPoints;
        }

        assertEq(eulerAggregationVault.totalAllocationPoints(), expectedTotalAllocationpoints);
    }

    // Every strategy in the withdrawal queue should have an allocation points > 0.
    function invariant_withdrawalQueueStrategiesAllocationPoints() public view {
        address withdrawalQueueAddr = eulerAggregationVault.withdrawalQueue();

        (address[] memory withdrawalQueueArray, uint256 withdrawalQueueLength) =
            IWithdrawalQueue(withdrawalQueueAddr).getWithdrawalQueueArray();

        for (uint256 i; i < withdrawalQueueLength; i++) {
            assertGt(eulerAggregationVault.getStrategy(withdrawalQueueArray[i]).allocationPoints, 0);
        }
    }

    // If `total allocation points - cash reserve allocation points == 0`(no strategy added), the withdrawal queue length should be zero.
    // Else, the length should be greater than zero.
    function invariant_withdrawalQueue() public view {
        address withdrawalQueueAddr = eulerAggregationVault.withdrawalQueue();

        (, uint256 withdrawalQueueLength) = IWithdrawalQueue(withdrawalQueueAddr).getWithdrawalQueueArray();

        uint256 cashReserveAllocationPoints = (eulerAggregationVault.getStrategy(address(0))).allocationPoints;

        if (eulerAggregationVault.totalAllocationPoints() - cashReserveAllocationPoints == 0) {
            assertEq(withdrawalQueueLength, 0);
        } else {
            assertGt(withdrawalQueueLength, 0);
        }
    }

    // total allocated amount should always be equal the sum of allocated amount in all the strategies.
    function invariant_totalAllocated() public view {
        address withdrawalQueueAddr = eulerAggregationVault.withdrawalQueue();

        (address[] memory withdrawalQueueArray, uint256 withdrawalQueueLength) =
            IWithdrawalQueue(withdrawalQueueAddr).getWithdrawalQueueArray();

        uint256 aggregatedAllocatedAmount;
        for (uint256 i; i < withdrawalQueueLength; i++) {
            aggregatedAllocatedAmount += (eulerAggregationVault.getStrategy(withdrawalQueueArray[i])).allocated;
        }

        assertEq(eulerAggregationVault.totalAllocated(), aggregatedAllocatedAmount);
    }

    // Balance of a certain fee recipient should always be equal to the ghost tracking variable.
    function invariant_performanceFee() public view {
        for (uint256 i; i < eulerAggregationVaultHandler.ghostFeeRecipientsLength(); i++) {
            address feeRecipient = eulerAggregationVaultHandler.ghost_feeRecipients(i);

            assertEq(
                assetTST.balanceOf(feeRecipient),
                eulerAggregationVaultHandler.ghost_accumulatedPerformanceFeePerRecipient(feeRecipient)
            );
        }
    }

    // the interest left should always be greater or equal current interest accrued value.
    function invariant_interestLeft() public view {
        EulerAggregationVault.AggregationVaultSavingRate memory aggregationVaultSavingRate =
            eulerAggregationVault.getAggregationVaultSavingRate();
        uint256 accruedInterest = eulerAggregationVault.interestAccrued();
        assertGe(aggregationVaultSavingRate.interestLeft, accruedInterest);
    }

    function invariant_cashReserveStrategyCap() public view {
        assertEq(eulerAggregationVault.getStrategy(address(0)).cap, 0);
    }

    function _deployOtherStrategies() private {
        eTSTsecond = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount))
        );
        eTSTthird = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount))
        );
        eTSTforth = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount))
        );
        eTSTfifth = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount))
        );
        eTSTsixth = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount))
        );
    }
}
