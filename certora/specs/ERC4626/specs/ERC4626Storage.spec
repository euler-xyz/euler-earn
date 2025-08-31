import "ERC4626Params.spec";

/// The total amount of assets deposited in the vault ( = totalAssets())
ghost mapping(address /*ERC4626 token*/ => uint256) ERC4626TotalAssets {
    axiom forall address token. ERC4626TotalAssets[token] <= MAX_ASSETS();
}

/// Returns the underlying asset of each ERC4626 token contract [STATIC].
persistent ghost ERC4626Asset(address /*ERC4626 token*/) returns address {
    axiom forall address token. (ERC4626Asset(token) != token || token == 0);
}

/// Returns the max deposit amount per each ERC4626 token contract for any account.
persistent ghost maxDepositCVL(address /*ERC4626 token*/, address /*account*/) returns uint256;