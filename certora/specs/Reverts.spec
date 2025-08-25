// Based on Reverts.spec in SiloVault spec

import "ConsistentState.spec";

methods {
    function msgSender() external returns address;
    function reentrancyGuardEntered() external returns bool envfree;
    function msgSenderOnlyEVCAccountOwner() external returns address; 
    function isStrategyAllowedHarness(address) external returns bool envfree;
    function EVC() external returns address envfree;
}

function msgSenderOnlyEVCAccountOwnerReverted(env e) returns bool {
    msgSenderOnlyEVCAccountOwner@withrevert(e); 
    return lastReverted;
}

function msgSenderReverted(env e) returns bool {
    msgSender@withrevert(e); 
    return lastReverted;
}


//Check that vault can't have reentrancy lock on after interaction
// Verified
rule reentrancyLockFalseAfterInteraction (method f, env e, calldataarg args)
    filtered {
        f -> (f.contract == currentContract)
    }
{
    require !reentrancyGuardEntered();
    f(e, args);
    assert !reentrancyGuardEntered();
}


//Check all the revert conditions of the setCurator function.
// Verified
rule setCuratorRevertCondition(env e, address newCurator) {
    address msgSender = msgSender(e);
    address owner = owner();
    address oldCurator = curator();

    setCurator@withrevert(e, newCurator);

    assert lastReverted <=>
        e.msg.value != 0 ||
        msgSender != owner ||
        newCurator == oldCurator;
}


//Check all the revert conditions of the setIsAllocator function.
// Verified
rule setIsAllocatorRevertCondition(env e, address newAllocator, bool newIsAllocator) {
    address msgSender = msgSender(e);
    address owner = owner();
    bool wasAllocator = isAllocator(newAllocator);

    setIsAllocator@withrevert(e, newAllocator, newIsAllocator);

    assert lastReverted <=>
        e.msg.value != 0 ||
        msgSender != owner ||
        newIsAllocator == wasAllocator;
}


//Check the input validation conditions under which the setFee function reverts.
// This function can also revert if interest accrual reverts.
// Verified
rule setFeeInputValidation(env e, uint256 newFee) {
    address msgSender = msgSender(e);
    address owner = owner();
    uint96 oldFee = fee();
    address feeRecipient = feeRecipient();

    setFee@withrevert(e, newFee);

    assert e.msg.value != 0 ||
           msgSender != owner ||
           newFee == assert_uint256(oldFee) ||
           (newFee != 0 && feeRecipient == 0)
        => lastReverted;
}


//Check the input validation conditions under which the setFeeRecipient function reverts.
// This function can also revert if interest accrual reverts.
// Verified
rule setFeeRecipientInputValidation(env e, address newFeeRecipient) {
    address msgSender = msgSender(e);
    address owner = owner();
    uint96 fee = fee();
    address oldFeeRecipient = feeRecipient();

    setFeeRecipient@withrevert(e, newFeeRecipient);

    assert e.msg.value != 0 ||
           msgSender != owner ||
           newFeeRecipient == oldFeeRecipient ||
           (fee != 0 && newFeeRecipient == 0)
        => lastReverted;
}


//Check all the revert conditions of the submitGuardian function.
// Verified
rule submitGuardianRevertCondition(env e, address newGuardian) {
    address msgSender = msgSender(e);
    address owner = owner();
    address oldGuardian = guardian();
    uint64 pendingGuardianValidAt = pendingGuardian_().validAt;

    requireInvariant timelockInRange();
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    submitGuardian@withrevert(e, newGuardian);

    assert lastReverted <=>
        e.msg.value != 0 ||
        msgSender != owner ||
        newGuardian == oldGuardian ||
        pendingGuardianValidAt != 0;
}


