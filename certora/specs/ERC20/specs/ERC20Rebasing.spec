import "./ERC20Storage.spec";

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Summarizations                                                                                 
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

function totalSupplyCVL(address token, uint256 timestamp) returns uint256
{
    require token != NATIVE();
    if(isRebasing(token)) {
        uint256 index = indexByToken[token][timestamp];
        uint256 amount = supplyByToken[token];
        return rawTokensToBalance(token, amount, index);
    } else {
        return supplyByToken[token]; 
    }
}

function transferCVL(address token, uint256 timestamp, address from, address to, uint256 amount) returns bool 
{
    require sumOfPairLessEqualThanSupply(token, from, to);
    if(isRebasing(token)) {
        return transferCVLRebasing(token, timestamp, from, to, amount);
    } else {
        return transferCVLStandard(token, from, to, amount);
    }
}

function transferFromCVL(address token, uint256 timestamp, address spender, address from, address to, uint256 amount) returns bool 
{
    require sumOfPairLessEqualThanSupply(token, from, to);
    if(isRebasing(token)) {
        return transferFromCVLRebasing(token, timestamp, spender, from, to, amount);
    } else {
        return transferFromCVLStandard(token, spender, from, to, amount);
    }
}

function balanceOfCVL(address token, uint256 timestamp, address account) returns uint256 {
    /// The share balance of any user cannot surpass than the total supply.
    require balanceByToken[token][account] <= supplyByToken[token];
    require token != NATIVE();
    if(isRebasing(token)) {
        uint256 index = indexByToken[token][timestamp];
        uint256 amount = balanceByToken[token][account];
        return rawTokensToBalance(token, amount, index);
    } else {
        return balanceByToken[token][account];
    }
}

function approveCVL(address token, address account, address spender, uint256 amount) returns bool {
    allowanceByToken[token][account][spender] = amount;
    return true;
}

function allowanceCVL(address token, address account, address spender) returns uint256 {
    require token != NATIVE();
    return allowanceByToken[token][account][spender];
}

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Definitions                                                                                 
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

/// Returns | x - y | <= tol.
definition equalUpTo(mathint x, mathint y, mathint tol) returns bool = x > y ? x - y <= tol : y - x <= tol;

/// Returns the approximate condition for preservation of balance after a single transfer operation.
/// diff - the change in balance
/// amount - the expected change (rounding-error-free)
/// index - the token index at time of the transfer
/// precision - the token precision.
/// Relative error bound
/// |diff - amount| <= 2*index / precision;
definition balanceTolerance(mathint diff, mathint amount, mathint index, mathint precision) returns bool = 
    equalUpTo(diff * precision, amount * precision, 2*index);   /// @dev Can we do better?

    
/// The tolerance for balance change in transfer operation
function amountsAllowedError(address token, uint256 timestamp, mathint amount_pre, mathint amount_post, mathint delta) returns bool
{
    return isRebasing(token) ?
        balanceTolerance(amount_post - amount_pre, delta, indexByToken[token][timestamp], tokenIndexPrecision(token))
        : amount_post - amount_pre == delta;
}

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Rebasing tokens ghosts                                                                                 
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

/// Returns the rebasing token index per each timestamp.
ghost mapping(address /* token */ => mapping(uint256 /* timestamp */ => uint256)) indexByToken;

/// Returns the precision of the index (10^decimals) [STATIC]
/// For instance:
/// WAD = 10^18
/// RAY = 10^27
persistent ghost tokenIndexPrecision(address /* token */) returns uint256 
{
    /// The precision is never zero!
    axiom forall address token. tokenIndexPrecision(token) != 0;
    /// One can choose here the possible options for the precision:
    axiom forall address token.
        tokenIndexPrecision(token) == DEFAULT_PRECISION()
        ||
        tokenIndexPrecision(token) == SECONDARY_PRECISION();
}

