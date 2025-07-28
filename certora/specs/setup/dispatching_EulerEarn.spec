import "./vaults_summaries_EulerEarn.spec";

methods {
function _.approve(address,uint256) external => DISPATCHER(true);
function _.approve(address,address,uint160,uint48) external => DISPATCHER(true);
function _.transferFrom(address,address,uint256) external => DISPATCHER(true);
function _.redeem(uint256,address,address) external => DISPATCHER(true);
function _.allowance(address,address) external => DISPATCHER(true);
function _.transfer(address,uint256) external => DISPATCHER(true);
function _.balanceOf(address) external => DISPATCHER(true);
function _.isStrategyAllowed(address) external => DISPATCHER(true);
function _.permit2Address() external => DISPATCHER(true);
function _.getCurrentOnBehalfOfAccount(address) external => DISPATCHER(true);

// ERC4626 methods that are implemented in EulerEarn, but we mean to dispatch to the vaults when they're called within it
function _.previewRedeem(uint256 shares) external with (env e) => cvlDispatchPreviewRedeem(shares, calledContract, e) expect uint256;
function _.maxWithdraw(address owner) external with (env e) => cvlDispatchMaxWithdraw(owner, calledContract, e) expect uint256;
function _.withdraw(uint256 assets, address receiver, address owner) external with (env e) 
            => cvlDispatchWithdraw(assets, receiver, owner, calledContract, e) expect uint256;
function _.asset() external with (env e) => cvlDispatchAsset(calledContract, e) expect address;
function _.maxDeposit(address owner) external with (env e) => cvlDispatchMaxDeposit(owner, calledContract, e) expect uint256;
function _.deposit(uint256 assets, address receiver) external with (env e) 
            => cvlDispatchDeposit(assets, receiver, calledContract, e) expect uint256;

function _.checkVaultStatus() external => NONDET;
function _.checkAccountStatus(address, address[]) external => NONDET;
// comment this in (and possibly refine what to dispatch to) if you end up needing multicall in the rules
//unresolved external in EulerEarnHarness.multicall(bytes[]) => DISPATCH [ EulerEarnHarness._ ] default ASSERT_FALSE;

// might want to summarize this to something more deterministic if the asset decimals are relevant to the rules
function _._tryGetAssetDecimals(address) internal => NONDET;
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