import "ERC4626Storage.spec";
import "../../ERC20/specs/ERC20Storage.spec";
import "../../ERC20/specs/ERC20Standard.spec";

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Shares <-> Assets Conversion Formulas                                                                               
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

/// Mathmatical ghost function for pro-rata converter of the form:
/// result = mulDiv(assets, total shares + offset, total assets + offset).
persistent ghost proRataConverter(
    mathint /*assets*/,
    mathint /*total shares + offset*/,
    mathint /*total assets + offset*/
) returns uint256
{
    /// Rounding error bounds
    axiom forall mathint assets. forall mathint totalShares. forall mathint totalAssets.
        proRataConverter(assets,totalShares,totalAssets) * totalAssets
        <= assets * totalShares
        &&
        (proRataConverter(assets,totalShares,totalAssets) + 1) * totalAssets
        > assets * totalShares;
    
    /// Monotonoticity
    axiom forall mathint assets1. forall mathint assets2. forall mathint totalShares. forall mathint totalAssets.
        assets1 < assets2 => proRataConverter(assets1,totalShares,totalAssets) <= proRataConverter(assets2,totalShares,totalAssets);

    axiom forall mathint assets. forall mathint totalShares1. forall mathint totalShares2. forall mathint totalAssets.
        totalShares1 < totalShares2 => proRataConverter(assets,totalShares1,totalAssets) <= proRataConverter(assets,totalShares2,totalAssets);

    axiom forall mathint assets. forall mathint totalAssets1. forall mathint totalAssets2. forall mathint totalShares.
        totalAssets1 < totalAssets2 => proRataConverter(assets,totalShares,totalAssets2) <= proRataConverter(assets,totalShares,totalAssets1);
}

function convertToAssetsCVL(address token, uint256 shares, Math.Rounding rounding) returns uint256 
{
    uint256 assets = proRataConverter(
        shares, 
        ERC4626TotalAssets[token] + ASSETS_OFFSET(), 
        supplyByToken[token] + SHARES_OFFSET()
    );
    bool noRemainder = assets * (supplyByToken[token] + SHARES_OFFSET()) == shares * (ERC4626TotalAssets[token] + ASSETS_OFFSET());
    if(rounding == Math.Rounding.Floor) {
        return assets;
    } else if(rounding == Math.Rounding.Ceil) {
        return noRemainder ? assets : require_uint256(assets+1);
    } else {
        assert false;
    }
    return 0;
}

function convertToSharesCVL(address token, uint256 assets, Math.Rounding rounding) returns uint256 
{
    uint256 shares = proRataConverter(
        assets, 
        supplyByToken[token] + SHARES_OFFSET(),
        ERC4626TotalAssets[token] + ASSETS_OFFSET() 
    );
    bool noRemainder = assets * (supplyByToken[token] + SHARES_OFFSET()) == shares * (ERC4626TotalAssets[token] + ASSETS_OFFSET());
    if(rounding == Math.Rounding.Floor) {
        return shares;
    } else if(rounding == Math.Rounding.Ceil) {
        return noRemainder ? shares : require_uint256(shares+1);
    } else {
        assert false;
    }
    return 0;
}

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Function implementations                                                                                 
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

function depositCVL(address token, uint256 timestamp, address sender, uint256 assets, address receiver) returns uint256
{
    /// Assumption: the share token is non-rebasing.
    require !isRebasing(token);
    /// The share balance of any user cannot surpass the total supply.
    require sumOfPairLessEqualThanSupply(token, sender, receiver);
    /// Calculate amount of minted shares
    uint256 shares = previewDepositCVL(token, assets);

    if(!depositSuccess(token, sender, receiver, assets, shares)) {
        revert("Deposit is invalid");
    }

    address underlying = ERC4626Asset(token);
    /// Deposit tokens from sender to vault.
    /// @dev notice:
    /*
    The following call only invokes the standard CVL implementation of the IERC20 interface.
    Any ERC20 contracts present in the scene will not be invoked here, thus missed behavior could be
    possible, where the underlying token is a contract in the scene.
    Consider adding a switch-case block to allow for special tokens
    e.g. if(underlying == Contract) Contract.transferFrom(e, ...)
    */
    bool success = transferFromCVL(underlying, timestamp, token, sender, token, assets);
    require success;
    
    /// Mint shares and increase assets
    supplyByToken[token] = assert_uint256(supplyByToken[token] + shares);
    ERC4626TotalAssets[token] = assert_uint256(ERC4626TotalAssets[token] + assets);
    balanceByToken[token][receiver] = assert_uint256(balanceByToken[token][receiver] + shares);

    return shares;
}

