// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IEulerEarn} from "./interfaces/IEulerEarn.sol";
import {SafeERC20Permit2Lib} from "./libraries/SafeERC20Permit2Lib.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IBorrowing, IRiskManager} from "../lib/euler-vault-kit/src/EVault/IEVault.sol";

/* 
    Rescue procedure:
    - Euler installs a perspective in the earn factory which allows adding custom strategies
    - RescueStrategy contracts are deployed for each earn vault to rescue. 
      Immutable params:
        o Rescue account: is allowed to call the rescue functions and receives rescued assets and shares
        o Earn vault: the strategy can only work with the specified vault. If another vault tries to enable it, it will revert on `acceptCap`
    - Euler registers the strategies in the perspective
    - Curator installs the strategy with unlimited cap (submit/acceptCap)
    - Curator sets the new strategy as the only one in supply queue and moves it to the front of withdraw queue
        o at this stage the regular users can't deposit or withdraw from earn
    - Rescue account calls one of the `rescueX` functions (for Euler, Morpho or Aave flash loan sources), specifying the asset amount to flashloan
        o flash loan is used to create earn vault shares, it just passes through earn vault back to the rescue strategy where it is repaid
        o the shares are used to withdraw as much as possible from the underlying strategies to the rescue account
*/

interface IFlashLoan {
    function flashLoan(uint256, bytes memory) external;
    function flashLoan(address, uint256, bytes memory) external;
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}


