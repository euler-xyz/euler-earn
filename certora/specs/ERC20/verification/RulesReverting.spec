import "../specs/ERC20Revert.spec";

/// @TODO Add more revert conditions.
rule transferRevertsForInsufficientBalance(address token, address from, address to) {
    uint256 timestamp;
    uint256 amount;

    uint256 balance_sender_pre = balanceOfCVL(token, timestamp, from);
    require amount > balance_sender_pre;
    bool success = transferCVL@withrevert(token, timestamp, from, to, amount);
    bool reverted = lastReverted;

    assert reverted;
    satisfy reverted;
}

/// @TODO Add more revert conditions.
rule transferFromRevertsForInsufficientBalance(address token, address from, address to, address spender) {
    uint256 timestamp;
    uint256 amount;

    uint256 balance_sender_pre = balanceOfCVL(token, timestamp, from);
    require amount > balance_sender_pre;
    bool success = transferFromCVL@withrevert(token, timestamp, spender, from, to, amount);
    bool reverted = lastReverted;

    assert reverted;
    satisfy reverted;
}