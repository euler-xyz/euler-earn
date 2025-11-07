// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {IEulerEarn} from "./interfaces/IEulerEarn.sol";
import {SafeERC20Permit2Lib} from "./libraries/SafeERC20Permit2Lib.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

interface IFlashLoan {
    function flashLoan(uint256, bytes memory) external;
    function flashLoan(address, uint256, bytes memory) external;
}

contract RescueStrategy {
	address immutable public rescueAccount;
	address immutable public earnVault;
	IERC20 immutable internal _asset;
	address immutable public fundsReceiver;

	modifier onlyRescueAccount() {
		require(tx.origin == rescueAccount, "vault operations are paused");
		_;
	}

    modifier onlyAllowedEarnVault() {
        require(msg.sender == earnVault, "wrong vault");
        _;
    }

	constructor(address _rescueAccount, address _earnVault, address _fundsReceiver) {
		rescueAccount = _rescueAccount;
		earnVault = _earnVault;
        fundsReceiver = _fundsReceiver;
		_asset = IERC20(IEulerEarn(earnVault).asset());
		SafeERC20Permit2Lib.forceApproveMaxWithPermit2(
			_asset,
			rescueAccount,
			address(0)
		);
	}

    function asset() onlyAllowedEarnVault external view returns(address) {
        return address(_asset);
    }

    // will revert user deposits
	function maxDeposit(address) onlyAllowedEarnVault onlyRescueAccount external view returns (uint256) {
		return type(uint256).max;
	}

    // will revert user withdrawals
	function maxWithdraw(address) onlyAllowedEarnVault onlyRescueAccount external view returns (uint256) {
		return 0;
	}

	function previewRedeem(uint256) onlyAllowedEarnVault external view returns (uint256) {
		return 0;
	}

	function balanceOf(address) onlyAllowedEarnVault external view returns (uint256) {
		return 0;
	}

	function deposit(uint256 amount, address) onlyAllowedEarnVault onlyRescueAccount external returns (uint256) {
		SafeERC20Permit2Lib.safeTransferFromWithPermit2(
			_asset,
			msg.sender,
			address(this),
			amount, 
			IEulerEarn(earnVault).permit2Address()
		);

        return amount;
	}

    function rescueEuler(uint256 loanAmount, address flashLoanVault) onlyRescueAccount external {
        bytes memory data = abi.encode(loanAmount, flashLoanVault);
		IFlashLoan(flashLoanVault).flashLoan(loanAmount, data);
	}

    function rescueMorpho(uint256 loanAmount, address morpho) onlyRescueAccount external {
        bytes memory data = abi.encode(loanAmount, morpho);
		IFlashLoan(morpho).flashLoan(address(_asset), loanAmount, data);
	}

	function onFlashLoan(bytes memory data) external {
        (uint256 loanAmount, address flashLoanSource) = abi.decode(data, (uint256, address));

		_processFlashLoan(loanAmount);

        // repay the flashloan
		SafeERC20.safeTransfer(
			_asset,
			flashLoanSource,
			loanAmount
		);
	}

	function onMorphoFlashLoan(uint256, bytes memory data) external {
        (uint256 loanAmount, address flashLoanSource) = abi.decode(data, (uint256, address));

		_processFlashLoan(loanAmount);

        SafeERC20.forceApprove(_asset, flashLoanSource, loanAmount);
	}

	function call(address target, bytes memory payload) onlyRescueAccount external {
		(bool success,) = target.call(payload);
		require(success, "call failed");
	}

	fallback() external {
		revert("vault operations are paused");
	}

    function _processFlashLoan(uint256 loanAmount) internal {
		SafeERC20Permit2Lib.forceApproveMaxWithPermit2(
			_asset,
			earnVault,
			address(0)
		);

		// deposit to earn. All assets should be allocated to rescue strategy, which returns them to the executor
		IERC4626(earnVault).deposit(loanAmount, address(this));

        // withdraw as much as possible to the owner
        IERC4626(earnVault).withdraw(IERC4626(earnVault).maxWithdraw(address(this)), fundsReceiver, address(this));

        // send the remaining shares to the owner
        IERC4626(earnVault).transfer(fundsReceiver, IERC4626(earnVault).balanceOf(address(this)));
    }
}
