// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library EventsLib {
    /// @dev Shared.sol events
    event Gulp(uint256 interestLeft, uint256 interestSmearEnd);
    event DeductLoss(uint256 socializedAmount);
    event InterestUpdated(uint256 interestAccrued, uint256 interestLeft);

    /// @dev EulerEarnVault.sol events
    event AccruePerformanceFee(address indexed feeRecipient, uint256 yield, uint256 feeShares);
    event ExecuteHarvest(address indexed strategy, uint256 eulerEarnAssetsAmount, uint256 strategyAllocatedAmount);
    event Harvest(uint256 totalAllocated, uint256 totalYield, uint256 totalLoss);
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Rebalance(address indexed strategy, uint256 amountToRebalance, bool isDeposit);
    event Skim(address indexed token, address indexed recipient, uint256 amount);

    /// @dev Strategy.sol events
    event AdjustAllocationPoints(address indexed strategy, uint256 oldPoints, uint256 newPoints);
    event AddStrategy(address indexed strategy, uint256 allocationPoints);
    event RemoveStrategy(address indexed strategy);
    event SetStrategyCap(address indexed strategy, uint256 cap);
    event ToggleStrategyEmergencyStatus(address indexed strategy, bool isSetToEmergency);

    /// @dev Fee.sol events
    event SetFeeRecipient(address indexed oldRecipient, address indexed newRecipient);
    event SetPerformanceFee(uint96 oldFee, uint96 newFee);

    /// @dev Hooks.sol events
    event SetHooksConfig(address indexed hooksTarget, uint32 hookedFns);

    /// @dev Rewards.sol events
    event OptInStrategyRewards(address indexed strategy);
    event OptOutStrategyRewards(address indexed strategy);
    event EnableRewardForStrategy(address indexed strategy, address indexed reward);
    event DisableRewardForStrategy(address indexed strategy, address indexed reward, bool forfeitRecentReward);
    event EnableBalanceForwarder(address indexed user);
    event DisableBalanceForwarder(address indexed user);
    event ClaimStrategyReward(
        address indexed strategy, address indexed reward, address indexed recipient, bool forfeitRecentReward
    );

    /// @dev WithdrawalQueueModule.sol events
    event ReorderWithdrawalQueue(uint8 index1, uint8 index2);
}
