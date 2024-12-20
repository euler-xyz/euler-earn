// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../common/EulerEarnBase.t.sol";

contract DepositWithdrawMintBurnFuzzTest is EulerEarnBase {
    uint256 constant MAX_ALLOWED = type(uint208).max;

    function setUp() public virtual override {
        super.setUp();
    }

    function testFuzzDeposit(uint256 _assets) public {
        _assets = bound(_assets, 0, MAX_ALLOWED);

        // moch the scenario of _assets ownership
        assetTST.mint(user1, _assets);

        uint256 balanceBefore = eulerEulerEarnVault.balanceOf(user1);
        uint256 totalSupplyBefore = eulerEulerEarnVault.totalSupply();
        uint256 totalAssetsDepositedBefore = eulerEulerEarnVault.totalAssetsDeposited();
        uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

        _deposit(user1, _assets);

        assertEq(eulerEulerEarnVault.balanceOf(user1), balanceBefore + _assets);
        assertEq(eulerEulerEarnVault.totalSupply(), totalSupplyBefore + _assets);
        assertEq(eulerEulerEarnVault.totalAssetsDeposited(), totalAssetsDepositedBefore + _assets);
        assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - _assets);
    }

    function testFuzzWithdraw(
        address _receiver,
        uint256 _assetsToDeposit,
        uint256 _assetsToWithdraw,
        uint256 _timestampAfterDeposit
    ) public {
        vm.assume(_receiver != address(0));

        _assetsToDeposit = bound(_assetsToDeposit, 1, MAX_ALLOWED - 1);
        _assetsToWithdraw = bound(_assetsToWithdraw, 0, _assetsToDeposit);
        _timestampAfterDeposit = bound(_timestampAfterDeposit, 0, 86400);

        // deposit
        assetTST.mint(user1, _assetsToDeposit);
        _deposit(user1, _assetsToDeposit);
        vm.warp(block.timestamp + _timestampAfterDeposit);

        // test revert scenario
        uint256 assets = eulerEulerEarnVault.previewRedeem(eulerEulerEarnVault.balanceOf(user1));
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.ERC4626ExceededMaxWithdraw.selector, user1, assets + 1, assets)
        );
        eulerEulerEarnVault.withdraw(assets + 1, user1, user1);
        vm.stopPrank();

        // fuzz partial & full withdraws
        uint256 balanceBefore = eulerEulerEarnVault.balanceOf(user1);
        uint256 totalSupplyBefore = eulerEulerEarnVault.totalSupply();
        uint256 totalAssetsDepositedBefore = eulerEulerEarnVault.totalAssetsDeposited();
        uint256 receiverAssetBalanceBefore = assetTST.balanceOf(_receiver);

        vm.startPrank(user1);
        eulerEulerEarnVault.withdraw(_assetsToWithdraw, _receiver, user1);
        vm.stopPrank();

        assertEq(eulerEulerEarnVault.balanceOf(user1), balanceBefore - _assetsToWithdraw);
        assertEq(eulerEulerEarnVault.totalSupply(), totalSupplyBefore - _assetsToWithdraw);
        assertEq(eulerEulerEarnVault.totalAssetsDeposited(), totalAssetsDepositedBefore - _assetsToWithdraw);
        assertEq(assetTST.balanceOf(_receiver), receiverAssetBalanceBefore + _assetsToWithdraw);
    }

    function testFuzzMint(uint256 _shares) public {
        // mock the scenario of _assets ownership
        uint256 assets = eulerEulerEarnVault.previewMint(_shares);
        if (assets > MAX_ALLOWED) assets = MAX_ALLOWED;
        assetTST.mint(user1, assets);
        _shares = eulerEulerEarnVault.previewDeposit(assets);

        uint256 balanceBefore = eulerEulerEarnVault.balanceOf(user1);
        uint256 totalSupplyBefore = eulerEulerEarnVault.totalSupply();
        uint256 totalAssetsDepositedBefore = eulerEulerEarnVault.totalAssetsDeposited();
        uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

        _mint(user1, assets, _shares);

        assertEq(eulerEulerEarnVault.balanceOf(user1), balanceBefore + _shares);
        assertEq(eulerEulerEarnVault.totalSupply(), totalSupplyBefore + _shares);
        assertEq(eulerEulerEarnVault.totalAssetsDeposited(), totalAssetsDepositedBefore + assets);
        assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - assets);
    }

    function testFuzzRedeem(address _receiver, uint256 _sharesToMint, uint256 _sharesToRedeem) public {
        vm.assume(_receiver != address(0));

        _sharesToMint = bound(_sharesToMint, 1, type(uint256).max - 1);

        // deposit
        uint256 assetsToDeposit = eulerEulerEarnVault.previewMint(_sharesToMint);
        if (assetsToDeposit > MAX_ALLOWED) assetsToDeposit = MAX_ALLOWED;
        assetTST.mint(user1, assetsToDeposit);

        _sharesToMint = eulerEulerEarnVault.previewDeposit(assetsToDeposit);
        _sharesToRedeem = bound(_sharesToRedeem, 0, _sharesToMint);
        _mint(user1, assetsToDeposit, _sharesToMint);
        vm.warp(block.timestamp + 86400);

        // test revert scenario
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(ErrorsLib.ERC4626ExceededMaxRedeem.selector, user1, _sharesToMint + 1, _sharesToMint)
        );
        eulerEulerEarnVault.redeem(_sharesToMint + 1, user1, user1);
        vm.stopPrank();

        // fuzz partial & full redeem
        uint256 balanceBefore = eulerEulerEarnVault.balanceOf(user1);
        uint256 totalSupplyBefore = eulerEulerEarnVault.totalSupply();
        uint256 totalAssetsDepositedBefore = eulerEulerEarnVault.totalAssetsDeposited();
        uint256 receiverAssetBalanceBefore = assetTST.balanceOf(_receiver);

        vm.startPrank(user1);
        uint256 assetsToWithdraw = eulerEulerEarnVault.redeem(_sharesToRedeem, _receiver, user1);
        vm.stopPrank();

        assertEq(eulerEulerEarnVault.balanceOf(user1), balanceBefore - _sharesToRedeem);
        assertEq(eulerEulerEarnVault.totalSupply(), totalSupplyBefore - _sharesToRedeem);
        assertEq(eulerEulerEarnVault.totalAssetsDeposited(), totalAssetsDepositedBefore - assetsToWithdraw);
        assertEq(assetTST.balanceOf(_receiver), receiverAssetBalanceBefore + assetsToWithdraw);
    }

    function _deposit(address _from, uint256 _assets) private {
        vm.startPrank(_from);
        assetTST.approve(address(eulerEulerEarnVault), _assets);
        eulerEulerEarnVault.deposit(_assets, _from);
        vm.stopPrank();
    }

    function _mint(address _from, uint256 _assets, uint256 _shares) private {
        vm.startPrank(_from);
        assetTST.approve(address(eulerEulerEarnVault), _assets);
        eulerEulerEarnVault.mint(_shares, _from);
        vm.stopPrank();
    }
}
