import "../specs/ERC4626.spec";
import "../../ERC20/specs/summary_standard.spec";

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ deposit() rules                                                                                
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

rule depositTokenTransferIntegrity(address token, uint256 assets) {
    uint256 timestamp;
    address sender;
    address receiver;
    address underlying = ERC4626Asset(token);

    uint256 balanceShare_receiver_pre = balanceOfCVL(token, timestamp, receiver);
    uint256 balanceToken_vault_pre = balanceOfCVL(underlying, timestamp, token);
        uint256 shares = depositCVL(token, timestamp, sender, assets, receiver);
    uint256 balanceShare_receiver_post = balanceOfCVL(token, timestamp, receiver);
    uint256 balanceToken_vault_post = balanceOfCVL(underlying, timestamp, token);

    assert balanceShare_receiver_post - balanceShare_receiver_pre == shares;
    assert sender != token => balanceToken_vault_post - balanceToken_vault_pre == assets;
    satisfy balanceShare_receiver_post != balanceShare_receiver_pre;
}

rule depositSharesMatchPreviewDeposit(address token, uint256 assets) {
    uint256 timestamp;
    address sender;
    address receiver;
    
    uint256 shares_preview = previewDepositCVL(token, assets);
    uint256 shares_real = depositCVL(token, _, _, assets, _);

    assert shares_preview == shares_real;
    satisfy shares_preview > 0;
}

rule depositIsSubAdditive(address token, uint256 assets1, uint256 assets2) {
    uint256 shares1 = previewDepositCVL(token, assets1);
    uint256 shares2 = previewDepositCVL(token, assets2);
    uint256 shares_sum = previewDepositCVL(token, require_uint256(assets1+assets2));

    assert shares1 + shares2 <= shares_sum;
    satisfy shares_sum > 0;
}

rule depositWithdrawRoundTripNoProfit(address token, uint256 assets) {
    address depositor;
    uint256 timestamp;
    uint256 sharesIn = depositCVL(token, timestamp, depositor, assets, depositor);
    uint256 sharesOut = withdrawCVL(token, timestamp, depositor, assets, depositor, depositor);

    assert sharesOut >= sharesIn;
    satisfy assets > 0 && sharesOut == sharesIn;
}