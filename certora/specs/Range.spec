// Based on Range.spec in SiloVault spec
 
import "setup/dispatching_EulerEarn.spec";
import "summaries/Math.spec";

methods {
    function timelock() external returns(uint256) envfree;
    function supplyQueueLength() external returns(uint256) envfree;
    function withdrawQueueLength() external returns(uint256) envfree;
    function fee() external returns(uint96) envfree;
    function pendingTimelock_() external returns(EulerEarnHarness.PendingUint136) envfree;
    function minTimelock() external returns(uint256) envfree;
    function maxTimelock() external returns(uint256) envfree;
    function maxQueueLength() external returns(uint256) envfree;
    function maxFee() external returns(uint256) envfree;
    function pendingCap_(address) external returns(EulerEarnHarness.PendingUint136) envfree;
}

//Verified
invariant pendingTimelockInRange()
    pendingTimelock_().validAt != 0 =>
        assert_uint256(pendingTimelock_().value) <= maxTimelock() &&
        assert_uint256(pendingTimelock_().value) >= minTimelock();

//Verified -- in Euler timelock can be initiated at 0 like in metamorpho v1.1 (and unlike Silo)
invariant timelockInRange()
    (timelock() <= maxTimelock() && timelock() >= minTimelock()) || timelock() == 0
    {
        preserved {
            requireInvariant pendingTimelockInRange();
        }
    }

//Verified
invariant feeInRange()
    assert_uint256(fee()) <= maxFee();

//Verified
invariant supplyQueueLengthInRange()
    supplyQueueLength() <= maxQueueLength();

//Verified
invariant withdrawQueueLengthInRange()
    withdrawQueueLength() <= maxQueueLength();