function withdrawCVL(address token, uint256 timestamp, address sender, uint256 assets, address receiver, address owner) returns uint256
{
    /// Assumption: the share token is non-rebasing.
    require !isRebasing(token);
    /// The share balance of any user cannot surpass the total supply.
    require sumOfPairLessEqualThanSupply(token, owner, receiver);
    uint256 shares = previewWithdrawCVL(token, assets);

    if(!withdrawSuccess(token, sender, owner, receiver, assets, shares)) {
        revert("Withdraw is invalid");
    }

    /// Spend allowance
    if(owner != sender) {
        allowanceByToken[token][owner][sender] = assert_uint256(allowanceByToken[token][owner][sender] - shares);
    }
    /// Burn and decrease assets
    supplyByToken[token] = assert_uint256(supplyByToken[token] - shares);
    ERC4626TotalAssets[token] = assert_uint256(ERC4626TotalAssets[token] - assets);
    balanceByToken[token][owner] = assert_uint256(balanceByToken[token][owner] - shares);

    address underlying = ERC4626Asset(token);
    /// Send tokens to recipient.
    /// @dev notice:
    /*
    The following call only invokes the standard CVL implementation of the IERC20 interface.
    Any ERC20 contracts present in the scene will not be invoked here, thus missed behavior could be
    possible, where the underlying token is a contract in the scene.
    Consider adding a switch-case block to allow for special tokens
    e.g. if(underlying == Contract) Contract.transfer(e, ...)
    */
    bool success = transferCVL(underlying, timestamp, token, receiver, assets);
    require success;

    return shares;
}

function maxWithdrawCVL(address token, address account) returns uint256 {
    return convertToAssetsCVL(token, balanceByToken[token][account], Math.Rounding.Floor);
}

function previewRedeemCVL(address token, uint256 shares) returns uint256 {
    return convertToAssetsCVL(token, shares, Math.Rounding.Floor);
}

function previewDepositCVL(address token, uint256 assets) returns uint256 {
    return convertToSharesCVL(token, assets, Math.Rounding.Floor);
}

function previewMintCVL(address token, uint256 shares) returns uint256 {
    return convertToAssetsCVL(token, shares, Math.Rounding.Ceil);
}

function previewWithdrawCVL(address token, uint256 assets) returns uint256 {
    return convertToSharesCVL(token, assets, Math.Rounding.Ceil);
}

/*
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Function success conditions                                                                                 
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
*/

function depositSuccess(address token, address sender, address receiver, uint256 assets, uint256 shares) returns bool {
    return assets <= maxDepositCVL(token, receiver) &&
        ERC4626TotalAssets[token] + assets <= max_uint256 &&
        supplyByToken[token] + shares <= max_uint256;
}

function withdrawSuccess(address token, address spender, address owner, address receiver, uint256 assets, uint256 shares) returns bool {
    return hasAllowanceERC20(token, spender, owner, shares) &&
        assets <= maxWithdrawCVL(token, receiver) &&
        supplyByToken[token] >= shares &&
        ERC4626TotalAssets[token] >= assets &&
        balanceByToken[token][owner] >= shares;
}

function hasAllowanceERC20(address token, address spender, address from, uint256 amount) returns bool {
    return from != spender => allowanceByToken[token][from][spender] >= amount;
}