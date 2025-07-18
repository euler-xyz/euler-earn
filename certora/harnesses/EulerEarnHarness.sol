// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import "../../src/EulerEarn.sol";
import "../../src/libraries/ConstantsLib.sol";

contract EulerEarnHarness is EulerEarn {
    constructor(
        address owner,
        address evc,
        address permit2,
        uint256 initialTimelock,
        address _asset,
        string memory __name,
        string memory __symbol
    ) EulerEarn(owner, evc, permit2, initialTimelock, _asset, __name, __symbol) {}
    
    function fees() public view returns (uint256) {
        uint256 feeShares;
        (feeShares, , ) = _accruedFeeAndAssets();
        return feeShares;
    }

    function wad() public view returns (uint256) {
        return WAD;
    }

    function virtualAmount() public view returns (uint256) {
        return ConstantsLib.VIRTUAL_AMOUNT;
    }

    function realTotalAssets() public view returns (uint256) {
        uint256 realTotalAssets;
        for (uint256 i; i < withdrawQueue.length; ++i) {
            IERC4626 id = withdrawQueue[i];
            realTotalAssets += _expectedSupplyAssets(id);
        }
        return realTotalAssets;
    }

    function msgSender() public view returns (address) {
        return _msgSender();
    }
    
    function pendingTimelock_() external view returns (PendingUint136 memory) {
        return pendingTimelock;
    }

    function pendingGuardian_() external view returns (PendingAddress memory) {
        return pendingGuardian;
    }

    function pendingCap_(IERC4626 id) external view returns (PendingUint136 memory) {
        return pendingCap[id];
    }

    function minTimelock() external pure returns (uint256) {
        return ConstantsLib.POST_INITIALIZATION_MIN_TIMELOCK;
    }

    function maxTimelock() external pure returns (uint256) {
        return ConstantsLib.MAX_TIMELOCK;
    }

    function maxQueueLength() external pure returns (uint256) {
        return ConstantsLib.MAX_QUEUE_LENGTH;
    }

    function maxFee() external pure returns (uint256) {
        return ConstantsLib.MAX_FEE;
    }

    function config_(IERC4626 id) external view returns (MarketConfig memory) {
        return config[id];
    }

    function supplyQGetAt(uint256 index) external view returns (IERC4626)
    {
        return supplyQueue[index];
    }

    function supplyQLength() external view returns (uint256)
    {
        return supplyQueue.length;
    }

    function withdrawQGetAt(uint256 index) external view returns (IERC4626)
    {
        return withdrawQueue[index];
    }

    function withdrawQLength() external view returns (uint256)
    {
        return withdrawQueue.length;
    }

        function nextGuardianUpdateTime() external view returns (uint256 nextTime) {
        nextTime = block.timestamp + timelock;

        if (pendingTimelock.validAt != 0) {
            nextTime = Math.min(nextTime, pendingTimelock.validAt + pendingTimelock.value);
        }

        uint256 validAt = pendingGuardian.validAt;
        if (validAt != 0) nextTime = Math.min(nextTime, validAt);
    }

    function nextCapIncreaseTime(IERC4626 id) external view returns (uint256 nextTime) {
        nextTime = block.timestamp + timelock;

        if (pendingTimelock.validAt != 0) {
            nextTime = Math.min(nextTime, pendingTimelock.validAt + pendingTimelock.value);
        }

        uint256 validAt = pendingCap[id].validAt;
        if (validAt != 0) nextTime = Math.min(nextTime, validAt);
    }

    function nextTimelockDecreaseTime() external view returns (uint256 nextTime) {
        nextTime = block.timestamp + timelock;

        if (pendingTimelock.validAt != 0) nextTime = Math.min(nextTime, pendingTimelock.validAt);
    }

    function nextRemovableTime(IERC4626 id) external view returns (uint256 nextTime) {
        nextTime = block.timestamp + timelock;

        if (pendingTimelock.validAt != 0) {
            nextTime = Math.min(nextTime, pendingTimelock.validAt + pendingTimelock.value);
        }

        uint256 removableAt = config[id].removableAt;
        if (removableAt != 0) nextTime = Math.min(nextTime, removableAt);
    }

    function getVaultAsset(IERC4626 id) external view returns (address asset) {
        return id.asset();
    }

    function reentrancyGuardEntered() external view returns (bool) {
        return _reentrancyGuardEntered();
    }

    function msgSenderOnlyEVCAccountOwner() external returns (address) {
        return _msgSenderOnlyEVCAccountOwner();
    }

    function isStrategyAllowedHarness(IERC4626 id) external returns (bool) {
        return IEulerEarnFactory(creator).isStrategyAllowed(address(id));
    }

}