//Check all the revert conditions of the submitCap function.
// Verified
rule submitCapRevertCondition(env e, address market, uint256 newSupplyCap) {
    address msgSender = msgSender(e);
    bool hasCuratorRole = hasCuratorRole(msgSender);
    bool msgSenderOnlyEVCAccountOwnerReverted = msgSenderOnlyEVCAccountOwnerReverted(e);
    address asset = asset();
    uint256 pendingCapValidAt = pendingCap_(market).validAt;
    EulerEarnHarness.MarketConfig config = config_(market);
    bool strategyAllowed = isStrategyAllowedHarness(market);
    bool reentrancyEntered = reentrancyGuardEntered();
    require market != currentContract, "Euler itself shouldn't be a market in Euler"; 

    requireInvariant timelockInRange();
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;
    requireInvariant supplyCapIsEnabled(market);

    submitCap@withrevert(e, market, newSupplyCap);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasCuratorRole ||
        getVaultAsset(market) != asset ||
        pendingCapValidAt != 0 ||
        config.removableAt != 0 ||
        newSupplyCap == assert_uint256(config.cap) ||
        (newSupplyCap == 2^184-1 && config.cap == 2^136-1 ) || //new revert condition due to their most recent fix.
        (newSupplyCap >= 2^136 && newSupplyCap != 2^184-1) || 
        msgSenderOnlyEVCAccountOwnerReverted ||
        reentrancyEntered ||
        !strategyAllowed;
}


//Check all the revert conditions of the submitMarketRemoval function.
// Verified

rule submitMarketRemovalRevertCondition(env e, address market) {
    address msgSender = msgSender(e);
    bool hasCuratorRole = hasCuratorRole(msgSender);
    uint256 pendingCapValidAt = pendingCap_(market).validAt;
    EulerEarnHarness.MarketConfig config = config_(market);
    bool msgSenderOnlyEVCAccountOwnerReverted = msgSenderOnlyEVCAccountOwnerReverted(e);

    requireInvariant timelockInRange();
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    submitMarketRemoval@withrevert(e, market);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasCuratorRole ||
        pendingCapValidAt != 0 ||
        config.cap != 0 ||
        !config.enabled ||
        config.removableAt != 0 ||
        msgSenderOnlyEVCAccountOwnerReverted;
}


//Check the input validation conditions under which the setSupplyQueue function reverts.
// There are no other condition under which this function reverts, but it cannot be expressed easily because of the encoding of the universal quantifier chosen.
// Verified

rule setSupplyQueueInputValidation(env e, address[] newSupplyQueue) {
    address msgSender = msgSender(e);
    bool hasAllocatorRole = hasAllocatorRole(msgSender);
    uint256 maxQueueLength = maxQueueLength();
    uint256 i;
    require i < newSupplyQueue.length;
    uint184 anyCap = config_(newSupplyQueue[i]).cap;
    bool msgSenderOnlyEVCAccountOwnerReverted = msgSenderOnlyEVCAccountOwnerReverted(e);

    setSupplyQueue@withrevert(e, newSupplyQueue);

    assert e.msg.value != 0 ||
           !hasAllocatorRole ||
           newSupplyQueue.length > maxQueueLength ||
           anyCap == 0 ||
           msgSenderOnlyEVCAccountOwnerReverted
        => lastReverted;
}


//Check the input validation conditions under which the updateWithdrawQueue function reverts.
// This function can also revert if a market is removed when it shouldn't:
//  - a removed market should have 0 supply cap
//  - a removed market should not have a pending cap
//  - a removed market should either have no supply or (be marked for forced removal and that timestamp has elapsed)
// Verified

rule updateWithdrawQueueInputValidation(env e, uint256[] indexes) {
    address msgSender = msgSender(e);
    bool hasAllocatorRole = hasAllocatorRole(msgSender);
    uint256 i;
    require i < indexes.length;
    uint256 j;
    require j < indexes.length;
    uint256 anyIndex = indexes[i];
    uint256 oldLength = withdrawQueueLength();
    uint256 anyOtherIndex = indexes[j];
    bool msgSenderOnlyEVCAccountOwnerReverted = msgSenderOnlyEVCAccountOwnerReverted(e);

    updateWithdrawQueue@withrevert(e, indexes);

    assert e.msg.value != 0 ||
           !hasAllocatorRole ||
           anyIndex > oldLength ||
           (i != j && anyOtherIndex == anyIndex) ||
           msgSenderOnlyEVCAccountOwnerReverted
        => lastReverted;
}


//Check the input validation conditions under which the reallocate function reverts.
// This function can also revert for non enabled markets and if the total withdrawn differs from the total supplied.
// Verified

