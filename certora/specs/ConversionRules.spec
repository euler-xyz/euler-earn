//Based on generic ERC4626 specitication: https://github.com/Certora/Examples/blob/master/DEFI/ERC4626/certora/specs/ERC4626.spec

import "./EulerEarnERC4626.spec";

methods {
    function _._accruedFeeAndAssets() internal with (env e) => _accruedFeeAndAssetsWithCaching(e) expect (uint256,uint256,uint256); // If this summary is used you need to call initCacheToZero at the start of every rule/invariant
    function expectedSupplyAssets(address) external returns uint256 envfree;
}

//summarization with caching -- doesn't approximate anything -- sometimes easier for the prover

ghost uint256 lastTotalAssetsCached;
ghost uint256 lostAssetsCached;
ghost uint96 feeCached;
ghost uint256 totalSupplyCached;
ghost address firstMarketCached;
ghost uint256 firstMarketExpectedSupplyAssetsCached;
ghost uint256 feeSharesCached; 
ghost uint256 newTotalAssetsCached;
ghost uint256 newLostAssetsCached;


function initCacheToZero() {
    feeSharesCached = 0;
    newTotalAssetsCached = 0;
    newLostAssetsCached = 0;
}

function _accruedFeeAndAssetsWithCaching(env e) returns (uint256,uint256,uint256) {
    uint256 lastTotalAssets = lastTotalAssets();
    uint256 lostAssets = lostAssets();
    uint96 fee = fee();
    uint256 totalSupply = totalSupply();
    address firstMarket = withdrawQGetAt(0);
    uint256 firstMarketExpectedSupplyAssets = expectedSupplyAssets(firstMarket);
    if (feeSharesCached == 0 && newTotalAssetsCached == 0 && newLostAssetsCached == 0) {
        lastTotalAssetsCached = lastTotalAssets;
        lostAssetsCached = lostAssets;
        feeCached = fee;
        totalSupplyCached = totalSupply;
        firstMarketCached = firstMarket;
        firstMarketExpectedSupplyAssetsCached = firstMarketExpectedSupplyAssets; 
        uint256 feeSharesRet;
        uint256 newTotalAssetsRet;
        uint256 newLostAssetsRet;
        (feeSharesRet, newTotalAssetsRet, newLostAssetsRet) = accruedFeeAndAssetsNotSummarized(e);
        feeSharesCached = feeSharesRet;
        newTotalAssetsCached = newTotalAssetsRet;
        newLostAssetsCached = newLostAssetsRet;
        return (feeSharesRet, newTotalAssetsRet, newLostAssetsRet);
    }
    else {
        if (
            lastTotalAssets == lastTotalAssetsCached &&
            lostAssets == lostAssetsCached &&
            fee == feeCached && 
            totalSupply == totalSupplyCached && 
            firstMarket == firstMarketCached &&
            firstMarketExpectedSupplyAssets == firstMarketExpectedSupplyAssetsCached 
        ) {
            uint256 feeSharesRet = feeSharesCached;
            uint256 newTotalAssetsRet = newTotalAssetsCached;
            uint256 newLostAssetsRet = newLostAssetsCached;
            return (feeSharesRet,newTotalAssetsRet,newLostAssetsRet);
        }
        else {
            lastTotalAssetsCached = lastTotalAssets;
            lostAssetsCached = lostAssets;
            feeCached = fee;
            totalSupplyCached = totalSupply;
            firstMarketCached = firstMarket;
            firstMarketExpectedSupplyAssetsCached = firstMarketExpectedSupplyAssets; 
            uint256 feeSharesRet;
            uint256 newTotalAssetsRet;
            uint256 newLostAssetsRet;
            (feeSharesRet, newTotalAssetsRet, newLostAssetsRet) = accruedFeeAndAssetsNotSummarized(e);
            feeSharesCached = feeSharesRet;
            newTotalAssetsCached = newTotalAssetsRet;
            newLostAssetsCached = newLostAssetsRet;
            return (feeSharesRet, newTotalAssetsRet, newLostAssetsRet);
        }
    }
}

// Verified 
rule conversionOfZero {
    initCacheToZero();
    uint256 convertZeroShares = convertToAssets(0);
    uint256 convertZeroAssets = convertToShares(0);

    assert convertZeroShares == 0,
        "converting zero shares must return zero assets";
    assert convertZeroAssets == 0,
        "converting zero assets must return zero shares";
}

// Verified with caching summary (see above) or with CONSTANT summary
rule convertToAssetsWeakAdditivity() {
    initCacheToZero();
    uint256 sharesA; uint256 sharesB;
    uint256 assetsA = convertToAssets(sharesA);
    uint256 assetsB = convertToAssets(sharesB);
    uint256 sharesAplusB = require_uint256(sharesA + sharesB);
    uint256 assetsAplusB = convertToAssets(sharesAplusB);
    require sharesA + sharesB < max_uint128
         && assetsA + assetsB < max_uint256
         && assetsAplusB < max_uint256;
    assert assetsA + assetsB <= assetsAplusB,
        "converting sharesA and sharesB to assets then summing them must yield a smaller or equal result to summing them then converting";
}

// Verified with caching summary
rule convertToSharesWeakAdditivity() {
    initCacheToZero();
    uint256 assetsA; uint256 assetsB;
    uint256 sharesA = convertToShares(assetsA);
    uint256 sharesB = convertToShares(assetsB);
    uint256 assetsAplusB = require_uint256(assetsA+assetsB);
    uint256 sharesAplusB = convertToShares(assetsAplusB);
    require assetsA + assetsB < max_uint128
         && sharesA + sharesB < max_uint256
         && sharesAplusB < max_uint256;
    assert sharesA + sharesB <= sharesAplusB,
        "converting assetsA and assetsB to shares then summing them must yield a smaller or equal result to summing them then converting";
}

// Verified
rule conversionWeakMonotonicity {
    initCacheToZero();
    uint256 smallerShares; uint256 largerShares;
    uint256 smallerAssets; uint256 largerAssets;

    assert smallerShares < largerShares => convertToAssets(smallerShares) <= convertToAssets(largerShares),
        "converting more shares must yield equal or greater assets";
    assert smallerAssets < largerAssets => convertToShares(smallerAssets) <= convertToShares(largerAssets),
        "converting more assets must yield equal or greater shares";
}

// Verified
rule conversionWeakIntegrity() {
    initCacheToZero();
    uint256 sharesOrAssets;
    assert convertToShares(convertToAssets(sharesOrAssets)) <= sharesOrAssets,
        "converting shares to assets then back to shares must return shares less than or equal to the original amount";
    assert convertToAssets(convertToShares(sharesOrAssets)) <= sharesOrAssets,
        "converting assets to shares then back to assets must return assets less than or equal to the original amount";
}
