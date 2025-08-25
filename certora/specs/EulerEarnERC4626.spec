//Based on generic ERC4626 specification: https://github.com/Certora/Examples/blob/master/DEFI/ERC4626/certora/specs/ERC4626.spec

import "setup/dispatchingWithoutVaultSummaries.spec";
import "summaries/Math.spec";
using Token0 as Token0;
using ERC20Helper as ERC20Helper;
using EthereumVaultConnector as EVC;

methods {
    function _._msgSender() internal with (env e) => e.msg.sender expect address; //ignoring EVC compatibility

     function SafeERC20.safeTransfer(address token,address to,uint256 value) internal with (env e) 
        => tokenTransferFromToCVL(e,token,calledContract,to,value); 
    // function EulerEarn.HOOK_after_accrueInterest() internal => CVL_after_accrueInterest();

    function EVC.getAccountOwner(address) external returns address envfree;
    function config_(address) external returns EulerEarnHarness.MarketConfig envfree; 
    function virtualAmount() external returns uint256 envfree;
    function permit2Address() external returns address envfree;
    function feeRecipient() external returns address envfree;
    function withdrawQGetAt(uint256) external returns address envfree;
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
    function withdrawQueueLength() external returns uint256 envfree;
    function ERC20Helper.totalSupply(address) external returns uint256 envfree;
    function totalSupply() external returns uint256 envfree;
    function balanceOf(address) external returns uint256 envfree;
    function reentrancyGuardEntered() external returns bool envfree;

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
    function maxFee() external returns uint256 envfree;
    function permit(address,address,uint256,uint256,uint8,bytes32,bytes32) external;
    function DOMAIN_SEPARATOR() external returns bytes32;
    function Token0.balanceOf(address) external returns uint256 envfree;
    function Token0.allowance(address, address) external returns uint256 envfree;
    function Token0.transferFrom(address,address,uint256) external returns bool;
    function allowance(address,address) external returns uint256 envfree;
}

function tokenTransferFromToCVL(env e,address token,address from, address to, uint256 value) {
    if (token == Token0) {
        Token0._transfer(e,from, to, value);
        return;
    }
    require false, "this should only be called on Token0";
}

function safeAssumptions(env e) {
    require currentContract != asset(); // Although this is not disallowed, we assume the contract's underlying asset is not the contract itself
    requireInvariant totalSupplyIsSumOfBalances();
    require msgSender(e) != currentContract;  // This is proved by rule noDynamicCalls
    require require_uint256(fee()) <= maxFee();
    requireInvariant configBalanceAndTotalSupply(withdrawQGetAt(0));   
    requireInvariant noAssetsOnEuler();
    
    uint256 fees;
    uint256 totalAssets; 
    uint256 lostAssets;
    uint256 totalSupply = totalSupply();
    (fees,totalAssets,lostAssets) =  _accruedFeeAndAssets(e);
    require totalAssets >= fees + totalSupply, "proven in TotalAssetsMoreThanSupplyAndFees - in different cases"; 
    require totalAssets <= 2^128, "reasonable value for totalAssets";
    require totalSupply <= 2^128, "reasonable value for totalSupply";
    require lostAssets <= 2^128, "reasonable value for lostAssets";
}

ghost mathint sumOfBalances {
    init_state axiom sumOfBalances == 0;
}

hook Sstore _balances[KEY address addy] uint256 newValue (uint256 oldValue)  {
    sumOfBalances = sumOfBalances + newValue - oldValue;
}

hook Sload uint256 val _balances[KEY address addy]  {
    require sumOfBalances >= val;
}

// Verified
invariant totalSupplyIsSumOfBalances()
    totalSupply() == sumOfBalances;