/// Returns the raw tokens given the balance and index. We assume rawTokens() rounds up.
/// Mocks rawTokens(balance) = ceil(balance * precision / index)
persistent ghost balanceToRawTokens(address,uint256,uint256) returns uint256
{
    axiom forall address token. forall uint256 balance. forall uint256 index.
        balance * tokenIndexPrecision(token) <= balanceToRawTokens(token, balance, index) * index
        &&
        balance * tokenIndexPrecision(token) - balanceToRawTokens(token, balance, index) * index + index > 0;

    axiom forall address token. forall uint256 balance1. forall uint256 balance2. forall uint256 index.
        balance1 < balance2 => balanceToRawTokens(token, balance1, index) <= balanceToRawTokens(token, balance2, index);

    axiom forall address token. forall uint256 index1. forall uint256 index2. forall uint256 balance.
        index1 < index2 => balanceToRawTokens(token, balance, index1) >= balanceToRawTokens(token, balance, index2);
}

/// Returns the balanceOf() given the amount and index. We assume balanceOf() rounds down.
/// Mocks balanceOf(user) = floor(raw_balance[user] * index / precision)
persistent ghost rawTokensToBalance(address,uint256,uint256) returns uint256
{
    axiom forall address token. forall uint256 amount. forall uint256 index.
        rawTokensToBalance(token, amount, index) <= MAX_SUPPLY();
        
    axiom forall address token. forall uint256 amount. forall uint256 index.
        amount * index - rawTokensToBalance(token, amount, index) * tokenIndexPrecision(token) < tokenIndexPrecision(token)
        &&
        amount * index >= rawTokensToBalance(token, amount, index) * tokenIndexPrecision(token);

    axiom forall address token. forall uint256 amount1. forall uint256 amount2. forall uint256 index.
        amount1 < amount2 => rawTokensToBalance(token, amount1, index) <= rawTokensToBalance(token, amount2, index);

    axiom forall address token. forall uint256 index1. forall uint256 index2. forall uint256 amount.
        index1 < index2 => rawTokensToBalance(token, amount, index1) <= rawTokensToBalance(token, amount, index2);

    /// Round-trip axiom
    axiom forall address token. forall uint256 amount. forall uint256 index.
        (balanceToRawTokens(token, rawTokensToBalance(token, amount, index), index) - amount) * index < index &&
        (balanceToRawTokens(token, rawTokensToBalance(token, amount, index), index) - amount) * index + tokenIndexPrecision(token) > 0;
}

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Function implementations                                                                                 
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

function transferFromCVLRebasing(address token, uint256 timestamp, address spender, address from, address to, uint256 amount) returns bool {
    require allowanceByToken[token][from][spender] >= amount;
    require spender != from => allowanceByToken[token][from][spender] >= amount;
    
    bool success = transferCVLRebasing(token, timestamp, from, to, amount);
    if(success && from != spender) {
        allowanceByToken[token][from][spender] = assert_uint256(allowanceByToken[token][from][spender] - amount);
    }
    return success;
}

function transferCVLRebasing(address token, uint256 timestamp, address from, address to, uint256 amount) returns bool {
    uint256 index = indexByToken[token][timestamp];

    mathint balanceFrom = rawTokensToBalance(token, balanceByToken[token][from], index) - amount;
    if(balanceFrom < 0) return false;    
    balanceByToken[token][from] = balanceToRawTokens(token, assert_uint256(balanceFrom), index);
    mathint balanceTo = rawTokensToBalance(token, balanceByToken[token][to], index) + amount;
    balanceByToken[token][to] = balanceToRawTokens(token, require_uint256(balanceTo), index);

    return true;
}

function transferFromCVLStandard(address token, address spender, address from, address to, uint256 amount) returns bool {
    require spender != from => allowanceByToken[token][from][spender] >= amount;
    //if (allowanceByToken[token][from][spender] < amount) return false;
    bool success = transferCVLStandard(token, from, to, amount);
    if(success && spender != from) {
        allowanceByToken[token][from][spender] = assert_uint256(allowanceByToken[token][from][spender] - amount);
    }
    return success;
}

function transferCVLStandard(address token, address from, address to, uint256 amount) returns bool {
    require balanceByToken[token][from] >= amount;
    //if(balanceByToken[token][from] < amount) return false;
    balanceByToken[token][from] = assert_uint256(balanceByToken[token][from] - amount);
    balanceByToken[token][to] = require_uint256(balanceByToken[token][to] + amount);  // We neglect overflows.
    return true;
}