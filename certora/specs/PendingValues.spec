// Based on PendingValues.spec in SiloVault spec
 
import "Range.spec";

methods {
    function pendingGuardian_() external returns(EulerEarnHarness.PendingAddress) envfree;
    function guardian() external returns(address) envfree;
    function pendingTimelock_() external returns(EulerEarnHarness.PendingUint136) envfree;
    function config_(address) external returns(EulerEarnHarness.MarketConfig) envfree; 
}

// Pending Values have two fields: value - the value to be set, and validAt - the minimal timestamp when it can be set.
// When the value valid and set we reset the pending value to 0 -- this is what is verified here.

// Verified
invariant noBadPendingTimelock()
    pendingTimelock_().validAt == 0 <=> pendingTimelock_().value == 0
{
    preserved with (env e) {
        requireInvariant timelockInRange();
        require e.block.timestamp < 2^63, "reasonable timestamp";
    }
}

// Verified
invariant smallerPendingTimelock()
    (assert_uint256(pendingTimelock_().value) < timelock()) || timelock() == 0
{
    preserved {
        requireInvariant pendingTimelockInRange();
        requireInvariant timelockInRange();
    }
}

// Verified
invariant noBadPendingCap(address market)
    pendingCap_(market).validAt == 0 <=> pendingCap_(market).value == 0
{
    preserved with (env e) {
        requireInvariant timelockInRange();
        require e.block.timestamp < 2^63, "reasonable timestamp";
        require e.block.timestamp > 0, "reasonable timestamp";
    }
}

function isGreaterPendingCap(address market) returns bool {
    uint192 pendingCapValue = pendingCap_(market).value;
    uint192 currentCapValue = config_(market).cap;

    return pendingCapValue != 0 => assert_uint256(pendingCapValue) > assert_uint256(currentCapValue);
}

// Verified
invariant greaterPendingCap(address market)
    isGreaterPendingCap(market);

// Verified
invariant noBadPendingGuardian()
    // Notice that address(0) is a valid value for a new guardian.
    pendingGuardian_().validAt == 0 => pendingGuardian_().value == 0
{
    preserved with (env e) {
        requireInvariant timelockInRange();
        require e.block.timestamp < 2^63, "reasonable timestamp";
        require e.block.timestamp > 0, "reasonable timestamp";
    }
}

// Verified
invariant differentPendingGuardian()
    pendingGuardian_().value != 0 => pendingGuardian_().value != guardian();