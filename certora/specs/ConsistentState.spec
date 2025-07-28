// Based on ConsistentStates.spec, TokenApproval.spec, lastUpdated.spec in SiloVault spec

import "Timelock.spec";

methods {
    function asset() external returns(address) envfree;
    function feeRecipient() external returns address envfree;
    function getVaultAsset(address) external returns address envfree;
    function ERC20Helper.allowance(address, address, address) external returns (uint256) envfree;
    function ERC20Helper.totalSupply(address) external returns (uint256) envfree;
    function ERC20Helper.safeTransferFrom(address,address,address,uint256) external envfree;
    function owner() external returns(address) envfree;
    function curator() external returns(address) envfree;
    function isAllocator(address target) external returns(bool) envfree;
    function permit2Address() external returns address envfree;
}

function hasCuratorRole(address user) returns bool {
    return user == owner() || user == curator();
}

function hasAllocatorRole(address user) returns bool {
    return user == owner() || user == curator() || isAllocator(user);
}

function hasGuardianRole(address user) returns bool {
    return user == owner() || user == guardian();
}

// Check that the fee cannot accrue to an unset fee recipient
// Verified
invariant noFeeToUnsetFeeRecipient()
    feeRecipient() == 0 => fee() == 0;

function hasSupplyCapIsEnabled(address market) returns bool {
    EulerEarnHarness.MarketConfig config = config_(market);

    return config.cap > 0 => config.enabled;
}

// Check that having a positive supply cap implies that the market is enabled.
// This invariant is useful to conclude that markets that are not enabled cannot be interacted with (notably for reallocate).
// Verified
invariant supplyCapIsEnabled(address market)
    hasSupplyCapIsEnabled(market);

function hasPendingSupplyCapHasConsistentAsset(address market) returns bool {
    return pendingCap_(market).validAt > 0 => getVaultAsset(market) == asset();
}

// Check that there can only be pending caps on markets where the loan asset is the asset of the vault
// Verified
invariant pendingSupplyCapHasConsistentAsset(address market)
    hasPendingSupplyCapHasConsistentAsset(market);

function isEnabledHasConsistentAsset(address market) returns bool {
    return config_(market).enabled => getVaultAsset(market) == asset();
}

// Check that having a positive cap implies that the loan asset is the asset of the vault.
// Verified
invariant enabledHasConsistentAsset(address market)
    isEnabledHasConsistentAsset(market)
{ preserved acceptCap(address _market) with (env e) {
    requireInvariant pendingSupplyCapHasConsistentAsset(market);
    require e.block.timestamp > 0;
  }
}

function hasSupplyCapIsNotMarkedForRemoval(address market) returns bool {
    EulerEarnHarness.MarketConfig config = config_(market);

    return config.cap > 0 => config.removableAt == 0;
}

// title Check that a market with a positive cap cannot be marked for removal.
// Verified
invariant supplyCapIsNotMarkedForRemoval(address market)
    hasSupplyCapIsNotMarkedForRemoval(market);

function isNotEnabledIsNotMarkedForRemoval(address market) returns bool {
    EulerEarnHarness.MarketConfig config = config_(market);

    return !config.enabled => config.removableAt == 0;
}

// Check that a non-enabled market cannot be marked for removal.
// Verified
invariant notEnabledIsNotMarkedForRemoval(address market)
    isNotEnabledIsNotMarkedForRemoval(market);

// Check that a market with a pending cap cannot be marked for removal.
// Verified
invariant pendingCapIsNotMarkedForRemoval(address market)
    pendingCap_(market).validAt > 0 => config_(market).removableAt == 0;

// Check that any new market in the supply queue necessarily has a positive cap.
// Verified
rule newSupplyQueueEnsuresPositiveCap(env e, address[] newSupplyQueue)
{
    uint256 i;

    setSupplyQueue(e, newSupplyQueue);

    address market = supplyQueue(i);

    assert config_(market).cap > 0;
}

//The following two rules are from TokenApproval.spec in Silo and caught bugs in Silo.

// violated after fix.
invariant noCapThenNoApproval(address market)
    config_(market).cap == 0 => ERC20Helper.allowance(asset(), currentContract, market) == 0
    {
    preserved acceptCap(address id) with (env e) {
        // not sure all of these assumptions are necessary but all are legitimate.
        require market != permit2Address();
        require msgSender(e) != currentContract; 
        requireInvariant pendingCapIsUint136(id);
        requireInvariant enabledHasPositiveRank(id);
        requireInvariant supplyCapIsEnabled(id);
        requireInvariant withdrawRankCorrect(id);
        requireInvariant noBadPendingCap(id);
        requireInvariant noCapThenNoApproval(id);
        requireInvariant pendingCapIsUint136(market);
        requireInvariant enabledHasPositiveRank(market);
        requireInvariant supplyCapIsEnabled(market);
        requireInvariant withdrawRankCorrect(market);
        requireInvariant noBadPendingCap(market);
        requireInvariant noCapThenNoApproval(market);
    }
    preserved with (env e) {
        require msgSender(e) != currentContract; 
        requireInvariant pendingCapIsUint136(market);
        requireInvariant noBadPendingCap(market);
        requireInvariant supplyCapIsEnabled(market);
    }
    }

// violated after fix.
invariant notInWithdrawQThenNoApproval(address market)
    withdrawRank(market) == 0 => ERC20Helper.allowance(asset(), currentContract, market) == 0
    {
    preserved with (env e) {
        require market != permit2Address();
        require msgSender(e) != currentContract; 
        requireInvariant pendingCapIsUint136(market);
        requireInvariant enabledHasPositiveRank(market);
        requireInvariant supplyCapIsEnabled(market);
        requireInvariant withdrawRankCorrect(market);
        requireInvariant noBadPendingCap(market);
        requireInvariant noCapThenNoApproval(market);
    }
}