rule reallocateInputValidation(env e, EulerEarnHarness.MarketAllocation[] allocations) {
    address msgSender = msgSender(e);
    bool hasAllocatorRole = hasAllocatorRole(msgSender);
    bool msgSenderOnlyEVCAccountOwnerReverted = msgSenderOnlyEVCAccountOwnerReverted(e);

    reallocate@withrevert(e, allocations);

    assert e.msg.value != 0 ||
           !hasAllocatorRole ||
           msgSenderOnlyEVCAccountOwnerReverted
        => lastReverted;
}


//Check all the revert conditions of the revokePendingTimelock function.
// Verified

rule revokePendingTimelockRevertCondition(env e) {
    address msgSender = msgSender(e);    
    bool hasGuardianRole = hasGuardianRole(msgSender);
    bool msgSenderOnlyEVCAccountOwnerReverted = msgSenderOnlyEVCAccountOwnerReverted(e);

    revokePendingTimelock@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasGuardianRole ||
        msgSenderOnlyEVCAccountOwnerReverted;
}


//Check all the revert conditions of the revokePendingGuardian function.
// Verified

rule revokePendingGuardianRevertCondition(env e) {
    address msgSender = msgSender(e);
    bool hasGuardianRole = hasGuardianRole(msgSender);
    bool msgSenderOnlyEVCAccountOwnerReverted = msgSenderOnlyEVCAccountOwnerReverted(e);

    revokePendingGuardian@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasGuardianRole ||
        msgSenderOnlyEVCAccountOwnerReverted;
}


//Check all the revert conditions of the revokePendingCap function.
// Verified

rule revokePendingCapRevertCondition(env e, address market) {
    address msgSender = msgSender(e);
    bool hasGuardianRole = hasGuardianRole(msgSender);
    bool hasCuratorRole = hasCuratorRole(msgSender);
    bool msgSenderOnlyEVCAccountOwnerReverted = msgSenderOnlyEVCAccountOwnerReverted(e);

    revokePendingCap@withrevert(e, market);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !(hasGuardianRole || hasCuratorRole) ||
        msgSenderOnlyEVCAccountOwnerReverted;
}


//Check all the revert conditions of the revokePendingMarketRemoval function.
// Verified

rule revokePendingMarketRemovalRevertCondition(env e, address market) {
    address msgSender = msgSender(e);
    bool hasGuardianRole = hasGuardianRole(msgSender);
    bool hasCuratorRole = hasCuratorRole(msgSender);
    bool msgSenderOnlyEVCAccountOwnerReverted = msgSenderOnlyEVCAccountOwnerReverted(e);

    revokePendingMarketRemoval@withrevert(e, market);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !(hasGuardianRole || hasCuratorRole) ||
        msgSenderOnlyEVCAccountOwnerReverted;
}


//Check all the revert conditions of the acceptTimelock function.
// Verified

rule acceptTimelockRevertCondition(env e) {
    uint256 pendingTimelockValidAt = pendingTimelock_().validAt;
    bool msgSenderReverted = msgSenderReverted(e);

    acceptTimelock@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        pendingTimelockValidAt == 0 ||
        pendingTimelockValidAt > e.block.timestamp ||
        msgSenderReverted;
}


//Check all the revert conditions of the acceptGuardian function.
// Verified

rule acceptGuardianRevertCondition(env e) {
    uint256 pendingGuardianValidAt = pendingGuardian_().validAt;
    bool msgSenderReverted = msgSenderReverted(e);

    acceptGuardian@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        pendingGuardianValidAt == 0 ||
        pendingGuardianValidAt > e.block.timestamp ||
        msgSenderReverted;
}


//Check the input validation conditions under which the acceptCap function reverts.
// This function can also revert if interest accrual reverts or if it would lead to growing the withdraw queue past the max length.
// Verified

rule acceptCapInputValidation(env e, address market) {
    uint256 pendingCapValidAt = pendingCap_(market).validAt;
    bool msgSenderReverted = msgSenderReverted(e);

    acceptCap@withrevert(e, market);

    assert e.msg.value != 0 ||
           pendingCapValidAt == 0 ||
           pendingCapValidAt > e.block.timestamp || 
           msgSenderReverted
        => lastReverted;
}
