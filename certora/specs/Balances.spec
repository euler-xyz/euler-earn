// Aggregating different rules about balances from MetamorhpoV1,V1.1 and SiloVault.

import "summaries/Math.spec";

using VaultMock0 as v0;
using VaultMock1 as v1;
using EulerEarnHarness as EulerEarnHarness;
using ERC20Helper as ERC20Helper;

methods {
    // These summaries are defined in this file and include assertions - see below
    function _.deposit(uint256 assets, address receiver) external => summaryDeposit(calledContract, assets, receiver) expect (uint256) ALL;
    function _.withdraw(uint256 assets, address receiver, address spender) external => summaryWithdraw(calledContract, assets, receiver, spender) expect (uint256) ALL;
    function _.redeem(uint256 shares, address receiver, address spender) external => summaryRedeem(calledContract, shares, receiver, spender) expect (uint256) ALL;
    
    // Redefining dispatchers because we can't import the dispatching for withdraw.
    function _.totalSupply() external => DISPATCHER(true);
    function _.isStrategyAllowed(address) external => DISPATCHER(true);
    function _.permit2Address() external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.approve(address,address,uint160,uint48) external => DISPATCHER(true);
    function _.previewRedeem(uint256 shares) external with (env e) => cvlDispatchPreviewRedeem(shares, calledContract, e) expect uint256;
    function _.maxWithdraw(address owner) external with (env e) => cvlDispatchMaxWithdraw(owner, calledContract, e) expect uint256;
    function _.asset() external with (env e) => cvlDispatchAsset(calledContract, e) expect address;    
    function _.maxDeposit(address owner) external with (env e) => cvlDispatchMaxDeposit(owner, calledContract, e) expect uint256;
    function _.convertToAssets(uint256 shares) external with (env e)
                => cvlDispatchConvertToAssets(shares,calledContract,e) expect uint256;
    function _.convertToShares(uint256 shares) external with (env e)
                => cvlDispatchConvertToShares(shares,calledContract,e) expect uint256;

    function ERC20Helper.allowance(address, address, address) external returns (uint256) envfree;
    function ERC20Helper.totalSupply(address) external returns (uint256) envfree;
    function ERC20Helper.safeTransferFrom(address,address,address,uint256) external envfree;
    function ERC20Helper.balanceOf(address,address) external returns (uint256) envfree;    
    function asset() external returns (address) envfree;
    function config_(address) external returns(EulerEarnHarness.MarketConfig) envfree; 
    function supplyQGetAt(uint256) external returns (address) envfree;
    function supplyQLength() external returns (uint256) envfree;   
    function withdrawQGetAt(uint256) external returns (address) envfree;
    function withdrawQLength() external returns (uint256) envfree;   
    function getVaultAsset(address) external returns address envfree;
    function v0.getConvertToShares(address vault, uint256 assets) external returns(uint256) envfree;
    function v0.getConvertToAssets(address vault, uint256 shares) external returns(uint256) envfree;
}


function summaryDeposit(address market, uint256 assets, address receiver) returns uint256 {
    assert assets != 0;
    assert receiver == currentContract;
    require market != currentContract;

    require config_(market).cap > 0 => config_(market).enabled;
    require config_(market).enabled => getVaultAsset(market) == asset(), "invariant proven in ConsistentState.spec";
    
    ERC20Helper.safeTransferFrom(asset(), currentContract, market, assets);
    return v0.getConvertToShares(market, assets);
}

function summaryWithdraw(address market, uint256 assets, address receiver, address spender) returns uint256 {
    assert receiver == currentContract;
    assert spender == currentContract;
    require market != currentContract;

    // Safe require because it is verified in MarketInteractions.
    require config_(market).enabled;
    require config_(market).enabled => getVaultAsset(market) == asset(), "invariant proven in ConsistentState.spec";

    address asset = asset();

    ERC20Helper.safeTransferFrom(asset, market, currentContract, assets);

    return v0.getConvertToShares(market, assets);
}

function summaryRedeem(address market, uint256 shares, address receiver, address spender) returns uint256 {
    assert receiver == currentContract;
    assert spender == currentContract;
    require market != currentContract;

    // Safe require because it is verified in MarketInteractions.
    require config_(market).enabled;
    require config_(market).enabled => getVaultAsset(market) == asset(), "invariant proven in ConsistentState.spec";

    address asset = asset();
    uint256 assets = v0.getConvertToAssets(market, shares);

    ERC20Helper.safeTransferFrom(asset, market, currentContract, assets);

    return assets;
}