// Verified
invariant noAssetsOnEuler()
    Token0.balanceOf(currentContract) == 0
    {   
        preserved withdraw(uint256 assets, address receiver, address owner) with (env e) {
            require receiver != currentContract;
            require owner != currentContract;
            safeAssumptions(e);
        }
        preserved redeem(uint256 assets, address receiver, address owner) with (env e) {
            require receiver != currentContract;
            require owner != currentContract;
            safeAssumptions(e);
        }
        preserved with (env e) {
            safeAssumptions(e);
        }
    }

/// solvency properties.

function CVL_after_accrueInterest() {
    assert totalAssets() >= totalSupply() + fees();
}

invariant TotalAssetsMoreThanSupplyAndFees()
    totalAssets() >= totalSupply() + fees()
    //filter out withdraw, redeem, deposit, mint - those are proven in a different rule - solvency in Internal Withdraw
    filtered {
    f -> (f.selector != sig:withdraw(uint256,address,address).selector &&
          f.selector != sig:redeem(uint256,address,address).selector &&
          f.selector != sig:deposit(uint256,address).selector &&
          f.selector != sig:mint(uint256,address).selector)
    }
    {
        preserved updateWithdrawQueue(uint256[] indexes) with (env e) {
            safeAssumptions(e);
            require withdrawQueueLength() == 1;
            require indexes.length != 0;
        }
        preserved with (env e) {
            safeAssumptions(e);
            require withdrawQueueLength() == 1;
        }
    }

// Verified
rule underlyingCannotChange() 
{
    address originalAsset = asset();

    method f; env e; calldataarg args;
    f(e, args);

    address newAsset = asset();

    assert originalAsset == newAsset,
        "the underlying asset of a contract must not change";
}

// Verified -- not standard ERC4626 but specific to us, this is simple because config_(market).balance should equal market.balanceOf(currentContract)
invariant configBalanceAndTotalSupply(address market) 
    config_(market).balance <= ERC20Helper.totalSupply(market) 
    {
        preserved with(env e) {
            require msgSender(e) != currentContract;
            safeAssumptions(e);
        }
    }


// Verified on most recent verison (was violated before) https://prover.certora.com/output/5771024/75bb49eac8b34219bb9e177fcc25773a/
rule zeroDepositZeroShares(uint assets, address receiver){
    env e;

    uint shares = deposit(e,assets, receiver);

    assert shares == 0 <=> assets == 0;
}


// Verified https://prover.certora.com/output/5771024/9d68a0e5a30c454f9f0ca25cd10230f6/
rule redeemingAllValidity() { 
    address owner; 
    address feeRecipient = feeRecipient();
    require owner != feeRecipient;

    uint256 shares; require shares == balanceOf(owner);
    
    env e; safeAssumptions(e);
    redeem(e, shares, _, owner);
    uint256 ownerBalanceAfter = balanceOf(owner);
    assert ownerBalanceAfter == 0;
}

// Verified https://prover.certora.com/output/5771024/fdeec6302e9b429bb0b725f3d9fd22fe
invariant zeroAllowanceOnAssets(address user)
    // no alloownaces from current contract.
    Token0.allowance(currentContract, user) == 0 && currentContract.allowance(currentContract, user) == 0 {
        preserved with(env e) {
            require msgSender(e) != currentContract;
            safeAssumptions(e);
            require user != permit2Address(), "allownaces for permit2 behave differently.";
        }
    }

// Verified
rule onlyContributionMethodsReduceAssets(method f) {
    address user; require user != currentContract;
    uint256 userBalanceOfBefore = Token0.balanceOf(user);

    env e; 
    calldataarg args;
    safeAssumptions(e);

    f(e, args);

    uint256 userBalanceOfAfter = Token0.balanceOf(user);

    assert userBalanceOfBefore > userBalanceOfAfter =>
        (f.selector == sig:deposit(uint256,address).selector ||
         f.selector == sig:mint(uint256,address).selector ||
         f.contract == asset() || f.contract == currentContract),
        "a user's assets must not go down except on calls to contribution methods or calls directly to the asset.";
}