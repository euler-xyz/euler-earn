// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Contracts
import {Invariants} from "./Invariants.t.sol";
import {Setup} from "./Setup.t.sol";

/*
 * Test suite that converts from  "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
contract CryticToFoundry is Invariants, Setup {
    CryticToFoundry Tester = this;

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

        // Initialize hook contracts
        _setUpHooks();

        /// @dev fixes the actor to the first user
        actor = actors[USER1];

        vm.warp(101007);
    }

    /// @dev Needed in order for foundry to recognise the contract as a test, faster debugging
    function testAux() public {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  POSTCONDITIONS REPLAY                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_redeemEchidna() public {
        this.addStrategy(50511606531911687419, 0);
        this.deposit(21, 0);
        this.rebalance(0, 0, 0);
        this.donateUnderlying(12, 0);
        this.harvest();
        this.mint(6254, 0);
        _delay(101007);
        this.setPerformanceFee(1012725796);
        this.simulateYieldAccrual(987897736, 0);
        this.redeem(5557, 0);
    }

    function test_updateInterestAccrued() public {
        this.donateUnderlying(1, 0);
        this.assert_ERC4626_WITHDRAW_INVARIANT_C();
        this.updateInterestAccrued();
    }

    function test_mintHSPOST_USER_D() public {
        this.donateUnderlying(39378, 0);
        this.ERC4626_roundtrip_invariantE(0);
        _delay(31);
        this.mint(1, 0);
    }

    function test_assert_ERC4626_WITHDRAW_INVARIANT_C() public {
        this.donateUnderlying(1213962, 0);
        this.mint(1e22, 0);
        this.simulateYieldAccrual(1, 0);
        this.addStrategy(1, 0);
        this.toggleStrategyEmergencyStatus(0);
        this.toggleStrategyEmergencyStatus(0);
        this.setPerformanceFee(4);
        _delay(1);
        this.simulateYieldAccrual(250244936486004518, 0);
    }

    function test_toggleStrategyEmergencyStatus() public {
        Tester.simulateYieldAccrual(1, 0);
        Tester.addStrategy(1, 0);
        Tester.toggleStrategyEmergencyStatus(0);
        Tester.toggleStrategyEmergencyStatus(0);
    }

    function test_depositEchidna() public {
        this.donateUnderlying(1460294, 0);
        this.assert_ERC4626_roundtrip_invariantG(0);
        _delay(1);
        this.deposit(1, 0);
    }

    function test_assert_ERC4626_REDEEM_INVARIANT_C() public {
        this.mint(20000, 0);
        this.addStrategy(1, 1);
        this.addStrategy(1, 0);
        _logStrategiesAllocation();
        this.adjustAllocationPoints(1007741998640599459404, 0);
        _logStrategiesAllocation();
        this.rebalance(0, 0, 0);
        _logStrategiesAllocation();
        this.simulateYieldAccrual(1, 1);
        this.rebalance(1, 0, 0);
        _logStrategiesAllocation();

        this.assert_ERC4626_REDEEM_INVARIANT_C();
    }

    function test_assert_ERC4626_roundtrip_invariantA() public {
        this.donateUnderlying(68, 0);
        this.ERC4626_roundtrip_invariantA(0);

        _delay(35693);
        this.ERC4626_roundtrip_invariantA(1);
    }

    function test_replayRedeem() public {
        Tester.mint(4370000, 0);
        Tester.donateUnderlying(1, 0);
        Tester.redeem(4370000, 0);
    }

    function test_replayWithdraw() public {
        Tester.mint(1, 0);
        Tester.donateUnderlying(1, 0);
        Tester.withdraw(1, 0);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     INVARIANTS REPLAY                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_echidna_INV_ASSETS_INVARIANTS_INV_ASSETS_A() public {
        Tester.simulateYieldAccrual(1, 0);
        assert_INV_ASSETS_A();
        Tester.addStrategy(1, 0);
        assert_INV_ASSETS_A();
        Tester.toggleStrategyEmergencyStatus(0);
        assert_INV_ASSETS_A();
        Tester.toggleStrategyEmergencyStatus(0);
        assert_INV_ASSETS_A();
    }

    function test_INV_ASSETS_INVARIANTS_1() public {
        Tester.donateUnderlying(1 ether, 0);
        Tester.simulateYieldAccrual(1 ether, 0);
        Tester.addStrategy(1, 0);
        Tester.toggleStrategyEmergencyStatus(0);
        Tester.toggleStrategyEmergencyStatus(0);
        _delay(2 weeks);
        console.log(block.timestamp);
        echidna_INV_ASSETS_INVARIANTS();
    }

    function test_echidna_INV_BASE_INVARIANTS() public {
        this.donateUnderlying(3633281, 0);
        this.assert_ERC4626_WITHDRAW_INVARIANT_C();
        _delay(1);
        this.assert_ERC4626_roundtrip_invariantH(2);
        echidna_INV_BASE_INVARIANTS();
    }

    function test_echidna_INV_STRATEGIES_INVARIANTS() public {
        this.addStrategy(1, 0);
        this.toggleStrategyEmergencyStatus(0);
        echidna_INV_STRATEGIES_INVARIANTS();
    }

    function test_echidna_INV_BASE_INVARIANTS5() public {
        this.addStrategy(501757585924425152950, 2);
        this.mint(3, 0);
        this.rebalance(2, 0, 0);
        this.toggleStrategyEmergencyStatus(2);
        echidna_INV_ASSETS_INVARIANTS();
    }

    function test_echidna_INV_ASSETS_INVARIANTS2() public {
        Tester.addStrategy(50098849964587092381, 0);
        Tester.deposit(21, 0);
        Tester.rebalance(0, 0, 0);
        Tester.donateUnderlying(1, 0);
        Tester.redeem(21, 0);

        assert_INV_ASSETS_A();
    }

    function test_replayDeposit() public {
        Tester.addStrategy(1, 0);
        Tester.mint(1, 0);
        Tester.donateUnderlying(177, 0);
        Tester.toggleStrategyEmergencyStatus(0);
        _delay(489);
        Tester.deposit(3, 0);
    }

    function test_replayMint() public {
        Tester.deposit(1, 0);
        Tester.donateUnderlying(410, 0);
        Tester.harvest();
        _delay(211);
        Tester.mint(2, 0);
        _delay(2110);
    }

    function test_replaytoggleStrategyEmergencyStatus() public {
        Tester.addStrategy(1, 0);
        Tester.donateUnderlying(1, 0);
        Tester.ERC4626_roundtrip_invariantF(0);
        _delay(1);
        Tester.toggleStrategyEmergencyStatus(0);
    }

    // Strategy cap allocation

    function test_replayHarvest() public {
        Tester.addStrategy(1, 0);
        Tester.simulateYieldAccrual(1, 0);
        Tester.setStrategyCap(1, 0);
        Tester.harvest();
    }

    function test_replayRebalance() public {
        Tester.addStrategy(1, 2);
        Tester.setStrategyCap(1, 2);
        Tester.simulateYieldAccrual(1, 2);
        Tester.rebalance(0, 0, 0);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 BROKEN INVARIANTS REPLAY                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

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

    function _logStrategiesAllocation() internal {
        console.log("Strategy 0: ", eulerEulerEarnVault.getStrategy(strategies[0]).allocated);
        console.log("Strategy 1: ", eulerEulerEarnVault.getStrategy(strategies[1]).allocated);
        console.log("Strategy 2: ", eulerEulerEarnVault.getStrategy(strategies[2]).allocated);
    }
}
