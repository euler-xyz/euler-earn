// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC4626, IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IEulerEarn} from "src/interfaces/IEulerEarn.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title EulerEarnAdminHandler
/// @notice Handler test contract for a set of actions
abstract contract EulerEarnAdminHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          SUBMIT                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function submitTimelock(uint256 _newTimelock, uint8 i) external {
        target = _getRandomEulerEarnVault(i);

        _before();
        IEulerEarn(target).submitTimelock(_newTimelock);
        _after();
    }

    function setFee(uint256 _newTimelock, uint8 i) external {
        target = _getRandomEulerEarnVault(i);

        _before();
        IEulerEarn(target).setFee(_newTimelock);
        _after();
    }

    function submitCap(uint256 _newSupplyCap, uint8 i, uint8 j) external {
        target = _getRandomEulerEarnVault(i);

        IERC4626 market = _getRandomMarket(j);

        _before();
        IEulerEarn(target).submitCap(market, _newSupplyCap);
        _after();
    }

    function submitMarketRemoval(uint8 i, uint8 j) external {
        target = _getRandomEulerEarnVault(i);

        IERC4626 market = _getRandomMarket(j);

        _before();
        IEulerEarn(target).submitMarketRemoval(market);
        _after();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          REVOKE                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function revokePendingTimelock(uint8 i) external {
        target = _getRandomEulerEarnVault(i);

        _before();
        IEulerEarn(target).revokePendingTimelock();
        _after();
    }

    function revokePendingCap(uint8 i, uint8 j) external {
        target = _getRandomEulerEarnVault(i);
        IERC4626 market = _getRandomMarket(j);

        _before();
        IEulerEarn(target).revokePendingCap(market);
        _after();
    }

    function revokePendingMarketRemoval(uint8 i, uint8 j) external {
        target = _getRandomEulerEarnVault(i);
        IERC4626 market = _getRandomMarket(j);

        _before();
        IEulerEarn(target).revokePendingMarketRemoval(market);
        _after();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          EXTERNAL                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function acceptTimelock(uint8 i) external {
        target = _getRandomEulerEarnVault(i);

        _before();
        IEulerEarn(target).acceptTimelock();
        _after();
    }

    function acceptCap(uint8 i, uint8 j) external {
        target = _getRandomEulerEarnVault(i);

        IERC4626 market = _getRandomMarket(i);

        _before();
        IEulerEarn(target).acceptCap(market);
        _after();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ALLOCATOR                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*     function setSupplyQueue(uint8 i) external {TODO uncomment when helpers are implemented back
        IERC4626[] memory _newSupplyQueue = _generateRandomMarketArray(i);

        vault.setSupplyQueue(_newSupplyQueue);

        uint256 supplyQueueLength = vault.supplyQueueLength();

        // HSPOST

        /// @dev QUEUES
        for (uint256 j; j < supplyQueueLength; j++) {
            assertGt(vault.config(vault.supplyQueue(j)).cap, 0, HSPOST_QUEUES_F);
        }
    } */

    /*     function updateWithdrawQueue(uint8[] memory _indexes, uint8 i) external {TODO uncomment when helpers are implemented back
        uint256[] memory _clampedIndexes = _clampIndexesArray(_indexes, i);

        vault.updateWithdrawQueue(_clampedIndexes);
    } */

    // TODO direct reallocate call ???

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*     function _generateRandomMarketArray(uint8 seed) internal returns (IERC4626[] memory) {
        uint256 randomLength = clampLe(seed, markets.length);

        IERC4626[] memory randomArray = new IERC4626[](randomLength);

        for (uint256 i; i < randomLength; i++) {
            randomArray[i] = IERC4626(markets[(uint256(seed) + i) % markets.length]);
        }

        assert(randomArray.length <= markets.length);

        return randomArray;
    }

    function _clampIndexesArray(uint8[] memory _indexes, uint8 seed) internal returns (uint256[] memory) {
        require(_indexes.length <= markets.length, "EulerEarnAdminHandler: indexes array too long");

        uint256 length = clampLe(seed, markets.length);

        uint256[] memory clampedIndexes = new uint256[](length);

        for (uint256 i; i < seed; i++) {
            clampedIndexes[i] = clampLt(seed, markets.length);
        }

        return clampedIndexes;
    } */
}
