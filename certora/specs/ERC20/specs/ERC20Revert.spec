import "./ERC20Storage.spec";

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Summarizations                                                                                 
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

function totalSupplyCVL(address token, uint256 timestamp) returns uint256
{
    require token != NATIVE();
    return supplyByToken[token];
}

function transferCVL(address token, uint256 timestamp, address from, address to, uint256 amount) returns bool 
{
    require sumOfPairLessEqualThanSupply(token, from, to);
    return transferCVLStandard(token, from, to, amount);
}

function transferFromCVL(address token, uint256 timestamp, address spender, address from, address to, uint256 amount) returns bool 
{
    require sumOfPairLessEqualThanSupply(token, from, to);
    return transferFromCVLStandard(token, spender, from, to, amount);
}

function approveCVL(address token, address account, address spender, uint256 amount) returns bool {
    if(!approveSuccess(token, account, spender)) {
        revert("Invalid accounts");
    }
    allowanceByToken[token][account][spender] = amount;
    return true;
}

function balanceOfCVL(address token, uint256 timestamp, address account) returns uint256 {
    if(!_validToken(token)) {
        revert("Invalid token");
    }
    require balanceByToken[token][account] <= supplyByToken[token];
    return balanceByToken[token][account];
}

function allowanceCVL(address token, address account, address spender) returns uint256 {
    require token != NATIVE();
    return allowanceByToken[token][account][spender];
}

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Function implementations                                                                                 
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

function transferFromCVLStandard(address token, address spender, address from, address to, uint256 amount) returns bool {
    if(!hasAllowance(token, spender, from, amount)) {
        revert("Insufficient allowance");
    }
    //require spender != from => allowanceByToken[token][from][spender] >= amount;
    //if (allowanceByToken[token][from][spender] < amount) return false;
    if(spender != from) {
        allowanceByToken[token][from][spender] = assert_uint256(allowanceByToken[token][from][spender] - amount);
    }
    bool success = transferCVLStandard(token, from, to, amount);
    
    return success;
}

function transferCVLStandard(address token, address from, address to, uint256 amount) returns bool {
    if(!transferSuccess(token, from, to, amount)) {
        revert("Invalid transfer");
    }
    balanceByToken[token][from] = assert_uint256(balanceByToken[token][from] - amount);
    balanceByToken[token][to] = assert_uint256(balanceByToken[token][to] + amount);  // We neglect overflows.
    return true;
}

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Function success conditions                                                                                 
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

function transferFromSuccess(address token, address spender, address from, address to, uint256 amount) returns bool {
    return transferSuccess(token, from, to, amount) && hasAllowance(token, spender, from, amount);
}

function hasAllowance(address token, address spender, address from, uint256 amount) returns bool {
    return from != spender => allowanceByToken[token][from][spender] >= amount;
}

function transferSuccess(address token, address from, address to, uint256 amount) returns bool {
    return balanceByToken[token][from] >= amount &&
        balanceByToken[token][to] + amount <= max_uint256 && 
        from !=0 && to != 0 &&
        _validToken(token);
}

function approveSuccess(address token, address owner, address spender) returns bool {
    return owner != 0 && spender != 0 && _validToken(token);
}

function _validToken(address token) returns bool {
    return token != NATIVE();
}