// Check balances change on deposit.
rule depositTokenChange(env e, uint256 assets, address receiver) {
    address asset = asset();

    // Trick to require that all the following addresses are different.
    require asset == 0x11;
    require currentContract == 0x12;
    require msgSender(e) == 0x13;

    //this together with loop_iter == 2 ensures that the markets don't call "deposit" on the Vault
    require supplyQGetAt(0) != msgSender(e);
    require supplyQGetAt(1) != msgSender(e);

    require ERC20Helper.balanceOf(asset, currentContract) + 
        ERC20Helper.balanceOf(asset, msgSender(e)) <= ERC20Helper.totalSupply(asset);

    uint256 balanceVaultBefore = ERC20Helper.balanceOf(asset, currentContract);
    uint256 balanceSenderBefore = ERC20Helper.balanceOf(asset, msgSender(e));
    deposit(e, assets, receiver);
    uint256 balanceVaultAfter = ERC20Helper.balanceOf(asset, currentContract);
    uint256 balanceSenderAfter = ERC20Helper.balanceOf(asset, msgSender(e));

    require balanceSenderBefore > balanceSenderAfter;

    assert balanceVaultAfter == balanceVaultBefore;
    assert assert_uint256(balanceSenderBefore - balanceSenderAfter) == assets;
    // add third assert that appeared in metamorpho.
}

// Check balance changes on withdraw.
rule withdrawTokenChange(env e, uint256 assets, address receiver, address owner) {
    address asset = asset();

    // Trick to require that all the following addresses are different.
    require asset == 0x11;
    require currentContract == 0x12;
    require receiver == 0x13;

    //this togehter with loop_iter == 2 ensures that the markets don't withdraw from the Vault
    require withdrawQGetAt(0) != msgSender(e);
    require withdrawQGetAt(1) != msgSender(e);

    //with loop_iter = 2 this shows whether the reveiver is among the markets in the WithdrawQ
    //(the caller of withdraw may set any receiver address so shouldn't discard this option)
    bool isReceiverAVault = receiver == withdrawQGetAt(0) || receiver == withdrawQGetAt(1);

    require ERC20Helper.balanceOf(asset, currentContract) + 
        ERC20Helper.balanceOf(asset, msgSender(e)) <= ERC20Helper.totalSupply(asset);
    require ERC20Helper.balanceOf(asset, currentContract) + 
        ERC20Helper.balanceOf(asset, receiver) <= ERC20Helper.totalSupply(asset);

    uint256 balanceVaultBefore = ERC20Helper.balanceOf(asset, currentContract);
    uint256 balanceReceiverBefore = ERC20Helper.balanceOf(asset, receiver);
    withdraw(e, assets, receiver, owner);
    uint256 balanceVaultAfter = ERC20Helper.balanceOf(asset, currentContract);
    uint256 balanceReceiverAfter = ERC20Helper.balanceOf(asset, receiver);

    // no overflow happened. 
    // Another way to ensure this is to require sum_i{balanceOf(withdrawQ[i])} + balanceOf(receiver) <= totalSupply
    require balanceReceiverAfter > balanceReceiverBefore;

    assert balanceVaultAfter == balanceVaultBefore;

    // the balance of receiver must change unless the receiver is one of the markets in the queue
    assert !isReceiverAVault => assert_uint256(balanceReceiverAfter - balanceReceiverBefore) == assets;
}

// Check that balances do not change on reallocate.
rule reallocateTokenChange(env e, EulerEarnHarness.MarketAllocation[] allocations) {
    address asset = asset();

    // Trick to require that all the following addresses are different.
    require asset == 0x11;
    require currentContract == 0x12;
    require msgSender(e) == 0x13;

    // this together with loop_iter = 2 ensures that markets in the withdrawQ are not Allocators and not SiloVault
    // based on enabledIsInWithdrawQueue
    require config_(allocations[0].id).enabled => allocations[0].id != msgSender(e);
    require config_(allocations[1].id).enabled => allocations[1].id != msgSender(e);
    require config_(allocations[0].id).enabled => allocations[0].id != currentContract;
    require config_(allocations[1].id).enabled => allocations[1].id != currentContract;

    uint256 balanceVaultBefore = ERC20Helper.balanceOf(asset, currentContract);
    uint256 balanceSenderBefore = ERC20Helper.balanceOf(asset, msgSender(e));
    reallocate(e, allocations);

    uint256 balanceVaultAfter = ERC20Helper.balanceOf(asset, currentContract);
    uint256 balanceSenderAfter = ERC20Helper.balanceOf(asset, msgSender(e));

    assert balanceVaultAfter == balanceVaultBefore;
    assert balanceSenderAfter == balanceSenderBefore;
}

ghost mathint vaultBalanceIncrease;
ghost mathint vaultBalanceDecrease;

// we just want to track the increases and decreases of SiloVault's balance
hook Sstore Token0._balances[KEY address user] uint256 newBalance (uint256 oldBalance) {
    if (user == EulerEarnHarness)
    {
        if (newBalance > oldBalance) vaultBalanceIncrease = vaultBalanceIncrease + newBalance - oldBalance;
        if (newBalance < oldBalance) vaultBalanceDecrease = vaultBalanceDecrease - newBalance + oldBalance;
    }
}

