//Based on rules from metamorpho v1.1 - https://github.com/morpho-org/metamorpho-v1.1/blob/main/certora/specs/LostAssetsNoLink.spec

import "Range.spec";

methods {
    function name() external returns string envfree;
    function symbol() external returns string envfree;
    function decimals() external returns uint8 envfree;
    function asset() external returns address envfree;
    function fees() external returns uint256 envfree;
    function lostAssets() external returns uint256 envfree;
    function lastTotalAssets() external returns uint256 envfree;
    function realTotalAssets() external returns uint256 envfree;
    function fee() external returns uint96 envfree;
    function wad() external returns uint256 envfree;
    function virtualAmount() external returns uint256 envfree;

    function totalSupply() external returns uint256 envfree;
    function balanceOf(address) external returns uint256 envfree;

    function approve(address,uint256) external returns bool;
    function deposit(uint256,address) external;
    function mint(uint256,address) external;
    function withdraw(uint256,address,address) external;
    function redeem(uint256,address,address) external;

    function totalAssets() external returns uint256 envfree;
    function convertToShares(uint256) external returns uint256 envfree;
    function convertToAssets(uint256) external returns uint256 envfree;
    function previewDeposit(uint256) external returns uint256 envfree;
    function previewMint(uint256) external returns uint256 envfree;
    function previewWithdraw(uint256) external returns uint256 envfree;
    function previewRedeem(uint256) external returns uint256 envfree;

    function maxDeposit(address) external returns uint256 envfree;
    function maxMint(address) external returns uint256 envfree;
    function maxWithdraw(address) external returns uint256 envfree;
    function maxRedeem(address) external returns uint256 envfree;

    function permit(address,address,uint256,uint256,uint8,bytes32,bytes32) external;
    function DOMAIN_SEPARATOR() external returns bytes32;

    function Token0.balanceOf(address) external returns uint256 envfree;
    function Token0.allowance(address, address) external returns uint256 envfree;
    function Token0.transferFrom(address,address,uint256) external returns bool;

    function allowance(address,address) external returns uint256 envfree;
}


// Check that the lost assets always increase.
rule lostAssetsIncreases(method f, env e, calldataarg args) 
    filtered { f -> !f.isView }
{
    uint256 lostAssetsBefore = lostAssets();

    f(e, args);

    uint256 lostAssetsAfter = lostAssets();

    assert lostAssetsBefore <= lostAssetsAfter;
}

// Check that the last total assets are smaller than the total assets.
rule lastTotalAssetsSmallerThanTotalAssets() {
    assert lastTotalAssets() <= totalAssets();
}

// Check that the last total assets increase except on withdrawal and redeem.
rule lastTotalAssetsIncreases(method f, env e, calldataarg args)
filtered {
    f -> f.selector != sig:withdraw(uint256, address, address).selector &&
        f.selector != sig:redeem(uint256, address, address).selector &&
        f.selector != sig:updateWithdrawQueue(uint256[]).selector &&
        !f.isView
}
{
    uint256 lastTotalAssetsBefore = lastTotalAssets();

    f(e, args);

    uint256 lastTotalAssetsAfter = lastTotalAssets();

    assert lastTotalAssetsBefore <= lastTotalAssetsAfter;
}

// Check that the last total assets decreases on withdraw.
rule lastTotalAssetsDecreasesCorrectlyOnWithdraw(env e, uint256 assets, address receiver, address owner) {
    uint256 lastTotalAssetsBefore = lastTotalAssets();

    withdraw(e, assets, receiver, owner);

    uint256 lastTotalAssetsAfter = lastTotalAssets();

    assert to_mathint(lastTotalAssetsAfter) >= lastTotalAssetsBefore - assets;
}

// Check that the last total assets decreases on redeem.
rule lastTotalAssetsDecreasesCorrectlyOnRedeem(env e, uint256 shares, address receiver, address owner) {
    uint256 lastTotalAssetsBefore = lastTotalAssets();

    uint256 assets = redeem(e, shares, receiver, owner);

    uint256 lastTotalAssetsAfter = lastTotalAssets();

    assert to_mathint(lastTotalAssetsAfter) >= lastTotalAssetsBefore - assets;
}

persistent ghost mathint sumBalances {
    init_state axiom sumBalances == 0;
}

hook Sload uint256 balance _balances[KEY address addr] {
    require sumBalances >= to_mathint(balance);
}

hook Sstore _balances[KEY address user] uint256 newBalance (uint256 oldBalance) {
    sumBalances = sumBalances + newBalance - oldBalance;
}

// Check that the total supply is the sum of the balances.
strong invariant totalIsSumBalances()
    to_mathint(totalSupply()) == sumBalances;

// Check that the share price does not decrease lower than the one at the last interaction.
rule sharePriceIncreases(method f, env e, calldataarg args) 
    filtered { f -> !f.isView }
{
    requireInvariant totalIsSumBalances();
    require assert_uint256(fee()) == 0;

    // We query them in a state in which the vault is sync.
    uint256 lastTotalAssetsBefore = lastTotalAssets();
    uint256 totalSupplyBefore = totalSupply();
    require totalSupplyBefore > 0;

    f(e, args);

    uint256 totalAssetsAfter = lastTotalAssets();
    uint256 totalSupplyAfter = totalSupply();
    require totalSupplyAfter > 0;

    // there is no decimals_offset here
    // uint256 decimalsOffset = assert_uint256(DECIMALS_OFFSET());
    // require decimalsOffset == 18;
    // instead we have virtual amount
    uint256 virtualAmount = virtualAmount();

    assert (lastTotalAssetsBefore + virtualAmount) * (totalSupplyAfter + virtualAmount) <= (totalAssetsAfter + virtualAmount) * (totalSupplyBefore + virtualAmount);
}