// Based on Enabled.spec and DistinctIdentifiers.spec in SiloVault spec

import "PendingValues.spec";

methods
{
    function withdrawQueue(uint256) external returns(address) envfree; 
    function supplyQueue(uint256) external returns(address) envfree;
    function supplyQGetAt(uint256) external returns (address) envfree;
    function supplyQLength() external returns (uint256) envfree;   
    function withdrawQGetAt(uint256) external returns (address) envfree;
    function withdrawQLength() external returns (uint256) envfree;   
    // these functions are ghost functions that come from the harness and simplify the verification  
    function withdrawRank(address) external returns(uint256) envfree;
    function deletedAt(address) external returns(uint256) envfree;
}

function isInWithdrawQueueIsEnabled(uint256 i) returns bool {
    if(i >= withdrawQueueLength()) return true;

    address market = withdrawQueue(i);

    return config_(market).enabled;
}
 
// Verified
invariant distinctIdentifiers(uint256 i, uint256 j)
    i != j => withdrawQueue(i) != withdrawQueue(j)
{
    preserved updateWithdrawQueue(uint256[] indexes) with (env e) {
        requireInvariant distinctIdentifiers(indexes[i], indexes[j]);
    }
}

// Verified
invariant inWithdrawQueueIsEnabled(uint256 i)
    isInWithdrawQueueIsEnabled(i)
filtered {
    f -> f.selector != sig:updateWithdrawQueue(uint256[]).selector
}

// Verified
rule inWithdrawQueueIsEnabledPreservedUpdateWithdrawQueue(env e, uint256 i, uint256[] indexes) {
    uint256 j;
    require isInWithdrawQueueIsEnabled(indexes[i]);

    requireInvariant distinctIdentifiers(indexes[i], j);

    updateWithdrawQueue(e, indexes);

    address market = withdrawQueue(i);
    // Safe require because j is not otherwise constrained.
    // The ghost variable deletedAt is useful to make sure that markets are not permuted and deleted at the same time in updateWithdrawQueue.
    require j == deletedAt(market);

    assert isInWithdrawQueueIsEnabled(i);
}

function isWithdrawRankCorrect(address market) returns bool {
    uint256 rank = withdrawRank(market);

    if (rank == 0) return true;

    return withdrawQueue(assert_uint256(rank - 1)) == market;
}

// Verified
invariant withdrawRankCorrect(address market)
    isWithdrawRankCorrect(market);

// Verified
invariant enabledHasPositiveRank(address market)
    config_(market).enabled => withdrawRank(market) > 0;

// Verified
rule enabledIsInWithdrawQueue(address market) {
    require config_(market).enabled;

    requireInvariant enabledHasPositiveRank(market);
    requireInvariant withdrawRankCorrect(market);

    uint256 witness = assert_uint256(withdrawRank(market) - 1);
    assert withdrawQueue(witness) == market;
}

// Verified
invariant nonZeroCapHasPositiveRank(address market)
    config_(market).cap > 0 => withdrawRank(market) > 0
    {
    preserved {
        requireInvariant enabledHasPositiveRank(market); 
    }
}

function setSupplyQueueInputIsValid(address[] newSupplyQueue) returns bool
{
    uint256 i;
    require i < newSupplyQueue.length;
    uint184 someCap = config_(newSupplyQueue[i]).cap;
    bool result;
    require result == false => someCap == 0;
    return result;
}

// Verified
 rule setSupplyQueueRevertsOnInvalidInput(env e, address[] newSupplyQueue)
{
    setSupplyQueue@withrevert(e, newSupplyQueue);
    bool reverted = lastReverted;
    assert !setSupplyQueueInputIsValid(newSupplyQueue) => reverted;
}


// Verified
rule enabledIsInWithdrawalQueue(address market) {
    require config_(market).enabled;

    requireInvariant enabledHasPositiveRank(market);
    requireInvariant withdrawRankCorrect(market);

    uint256 witness = assert_uint256(withdrawRank(market) - 1);
    assert withdrawQueue(witness) == market;
}
