// Based on Reentrancy.spec in SiloVault spec

import "summaries/Math.spec";

using EulerEarnHarness as EulerEarnHarness;

methods {
    // because these rules only depend on the call structure we heavily summarize 
    // by making all action just nondeterministic returns
    // for functions that perform trusted external calls we additionally call 
    // ignoreExternalCall() that sets the guard ignoreCall to true, avoiding the next hooked ext. call.
    function _.deposit(uint256, address) external => uintTrustedExternalCall() expect (uint256);
    function _.withdraw(uint256, address, address) external => uintTrustedExternalCall() expect (uint256);
    function _.redeem(uint256, address, address) external => uintTrustedExternalCall() expect (uint256);
    function _.approve(address, uint256) external => boolTrustedExternalCall() expect (bool);
    function _.approve(address, address, uint160, uint48) external => boolTrustedExternalCall() expect (bool);
    function _.transfer(address, uint256) external => boolTrustedExternalCall() expect bool;
    function _.transferFrom(address, address, uint256) external => boolTrustedExternalCall() expect bool;
    function SafeERC20Permit2Lib.forceApproveMaxWithPermit2(address,address,address) internal => voidTrustedExternalCall();
    function SafeERC20Permit2Lib.revokeApprovalWithPermit2(address,address,address) internal => voidTrustedExternalCall();
    function SafeERC20Permit2Lib.safeTransferFromWithPermit2(address, address, address, uint256, address) internal => voidTrustedExternalCall();
    function SafeERC20.safeTransfer(address,address,uint256) internal => voidTrustedExternalCall();
    function SafeERC20.safeTransferFrom(address,address,address,uint256) internal => voidTrustedExternalCall();

    function _.balanceOf(address) external => uintNoCall() expect uint256;
    function _.previewRedeem(uint256) external => uintNoCall() expect uint256;
    function _.convertToAssets(uint256) external => uintNoCall() expect (uint256);
    function _.asset() external => addressNoCall() expect address;
    function _.permit2Address() external => addressNoCall() expect address;
    function _.isStrategyAllowed(address) external => boolNoCall() expect bool;
    function _.maxWithdraw(address) external => uintNoCall() expect uint;
    function _.maxDeposit(address) external => uintNoCall() expect uint;
}

persistent ghost bool ignoredCall;
persistent ghost bool hasCall;

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (ignoredCall) {
        // Ignore calls to tokens and Morpho markets as they are trusted (they have gone through a timelock).
        ignoredCall = false;
    } else {
        hasCall = true;
    }
}


function ignoreExternalCall() {
    ignoredCall = true;
}

function uintTrustedExternalCall() returns uint256 {
    ignoreExternalCall();
    uint256 value;
    return value;
}

function uintNoCall() returns uint256 {
    uint256 value;
    return value;
}

function boolTrustedExternalCall() returns bool {
    ignoreExternalCall();
    bool value;
    return value;
}

function boolNoCall() returns bool {
    bool value;
    return value;
}

function addressTrustedExternalCall() returns address {
    ignoreExternalCall();
    address value;
    return value;
}

function addressNoCall() returns address {
    address value;
    return value;
}

function voidTrustedExternalCall() {
    ignoreExternalCall();
    return;
}

function voidNoCall() {
    return;
}


// Check that there are no untrusted external calls, ensuring notably reentrancy safety.
rule reentrancySafe(method f, env e, calldataarg data)
    filtered {
        f -> (f.contract == currentContract)
    }
{
    // Set up the initial state.
    require !ignoredCall && !hasCall;
    f(e,data);
    assert !hasCall;
}