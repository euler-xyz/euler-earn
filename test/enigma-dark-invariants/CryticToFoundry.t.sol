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

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                               BROKEN POSTCONDITIONS REPLAY                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @dev Needed in order for foundry to recognise the contract as a test, faster debugging
    function testAux() public {}

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

    function test_assert_ERC4626_roundtrip_invariantB() public {
        this.donateUnderlying(597, 0);
        this.assert_ERC4626_roundtrip_invariantD(0);
        _delay(6100);
        this.assert_ERC4626_roundtrip_invariantB(2);
    }

    function test_assert_ERC4626_roundtrip_invariantE() public {
        this.donateUnderlying(13153, 0);
        this.harvest();
        _delay(276);
        this.assert_ERC4626_roundtrip_invariantE(2);
    }

    function test_assert_ERC4626_DEPOSIT_INVARIANT_C() public {
        this.addStrategy(4824480551761419311, 0);
        this.deposit(417, 0);
        this.rebalance(0, 0, 0);
        this.toggleStrategyEmergencyStatus(0);
        this.mint(1, 0);
        this.assert_ERC4626_DEPOSIT_INVARIANT_C();
    }

    function test_assert_ERC4626_REDEEM_INVARIANT_C() public {
        this.mint(2, 0);
        this.addStrategy(1, 1);
        this.addStrategy(1, 0);
        _logStrategiesAllocation();
        this.adjustAllocationPoints(1007741998640599459404, 0);
        _logStrategiesAllocation();
        this.rebalance(0, 0, 0);
        _logStrategiesAllocation();
        console.log("###################");
        this.simulateYieldAccrual(1, 1);
        this.rebalance(1, 0, 0);
        _logStrategiesAllocation();

        this.assert_ERC4626_REDEEM_INVARIANT_C();
    }

    function test_rebalanceEchidna() public {
        this.donateUnderlying(115806691264371466222864862475749781457799518246036164272, 0);
        this.addStrategy(1, 0);
        console.log("totalAssets: ", eulerEulerEarnVault.totalAssets());
        this.rebalance(0, 0, 0);
    }

    function test_updateInterestAccrued() public {
        this.donateUnderlying(1, 0);
        this.assert_ERC4626_WITHDRAW_INVARIANT_C();
        this.updateInterestAccrued();
    }

    function test_mintPostCondition() public {
        this.mint(1, 0);
    }

    function test_claimStrategyReward() public {
        this.rebalance(0, 0, 0);
    }

    function test_setStrategyCap() public {
        this.addStrategy(1, 0);
        this.toggleStrategyEmergencyStatus(0);
        this.simulateYieldAccrual(1, 0);
        this.toggleStrategyEmergencyStatus(0);
        this.setStrategyCap(1, 0);
    }

    function test_mintHSPOST_USER_D() public {
        this.donateUnderlying(39378, 0);
        this.assert_ERC4626_roundtrip_invariantE(0);
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
        this.assert_ERC4626_WITHDRAW_INVARIANT_C();
    }

    function test_assert_ERC4626_roundtrip_invariantF() public {
        //@audit-issue . I - 2
        this.donateUnderlying(2457159, 0);
        this.assert_ERC4626_WITHDRAW_INVARIANT_C();
        _delay(1);
        this.assert_ERC4626_roundtrip_invariantF(1);
    }

    function test_assert_ERC4626_roundtrip_invariantA() public {
        //@audit-issue . I - 2
        this.donateUnderlying(68, 0);
        this.assert_ERC4626_roundtrip_invariantA(0);
        _delay(35693);
        this.assert_ERC4626_roundtrip_invariantA(1);
    }

    function test_rebalance3() public {
        this.donateUnderlying(1, 0);
        console.log("defaultVarsBefore.lastInterestUpdate: ", defaultVarsBefore.lastInterestUpdate);
        this.rebalance(0, 0, 0);
        console.log("defaultVarsBefore.lastInterestUpdate: ", defaultVarsBefore.lastInterestUpdate);

        console.log("defaultVarsAfter.lastInterestUpdate: ", defaultVarsAfter.lastInterestUpdate);
    }

    function test_redeemHSPOST_USER_E() public {
        this.addStrategy(50242812395433680164, 0);
        this.deposit(21, 0);
        this.rebalance(0, 0, 0);
        _delay(88402);
        this.setPerformanceFee(1012725796);
        this.simulateYieldAccrual(987897736, 0);
        console.log("assetTST.balanceOf: ", assetTST.balanceOf(address(eulerEulerEarnVault)));
        this.redeem(0, 0);
    }

    function test_depositEchidna() public {
        this.donateUnderlying(1460294, 0);
        this.assert_ERC4626_roundtrip_invariantG(0);
        _delay(1);
        this.deposit(1, 0);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 BROKEN INVARIANTS REPLAY                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_echidna_INV_ASSETS_INVARIANTS_INV_ASSETS_A() public {
        this.simulateYieldAccrual(1, 0);
        assert_INV_ASSETS_A();
        this.addStrategy(1, 0);
        assert_INV_ASSETS_A();
        this.toggleStrategyEmergencyStatus(0);
        assert_INV_ASSETS_A();
        this.toggleStrategyEmergencyStatus(0);
        assert_INV_ASSETS_A();
    }

    function test_echidna_INV_ASSETS_INVARIANTS_INV_ASSETS_E() public {
        this.simulateYieldAccrual(1, 0);
        this.addStrategy(1, 0);
        this.toggleStrategyEmergencyStatus(0);
        this.toggleStrategyEmergencyStatus(0);
        echidna_INV_ASSETS_INVARIANTS();
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

    function _logStrategiesAllocation() internal {
        console.log("Strategy 0: ", eulerEulerEarnVault.getStrategy(strategies[0]).allocated);
        console.log("Strategy 1: ", eulerEulerEarnVault.getStrategy(strategies[1]).allocated);
        console.log("Strategy 2: ", eulerEulerEarnVault.getStrategy(strategies[2]).allocated);
    }
}