contract RescueStrategy {
	address immutable public rescueAccount;
	address immutable public earnVault;
	IERC20 immutable internal _asset;

    bool internal rescueActive;

    modifier onlyRescueAccount() {
        require(msg.sender == rescueAccount, "unauthorized");
        _;
    }

	modifier rescueLock() {
        require(!rescueActive, "rescue ongoing");
        _assertRescueMode();
        rescueActive = true;
		_;
        rescueActive = false;
	}

    modifier onlyWhenRescueActive() {
        require(rescueActive, "vault operations are paused");
        _;
    }

    modifier onlyAllowedEarnVault() {
        require(msg.sender == earnVault, "wrong vault");
        _;
    }

    event Rescued(address indexed vault, uint256 assets);

	constructor(address _rescueAccount, address _earnVault) {
		rescueAccount = _rescueAccount;
		earnVault = _earnVault;
		_asset = IERC20(IEulerEarn(earnVault).asset());
	}

    // ---------------- VAULT INTERFACE --------------------

    function asset() external view returns(address) {
        return address(_asset);
    }

    // will revert user deposits
	function maxDeposit(address) onlyAllowedEarnVault onlyWhenRescueActive external view returns (uint256) {
		return type(uint256).max;
	}

    // will revert user withdrawals
	function maxWithdraw(address) onlyAllowedEarnVault onlyWhenRescueActive external view returns (uint256) {
		return 0;
	}

	function previewRedeem(uint256) external pure returns (uint256) {
		return 0;
	}

    // this reverts acceptCaps to prevent reusing the whitelisted strategy on other vaults
	function balanceOf(address) onlyAllowedEarnVault external view returns (uint256) {
		return 0;
	}

	function deposit(uint256 amount, address) onlyAllowedEarnVault onlyWhenRescueActive external returns (uint256) {
		SafeERC20Permit2Lib.safeTransferFromWithPermit2(
			_asset,
			msg.sender,
			address(this),
			amount, 
			IEulerEarn(earnVault).permit2Address()
		);

        return amount;
	}

    // ---------------- RESCUE FUNCTIONS --------------------

    // alternative sources of flashloan
    function rescueEuler(uint256 loanAmount, uint256 loops, address flashLoanVault) onlyRescueAccount rescueLock external {
        bytes memory data = abi.encode(loanAmount, loops, flashLoanVault);
		IFlashLoan(flashLoanVault).flashLoan(loanAmount, data);
	}

    // alternative sources of flashloan
    function rescueEulerBatch(uint256 loanAmount, uint256 loops, address flashLoanVault) onlyRescueAccount rescueLock external {
        address evc = EVCUtil(earnVault).EVC();

        SafeERC20.forceApprove(_asset, flashLoanVault, loanAmount);

        IEVC.BatchItem[] memory batchItems = new IEVC.BatchItem[](5);
        batchItems[0] = IEVC.BatchItem({
            targetContract: evc,
            onBehalfOfAccount: address(0),
            value: 0,
            data: abi.encodeCall(IEVC.enableController, (address(this), flashLoanVault))
        });
        batchItems[1] = IEVC.BatchItem({
            targetContract: flashLoanVault,
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(IBorrowing.borrow, (loanAmount, address(this)))
        });
        batchItems[2] = IEVC.BatchItem({
            targetContract: address(this),
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(this.onBatchLoan, (loanAmount, loops))
        });
        batchItems[3] = IEVC.BatchItem({
            targetContract: flashLoanVault,
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(IBorrowing.repay, (loanAmount, address(this)))
        });
        batchItems[4] = IEVC.BatchItem({
            targetContract: flashLoanVault,
            onBehalfOfAccount: address(this),
            value: 0,
            data: abi.encodeCall(IRiskManager.disableController, ())
        });

        IEVC(evc).batch(batchItems);
	}

    function rescueAave(uint256 loanAmount, uint256 loops, address pool, address feeProvider) onlyRescueAccount rescueLock external {
        bytes memory data = abi.encode(loops, feeProvider);
		IFlashLoan(pool).flashLoanSimple(address(this), address(_asset), loanAmount, data, 0);
	}

    // alternative sources of flashloan
    function rescueMorpho(uint256 loanAmount, uint256 loops, address morpho) onlyRescueAccount rescueLock external {
        IFlashLoan(morpho).flashLoan(address(_asset), loanAmount, abi.encode(loops));
	}

    // ---------------- FLASHLOAN CALLBACKS --------------------

	function onBatchLoan(uint256 loanAmount, uint256 loops) onlyWhenRescueActive external {
		_processFlashLoan(loanAmount, loops);
	}

	function onFlashLoan(bytes memory data) onlyWhenRescueActive external {
        (uint256 loanAmount, uint256 loops, address flashLoanSource) = abi.decode(data, (uint256, uint256, address));

		_processFlashLoan(loanAmount, loops);

        // repay the flashloan
		SafeERC20.safeTransfer(
			_asset,
			flashLoanSource,
			loanAmount
		);
	}

	function onMorphoFlashLoan(uint256 amount, bytes memory data) onlyWhenRescueActive external {
        uint256 loops = abi.decode(data, (uint256));

		_processFlashLoan(amount, loops);

        SafeERC20.forceApprove(_asset, msg.sender, amount);
	}

    // aave callback
    function executeOperation(
        address,
        uint256 amount,
        uint256 premium,
        address,
        bytes calldata data
    ) onlyWhenRescueActive external returns (bool) {
        (uint256 loops, address feeProvider) = abi.decode(data, (uint256, address));
        SafeERC20.safeTransferFrom(_asset, feeProvider, address(this), premium);

        _processFlashLoan(amount, loops);

        SafeERC20.forceApprove(_asset, msg.sender, amount + premium);
        return true;
    }

    // ---------------- HELPERS AND INTERNAL --------------------

    // The contract is not supposed to hold any value, but in case of any issues rescue account can exec arbitrary call
	function call(address target, bytes memory payload) onlyRescueAccount external {
		(bool success,) = target.call(payload);
		require(success, "call failed");
	}

	fallback() external {
		revert("vault operations are paused");
	}

    function _processFlashLoan(uint256 loanAmount, uint256 loops) internal {
		SafeERC20Permit2Lib.forceApproveMaxWithPermit2(
			_asset,
			earnVault,
			address(0)
		);

		// deposit to earn, create shares. Assets will come back here if the strategy is first in supply queue
		for (uint256 i = 0; i < loops; i++) {
            IERC4626(earnVault).deposit(loanAmount, address(this));
        }

        // withdraw as much as possible to the receiver
        uint256 rescuedAmount = IERC4626(earnVault).maxWithdraw(address(this)); 
        IERC4626(earnVault).withdraw(rescuedAmount, rescueAccount, address(this));

        // send the remaining shares to the receiver
        IERC4626(earnVault).transfer(rescueAccount, IERC4626(earnVault).balanceOf(address(this)));

        emit Rescued(address(earnVault), rescuedAmount);
    }

    function _assertRescueMode() internal view {
        IEulerEarn vault = IEulerEarn(earnVault);

        // Must be the ONLY supply target
        require(vault.supplyQueueLength() == 1, "rescue: supplyQueue len != 1");
        require(address(vault.supplyQueue(0)) == address(this), "rescue: supplyQueue[0] != rescue");

        // Must be first in withdraw queue (bank-run guard)
        require(address(vault.withdrawQueue(0)) == address(this), "rescue: withdrawQueue[0] != rescue");
    }
}
