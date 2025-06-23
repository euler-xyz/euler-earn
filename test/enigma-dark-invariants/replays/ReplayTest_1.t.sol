// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Contracts
import {Invariants} from "../Invariants.t.sol";
import {Setup} from "../Setup.t.sol";

// Utils
import {Actor} from "../utils/Actor.sol";

contract ReplayTest1 is Invariants, Setup {
    // Generated from Echidna reproducers

    // Target contract instance (you may need to adjust this)
    ReplayTest1 Tester = this;

    modifier setup() override {
        _;
    }

    function setUp() public {
        // Deploy protocol contracts
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();

        /// @dev fixes the actor to the first user
        actor = actors[USER1];
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   		REPLAY TESTS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function testAux() public {
        console.log("address(eTST)", address(eTST));
        console.log("address(eTST2)", address(eTST2));
        console.log("address(eTST3)", address(eTST3));
        console.log("address(idleVault)", address(idleVault));
        console.log("address(eulerEarn)", address(eulerEarn));
        console.log("address(eulerEarn2)", address(eulerEarn2));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Fast forward the time and set up an actor,
    /// @dev Use for ECHIDNA call-traces
    function _delay(uint256 _seconds) internal {
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up an actor
    function _setUpActor(address _origin) internal {
        actor = actors[_origin];
    }

    /// @notice Set up an actor and fast forward the time
    /// @dev Use for ECHIDNA call-traces
    function _setUpActorAndDelay(address _origin, uint256 _seconds) internal {
        actor = actors[_origin];
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up a specific block and actor
    function _setUpBlockAndActor(uint256 _block, address _user) internal {
        vm.roll(_block);
        actor = actors[_user];
    }

    /// @notice Set up a specific timestamp and actor
    function _setUpTimestampAndActor(uint256 _timestamp, address _user) internal {
        vm.warp(_timestamp);
        actor = actors[_user];
    }
}
