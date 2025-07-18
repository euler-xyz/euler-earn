import "../specs/ERC20Standard.spec";

rule transferIntegrity(address token, address from, address to) {
    uint256 timestamp;
    uint256 amount;

    uint256 balance_sender_pre = balanceOfCVL(token, timestamp, from);
    uint256 balance_receiver_pre = balanceOfCVL(token, timestamp, to);
        bool success = transferCVL(token, timestamp, from, to, amount);
        require success;
    uint256 balance_sender_post = balanceOfCVL(token, timestamp, from);
    uint256 balance_receiver_post = balanceOfCVL(token, timestamp, to);

    if(from != to) {
        assert balance_sender_pre - balance_sender_post == amount;
        assert balance_receiver_post - balance_receiver_pre == amount;
    } else {
        assert balance_receiver_post == balance_receiver_pre;
    }
}

rule transferThirdParty(address token, address from, address to, address other) {
    uint256 timestamp;
    uint256 amount;

    uint256 balance_other_pre = balanceOfCVL(token, timestamp, other);
        bool success = transferCVL(token, timestamp, from, to, amount);
        require success;
    uint256 balance_other_post = balanceOfCVL(token, timestamp, other);

    assert other != from && other != to => balance_other_pre == balance_other_post;
}

rule transferPreservesTotalSupply(address token, address from, address to) {
    uint256 timestamp;
    uint256 amount;

    uint256 balance_sender_pre = balanceOfCVL(token, timestamp, from);
    uint256 balance_receiver_pre = balanceOfCVL(token, timestamp, to);
    uint256 supply_pre = totalSupplyCVL(token, timestamp);
        bool success = transferCVL(token, timestamp, from, to, amount);
        require success;
    uint256 balance_sender_post = balanceOfCVL(token, timestamp, from);
    uint256 balance_receiver_post = balanceOfCVL(token, timestamp, to);
    uint256 supply_post = totalSupplyCVL(token, timestamp);

    assert from == to
        ? balance_sender_post <= supply_post
        : balance_sender_post + balance_receiver_post <= supply_post;
    assert supply_pre == supply_post;
}

rule transferFromIntegrity(address token, address from, address to, address spender) {
    uint256 timestamp;
    uint256 amount;

    uint256 balance_sender_pre = balanceOfCVL(token, timestamp, from);
    uint256 balance_receiver_pre = balanceOfCVL(token, timestamp, to);
    uint256 allowance_spender_pre = allowanceCVL(token, from, spender);
        bool success = transferFromCVL(token, timestamp, spender, from, to, amount);
        require success;
    uint256 balance_sender_post = balanceOfCVL(token, timestamp, from);
    uint256 balance_receiver_post = balanceOfCVL(token, timestamp, to);
    uint256 allowance_spender_post = allowanceCVL(token, from, spender);

    if(from != to) {
        assert balance_sender_pre - balance_sender_post == amount;
        assert balance_receiver_post - balance_receiver_pre == amount;
    } else {
        assert balance_receiver_post == balance_receiver_pre;
    }

    if(spender == from) {
        assert allowance_spender_pre == allowance_spender_post;
    } else {
        assert allowance_spender_post == allowance_spender_pre - amount;
    }
}

rule transferFromThirdParty(address token, address from, address to, address spender, address other) {
    uint256 timestamp;
    uint256 amount;

    uint256 balance_other_pre = balanceOfCVL(token, timestamp, other);
        bool success = transferFromCVL(token, timestamp, spender, from, to, amount);
        require success;
    uint256 balance_other_post = balanceOfCVL(token, timestamp, other);

    assert other != from && other != to => balance_other_pre == balance_other_post;
}

rule transferFromPreservesTotalSupply(address token, address from, address to, address spender) {
    uint256 timestamp;
    uint256 amount;

    uint256 balance_sender_pre = balanceOfCVL(token, timestamp, from);
    uint256 balance_receiver_pre = balanceOfCVL(token, timestamp, to);
    uint256 supply_pre = totalSupplyCVL(token, timestamp);
        bool success = transferFromCVL(token, timestamp, spender, from, to, amount);
        require success;
    uint256 balance_sender_post = balanceOfCVL(token, timestamp, from);
    uint256 balance_receiver_post = balanceOfCVL(token, timestamp, to);
    uint256 supply_post = totalSupplyCVL(token, timestamp);

    assert from == to
        ? balance_sender_post <= supply_post
        : balance_sender_post + balance_receiver_post <= supply_post;
    assert supply_pre == supply_post;
}