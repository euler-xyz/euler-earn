// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces

// Libraries
import {Vm} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

// Utils
import {Actor} from "../utils/Actor.sol";
import {PropertiesConstants} from "../utils/PropertiesConstants.sol";
import {StdAsserts} from "../utils/StdAsserts.sol";

// Base
import {BaseStorage} from "./BaseStorage.t.sol";

import "forge-std/console.sol";

/// @notice Base contract for all test contracts extends BaseStorage
/// @dev Provides setup modifier and cheat code setup
/// @dev inherits Storage, Testing constants assertions and utils needed for testing
abstract contract BaseTest is BaseStorage, PropertiesConstants, StdAsserts, StdUtils {
    bool internal IS_TEST = true;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   ACTOR PROXY MECHANISM                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Actor proxy mechanism
    modifier setup() virtual {
        actor = actors[msg.sender];
        targetActor = address(actor);
        _;
        actor = Actor(payable(address(0)));
        targetActor = address(0);
    }

    /// @dev Solves medusa backward time warp issue
    modifier monotonicTimestamp() virtual {
        // Implement monotonic timestamp if needed
        _;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STRUCTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     CHEAT CODE SETUP                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Cheat code address, 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D.
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));

    /// @dev Virtual machine instance
    Vm internal constant vm = Vm(VM_ADDRESS);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _setTargetActor(address user) internal {
        targetActor = user;
    }

    /// @notice Get a random address
    function _makeAddr(string memory name) internal pure returns (address addr) {
        uint256 privateKey = uint256(keccak256(abi.encodePacked(name)));
        addr = vm.addr(privateKey);
    }

    /// @notice Helper function to deploy a contract from bytecode
    function deployFromBytecode(bytes memory bytecode) internal returns (address child) {
        assembly {
            child := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }

    function _getInterestAccruedFromCache() internal view returns (uint256) {
        (uint40 lastInterestUpdate, uint40 interestSmearingEnd, uint168 interestLeft) =
            eulerEulerEarnVault.getEulerEarnSavingRate();

        if (eulerEulerEarnVault.totalSupply() == 0) return 0;

        // If distribution ended, full amount is accrued
        if (block.timestamp >= interestLeft) {
            return interestLeft;
        }

        if (lastInterestUpdate == block.timestamp) {
            // If just updated return 0

            return 0;
        }

        // Else return what has accrued
        uint256 totalDuration = interestSmearingEnd - lastInterestUpdate;
        uint256 timePassed = block.timestamp - lastInterestUpdate;

        return interestLeft * timePassed / totalDuration;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  HELPERS: RANDOM GETTERS                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _getRandomStrategy(uint256 _i) internal view returns (address) {
        uint256 _strategyIndex = _i % strategies.length;
        return strategies[_strategyIndex];
    }

    /// @notice Get a random asset address
    function _getRandomAsset(uint256 _i) internal view returns (address) {
        uint256 _assetIndex = _i % baseAssets.length;
        return baseAssets[_assetIndex];
    }

    /// @notice Get a random actor proxy address
    function _getRandomActor(uint256 _i) internal view returns (address) {
        uint256 _actorIndex = _i % NUMBER_OF_ACTORS;
        return actorAddresses[_actorIndex];
    }
}
