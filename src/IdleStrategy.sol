// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

contract IdleStrategyDonateable is IERC4626 {
    address immutable public earnVault;

    IERC20 immutable internal _asset;

    modifier onlyEarnVault {
        if (msg.sender != earnVault) _revertNotSupported();
        _;
    }

    constructor(address _earnVault) {
        earnVault = _earnVault;
        _asset = IERC20(IERC4626(_earnVault).asset());
    }

    // ---------------- FUNCTIONS INTERACTED WITH BY EARN VAULT  --------------------

    function maxDeposit(address) external view returns (uint256) {
        return msg.sender == earnVault ? type(uint256).max : 0;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        return owner == earnVault ? totalAssets() : 0;
    }

    function balanceOf(address account) external view returns (uint256) {
        return maxWithdraw(account);
    }

    function previewRedeem(uint256) external view returns (uint256) {
        return msg.sender == earnVault ? totalAssets() : 0;
    }


    function deposit(uint256 amount, address receiver) onlyEarnVault external returns (uint256) {
        require(receiver == earnVault, "wrong receiver");
        SafeERC20.safeTransferFrom(_asset, msg.sender, address(this), amount);

        return 0;
    }

    function withdraw(uint256 amount, address, address) onlyEarnVault external returns (uint256) {
        SafeERC20.safeTransfer(_asset, earnVault, amount);

        return 0;
    }

    // ---------------- ERC4626 compatibility stubs --------------------

    function symbol() external pure returns (string memory) {
        return "IDL";
    }

    function name() external pure returns (string memory) {
        return "Idle Strategy";
    }

    function decimals() external view returns (uint8) {
        return IERC20Metadata(address(_asset)).decimals();
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function totalSupply() external view returns (uint256) {
        return convertToShares(totalAssets());
    }

    function asset() external view returns (address) {
        return address(_asset);
    }

    function totalAssets() public view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    function convertToShares(uint256 amount) public pure returns (uint256) {
        return amount;
    }

    function convertToAssets(uint256 amount) external pure returns (uint256) {
        return amount;
    }

    function previewDeposit(uint256) external pure returns (uint256) {
        return 0;
    }

    function maxMint(address) external pure returns (uint256) {
        return 0;
    }

    function previewMint(uint256) external pure returns (uint256) {
        return 0;
    }

    function previewWithdraw(uint256) external pure returns (uint256) {
        return 0;
    }

    function maxRedeem(address) external pure returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure returns (bool) {
        _revertNotSupported();
    }

    function transfer(address, uint256) external pure returns (bool) {
        _revertNotSupported();
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        _revertNotSupported();
    }

    function mint(uint256, address) external pure returns (uint256) {
        _revertNotSupported();
    }

    function redeem(uint256, address, address) external pure returns (uint256) {
        _revertNotSupported();
    }



    function _revertNotSupported() internal pure {
        revert("not supported");
    }
}
