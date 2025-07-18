import "../ERC4626/specs/ERC4626.spec";
using VaultMock0 as v0;
using VaultMock1 as v1;

methods {
    function v0.convertToAssets(uint256 shares, Math.Rounding rounding) external returns (uint256) =>
        convertToAssetsCVL(calledContract, shares, rounding);

    function v0.convertToShares(uint256 assets, Math.Rounding rounding) external returns (uint256) =>
        convertToSharesCVL(calledContract, assets, rounding);

    function v0.previewRedeem(uint256 shares) internal returns (uint256) => 
        previewRedeemCVL(calledContract, shares);

    function v0.previewMint(uint256 shares) internal returns (uint256) => 
        previewMintCVL(calledContract, shares);

    function v0.previewWithdraw(uint256 assets) internal returns (uint256) => 
        previewWithdrawCVL(calledContract, assets);

    function v0.asset() internal returns (address) => 
        ERC4626Asset(calledContract);

    function v0.maxDeposit(address owner) internal returns (uint256) => 
        maxDepositCVL(calledContract, owner);

    function v0.maxWithdraw(address owner) internal returns (uint256) => 
        maxWithdrawCVL(calledContract, owner);

    function v0.deposit(uint256 assets, address receiver) internal returns (uint256) with (env e) =>
        depositCVL(calledContract, e.block.timestamp, e.msg.sender, assets, receiver);

    function v0.withdraw(uint256 assets, address receiver, address owner) internal returns (uint256) with (env e) =>
        withdrawCVL(calledContract, e.block.timestamp, e.msg.sender, assets, receiver, owner);

    function v0.decimals() internal returns (uint8) => 
        decimalsCVL(calledContract);

    function v1.convertToAssets(uint256 shares, Math.Rounding rounding) external returns (uint256) =>
        convertToAssetsCVL(calledContract, shares, rounding);

    function v1.convertToShares(uint256 assets, Math.Rounding rounding) external returns (uint256) =>
        convertToSharesCVL(calledContract, assets, rounding);

    function v1.previewRedeem(uint256 shares) internal returns (uint256) => 
        previewRedeemCVL(calledContract, shares);

    function v1.previewMint(uint256 shares) internal returns (uint256) => 
        previewMintCVL(calledContract, shares);

    function v1.previewWithdraw(uint256 assets) internal returns (uint256) => 
        previewWithdrawCVL(calledContract, assets);

    function v1.asset() internal returns (address) => 
        ERC4626Asset(calledContract);

    function v1.maxDeposit(address owner) internal returns (uint256) => 
        maxDepositCVL(calledContract, owner);

    function v1.maxWithdraw(address owner) internal returns (uint256) => 
        maxWithdrawCVL(calledContract, owner);

    function v1.deposit(uint256 assets, address receiver) internal returns (uint256) with (env e) =>
        depositCVL(calledContract, e.block.timestamp, e.msg.sender, assets, receiver);

    function v1.withdraw(uint256 assets, address receiver, address owner) internal returns (uint256) with (env e) =>
        withdrawCVL(calledContract, e.block.timestamp, e.msg.sender, assets, receiver, owner);

    function v1.decimals() internal returns (uint8) => 
        decimalsCVL(calledContract);
}