// Shows that SiloVault doesn't hoard the tokens, i.e., that it sends outs everything that it receives.
rule vaultBalanceNeutral(env e, method f)
    filtered { f -> !f.isView }
{
    require msgSender(e) != EulerEarnHarness;
    require msgSender(e) != v0;
    address receiver;
    require receiver != EulerEarnHarness;
    address asset = asset();
    uint256 balance_pre = ERC20Helper.balanceOf(asset, EulerEarnHarness);
    dispatchCall(e, f, receiver);
    uint256 balance_post = ERC20Helper.balanceOf(asset, EulerEarnHarness);
    
    assert balance_pre == balance_post; 
}

// a manual dispatcher that allows to constrain the receiver
function dispatchCall(env e, method f, address receiver)
{
    if (f.selector == sig:withdraw(uint256, address, address).selector)
    {
        uint256 _assets; address _owner;
        withdraw(e, _assets, receiver, _owner);
    }
    else if (f.selector == sig:redeem(uint256, address, address).selector)
    {
        uint256 _shares; address _owner;
        redeem(e, _shares, receiver, _owner);
    }
    else if (f.selector == sig:deposit(uint256, address).selector)
    {
        uint256 _assets;
        deposit(e, _assets, receiver);
    }
    else if (f.selector == sig:mint(uint256, address).selector)
    {
        uint256 _shares;
        mint(e, _shares, receiver);
    }
    else
    {
        calldataarg args;
        f(e, args);
    }
}

rule onlySpecicifiedMethodsCanDecreaseMarketBalance(env e, method f, address market)
{ 
    require msgSender(e) != currentContract;
    address asset = asset();

    // otherwise deposit overflows and decreases the balance
    require ERC20Helper.balanceOf(asset, currentContract) + 
        ERC20Helper.balanceOf(asset, msgSender(e)) <= ERC20Helper.totalSupply(asset);

    uint balanceBefore = ERC20Helper.balanceOf(asset, currentContract);
    calldataarg args;
    f(e, args);
    bool isAllowedToDecreaseBalance = 
        (f.selector == sig:withdraw(uint256, address, address).selector ||
        f.selector == sig:redeem(uint256, address, address).selector ||
        f.selector == sig:reallocate(EulerEarnHarness.MarketAllocation[]).selector);
    uint balanceAfter = ERC20Helper.balanceOf(asset, currentContract);
    assert balanceAfter < balanceBefore => isAllowedToDecreaseBalance;
}


function cvlDispatchPreviewRedeem(uint256 shares, address called, env e) returns uint256 {
    if(called == v0) {
        return v0.previewRedeem(e, shares);
    }
    if(called == v1) {
        return v1.previewRedeem(e, shares);
    }
    require false, "We assume external calls to ERC4626 methods are always on one of the vaults";
    return 0;
}

function cvlDispatchMaxWithdraw(address owner, address called, env e) returns uint256 {
    if(called == v0) {
        return v0.maxWithdraw(e, owner);
    }
    if(called == v1) {
        return v1.maxWithdraw(e, owner);
    }
    require false, "We assume external calls to ERC4626 methods are always on one of the vaults";
    return 0;
}



function cvlDispatchWithdraw(uint256 assets, address receiver, address owner, address called, env e) returns uint256 {
    if(called == v0) {
        return v0.withdraw(e, assets, receiver, owner);
    }
    if(called == v1) {
        return v1.withdraw(e, assets, receiver, owner);
    }
    require false, "We assume external calls to ERC4626 methods are always on one of the vaults";
    return 0;
}

function cvlDispatchAsset(address called, env e) returns address {
    if(called == v0) {
        return v0.asset(e);
    }
    if(called == v1) {
        return v1.asset(e);
    }
    require false, "We assume external calls to ERC4626 methods are always on one of the vaults";
    return 0;
}

function cvlDispatchMaxDeposit(address owner, address called, env e) returns uint256 {
    if(called == v0) {
        return v0.maxDeposit(e, owner);
    }
    if(called == v1) {
        return v1.maxDeposit(e, owner);
    }
    require false, "We assume external calls to ERC4626 methods are always on one of the vaults";
    return 0;
}

function cvlDispatchDeposit(uint256 assets, address receiver, address called, env e) returns uint256 {
    if(called == v0) {
        return v0.deposit(e, assets, receiver);
    }
    if(called == v1) {
        return v1.deposit(e, assets, receiver);
    }
    require false, "We assume external calls to ERC4626 methods are always on one of the vaults";
    return 0;
}

function cvlDispatchConvertToAssets(uint256 shares, address called, env e) returns uint256 {
    if(called == v0) {
        return v0.convertToAssets(e, shares);
    }
    if(called == v1) {
        return v1.convertToAssets(e, shares);
    }
    require false, "We assume external calls to ERC4626 methods are always on one of the vaults";
    return 0;
}

function cvlDispatchConvertToShares(uint256 shares, address called, env e) returns uint256 {
    if(called == v0) {
        return v0.convertToShares(e, shares);
    }
    if(called == v1) {
        return v1.convertToShares(e, shares);
    }
    require false, "We assume external calls to ERC4626 methods are always on one of the vaults";
    return 0;
}