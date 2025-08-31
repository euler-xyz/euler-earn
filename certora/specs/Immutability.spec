// Based on Immutability.spec in SiloVault spec

persistent ghost bool delegateCall;

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    delegateCall = true;
}

// Check that the contract is truly immutable.
rule noDelegateCalls(method f, env e, calldataarg data)
    filtered {
        f -> (f.contract == currentContract)
    }
{
    // Set up the initial state.
    require !delegateCall;
    f(e,data);
    assert !delegateCall;
}