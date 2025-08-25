import "../specs/summary_standard_reverting.spec";

using Test as Test;

rule reverting_ERC20_summary(address token) {
    env e;
    address account = e.msg.sender;
    require e.msg.value == 0;
    
    uint256 balance_pre = Test.balanceByToken(e, token, Test);
        address recipient; require recipient != Test;
        uint256 amount;
        bool success = transferSuccess(token, Test, recipient, amount);
        Test.transferByToken@withrevert(e, token, recipient, amount);
        bool transfer_reverted = lastReverted;
    uint256 balance_post = Test.balanceByToken(e, token, Test);

    assert !transfer_reverted => balance_post == balance_pre - amount;
    assert !transfer_reverted => success;
    assert transfer_reverted => balance_post == balance_pre;
    satisfy transfer_reverted;
}