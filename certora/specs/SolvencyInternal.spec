import "./EulerEarnERC4626.spec";

ghost uint256 totalSupplyGhost;
ghost uint256 assetsInGhost;
ghost uint256 totalAssetsAfterWithdrawStrategy;

methods {
    function EulerEarn.HOOK_after_withdrawStrategy(uint256 assets) internal => CVL_after_withdrawStrategy(assets);
}

// Hook summaries that serve as lemmas for the solvencyInInternalWithdraw rule 
// this is only useful if run with multi_assert_check = true 
function CVL_after_withdrawStrategy(uint256 assetsIn) {
    // There is some bug with the summaries (see ticket -- so I am using asstsInGhost instead of assetsIn input)

    // not sure about these still -- need to think
    assert totalSupply() == totalSupplyGhost,
    "total supply does not change"; //verified 
    assert Token0.balanceOf(currentContract) == assetsInGhost, 
    "after withdraw stategy the assets are moved to Euler"; // verified
    uint256 totalAssetsNow = totalAssets();
    assert totalAssetsNow + Token0.balanceOf(currentContract) >= totalSupply(), 
    "The sum of assets moved to Euler + totalAssets in vaults >= totalSupply"; //verified
    totalAssetsAfterWithdrawStrategy = totalAssetsNow;
}

// Verified https://prover.certora.com/output/5771024/455e0433202940aebcd4aa94b939561e/
rule propertiesAfterAccrue() {
    require totalAssets() >= totalSupply() + fees();
    env e;
    _accrueInterest(e);
    assert fees() == 0; 
    assert totalAssets() >= totalSupply() + fees();
}

// verified https://prover.certora.com/output/5771024/d1f58762c7934808b936bd1a41fb15d9/ (most revent proof with less approximations)
rule solvencyInInternalWithdraw() {
    // simulating the internal _withdraw in a call from the external withdraw
    env e;
    address caller;
    address receiver;
    address owner;
    uint256 assets;
    uint256 shares;
    safeAssumptions(e); 

    require withdrawQueueLength() == 1; 
    address withdrawQueueFirstVault = withdrawQGetAt(0);
    
    require caller != withdrawQueueFirstVault;
    require receiver != withdrawQueueFirstVault;
    require owner != withdrawQueueFirstVault;
    require receiver != currentContract; 
    require caller != currentContract;
    require owner != currentContract;
    require currentContract != withdrawQueueFirstVault;

    uint256 totalAssetsPre; 
    uint256 feesPre;
    uint256 lostAssetsPre;
    uint256 totalSupplyPre = totalSupply();
    (feesPre,totalAssetsPre,lostAssetsPre) =  _accruedFeeAndAssets(e); // 6 non-linear ops 
    require totalSupplyGhost == totalSupplyPre;
    require assetsInGhost == assets;

    uint256 lastTotalAssetsPre = lastTotalAssets();
    require totalAssetsPre >= totalSupplyPre + feesPre, "solvent before";
    require lastTotalAssetsPre == totalAssetsPre, "_withdraw is called after _accrueInterest";
    assert feesPre == 0; // verified

    bool assetSharesRelationInWithdraw = ( shares == _convertToSharesWithTotals(e,assets, totalSupplyPre, lastTotalAssetsPre, Math.Rounding.Ceil) ); // 2 non-linear ops
    bool assetSharesRelationInRedeem = ( assets == _convertToAssetsWithTotals(e,shares, totalSupplyPre, lastTotalAssetsPre, Math.Rounding.Floor)); // 2 non-linear ops
    require assetSharesRelationInWithdraw || assetSharesRelationInRedeem,
        "internal withdraw is called either in the external withdraw or the external redeem";

    assert shares <= assets; // verified

    _withdraw(e,caller,receiver,owner,assets,shares); // 22 non-linear ops -> cvlDispatchMaxWithdraw - 4, cvlDispatchPreviewRedeem - 4, CVL_after_withdrawStrategy - 6 

    uint256 totalAssetsPost; 
    uint256 feesPost;
    uint256 lostAssetsPost;
    uint256 totalSupplyPost = totalSupply();
    (feesPost,totalAssetsPost,lostAssetsPost) =  _accruedFeeAndAssets(e); // 6 non-linear ops 
    uint256 lastTotalAssetsPost = lastTotalAssets(); 
    
    assert totalAssetsPost == totalAssetsAfterWithdrawStrategy; 
    assert totalSupplyPost == assert_uint256(totalSupplyPre - shares); 
    assert Token0.balanceOf(currentContract) == 0; 
    assert lastTotalAssetsPost == assert_uint256(lastTotalAssetsPre - assets); 
    uint256 totalInterest = assert_uint256(totalAssetsPost-lastTotalAssetsPost); 
    uint256 feeAssets = cvlMulDiv(totalInterest,fee(), wad()); 
    assert feeAssets <= totalInterest; 
    assert assert_uint256(totalAssetsPost-feeAssets) >= totalSupplyPost; 
    assert require_uint256(assert_uint256(totalAssetsPost-feeAssets)+virtualAmount()) >= require_uint256(totalSupplyPost+virtualAmount());
    assert feesPost <= feeAssets;
    assert feesPost <= totalInterest;
    assert totalAssetsPost >= totalSupplyPost + feesPost, "solvent after"; 
}


rule solvencyInInternalDeposit() {
    // simulating the internal _deposit in a call from the external deposit
    env e;
    address caller;
    address receiver;
    uint256 assets;
    uint256 shares;
    safeAssumptions(e);

    uint256 totalAssetsPre; 
    uint256 feesPre;
    uint256 lostAssetsPre;
    uint256 totalSupplyPre = totalSupply();
    (feesPre,totalAssetsPre,lostAssetsPre) =  _accruedFeeAndAssets(e);
    
    uint256 lastTotalAssetsPre = lastTotalAssets();
    require totalAssetsPre >= totalSupplyPre + feesPre, "solvent before";
    require lastTotalAssetsPre == totalAssetsPre, "_deposit is called after _accrueInterest";
    
    require shares == _convertToSharesWithTotals(e,assets, totalSupplyPre, lastTotalAssetsPre, Math.Rounding.Floor);

    _deposit(e,caller,receiver,assets,shares);

    uint256 totalAssetsPost; 
    uint256 feesPost;
    uint256 lostAssetsPost;
    uint256 totalSupplyPost = totalSupply();
    (feesPost,totalAssetsPost,lostAssetsPost) =  _accruedFeeAndAssets(e);
    
    assert totalAssetsPost >= totalSupplyPost + feesPost, "solvent after";
}
