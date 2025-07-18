import "./ERC4626.spec";

methods {
    function _.convertToAssets(uint256 shares, Math.Rounding rounding) internal =>
        convertToAssetsCVL(calledContract, shares, rounding) expect uint256;

    function _.convertToShares(uint256 assets, Math.Rounding rounding) internal =>
        convertToSharesCVL(calledContract, assets, rounding) expect uint256;

    function _.previewRedeem(uint256 shares) external => 
        previewRedeemCVL(calledContract, shares) expect uint256;

    function _.previewMint(uint256 shares) external => 
        previewMintCVL(calledContract, shares) expect uint256;

    function _.previewWithdraw(uint256 assets) external => 
        previewWithdrawCVL(calledContract, assets) expect uint256;

    function _.asset() external => 
        ERC4626Asset(calledContract) expect address;

    function _.maxDeposit(address account) external => 
        maxDepositCVL(calledContract, account) expect uint256;

    function _.maxWithdraw(address account) external => 
        maxWithdrawCVL(calledContract, account) expect uint256;

    function _.deposit(uint256 assets, address receiver) external with (env e) =>
        depositCVL(calledContract, e.block.timestamp, e.msg.sender, assets, receiver) expect uint256;

    function _.withdraw(uint256 assets, address receiver, address owner) external with (env e) =>
        withdrawCVL(calledContract, e.block.timestamp, e.msg.sender, assets, receiver, owner) expect uint256;
}