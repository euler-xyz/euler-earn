// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {IEVault} from "../lib/euler-vault-kit/src/EVault/IEVault.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IEulerEarn, IEulerEarnBase} from "./interfaces/IEulerEarn.sol";
import {IEulerEarnFactory} from "./interfaces/IEulerEarnFactory.sol";
import {SafeERC20Permit2Lib} from "./libraries/SafeERC20Permit2Lib.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/utils/ReentrancyGuard.sol";
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

contract RescueStrategy is IEVault {
    address public immutable rescueAccount;
    address public immutable earnVault;
    IERC20 internal immutable _asset;

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

    event Rescued(address indexed vault, uint256 assets);

    constructor(address _rescueAccount, address _earnVault) {
        rescueAccount = _rescueAccount;
        earnVault = _earnVault;
        _asset = IERC20(IEulerEarn(earnVault).asset());
    }

    // ---------------- RESCUE ENABLING BEHAVIOR --------------------

    // will revert user deposits
    function maxDeposit(address) external view returns (uint256) {
        require(msg.sender != earnVault || rescueActive, "vault operations are paused - maxDeposit");
        return msg.sender == earnVault ? type(uint256).max : 0;
    }

    // will revert user withdrawals
    function maxWithdraw(address) external view returns (uint256) {
        if (!rescueActive && msg.sender == earnVault) {
            // if reentrancy locked - earn is calling from `withdraw`, which should be prevented
            // if unlocked - let it through because `maxWithdrawFromStrategy` is called, which is relied upon by the Lens contract
            (bool success, bytes memory reason) = earnVault.staticcall(abi.encodeCall(IEulerEarnBase.setFee, (0)));
            require(!success, "expected revert"); // if reentrancy was unlocked, attempt to set it will panic

            if (reason.length == 4 && bytes4(reason) == ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
                revert("vault operations are paused - maxWithdraw");
        }
        return 0;
    }

    // this reverts acceptCaps to prevent reusing the whitelisted strategy on other vaults
    function balanceOf(address) external view returns (uint256) {
        require(!IEulerEarnFactory(IEulerEarn(earnVault).creator()).isVault(msg.sender) || msg.sender == earnVault, "wrong vault");
        return 0;
    }

    function deposit(uint256 amount, address) external  returns (uint256) {
        if (msg.sender == earnVault) {
            require(rescueActive, "only during rescue");

            SafeERC20Permit2Lib.safeTransferFromWithPermit2(
                _asset, msg.sender, address(this), amount, IEulerEarn(earnVault).permit2Address()
            );

            return amount;
        }

        _revertNotSupported();
    }

    // ---------------- RESCUE FUNCTIONS --------------------

    // alternative sources of flashloan
    function rescueEuler(uint256 loanAmount, uint256 loops, address flashLoanVault)
        external
        onlyRescueAccount
        rescueLock
    {
        bytes memory data = abi.encode(loanAmount, loops, flashLoanVault);
        IFlashLoan(flashLoanVault).flashLoan(loanAmount, data);
    }

    // alternative sources of flashloan
    function rescueEulerBatch(uint256 loanAmount, uint256 loops, address flashLoanVault)
        external
        onlyRescueAccount
        rescueLock
    {
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

    function rescueAave(uint256 loanAmount, uint256 loops, address pool, address feeProvider)
        external
        onlyRescueAccount
        rescueLock
    {
        bytes memory data = abi.encode(loops, feeProvider);
        IFlashLoan(pool).flashLoanSimple(address(this), address(_asset), loanAmount, data, 0);
    }

    // alternative sources of flashloan
    function rescueMorpho(uint256 loanAmount, uint256 loops, address morpho) external onlyRescueAccount rescueLock {
        IFlashLoan(morpho).flashLoan(address(_asset), loanAmount, abi.encode(loops));
    }

    // ---------------- FLASHLOAN CALLBACKS --------------------

    function onBatchLoan(uint256 loanAmount, uint256 loops) external onlyWhenRescueActive {
        _processFlashLoan(loanAmount, loops);
    }

    function onFlashLoan(bytes memory data) external onlyWhenRescueActive {
        (uint256 loanAmount, uint256 loops, address flashLoanSource) = abi.decode(data, (uint256, uint256, address));

        _processFlashLoan(loanAmount, loops);

        // repay the flashloan
        SafeERC20.safeTransfer(_asset, flashLoanSource, loanAmount);
    }

    function onMorphoFlashLoan(uint256 amount, bytes memory data) external onlyWhenRescueActive {
        uint256 loops = abi.decode(data, (uint256));

        _processFlashLoan(amount, loops);

        SafeERC20.forceApprove(_asset, msg.sender, amount);
    }

    // aave callback
    function executeOperation(address, uint256 amount, uint256 premium, address, bytes calldata data)
        external
        onlyWhenRescueActive
        returns (bool)
    {
        (uint256 loops, address feeProvider) = abi.decode(data, (uint256, address));
        SafeERC20.safeTransferFrom(_asset, feeProvider, address(this), premium);

        _processFlashLoan(amount, loops);

        SafeERC20.forceApprove(_asset, msg.sender, amount + premium);
        return true;
    }

    // ---------------- HELPERS AND INTERNAL --------------------

    // The contract is not supposed to hold any value, but in case of any issues rescue account can exec arbitrary call
    function call(address target, bytes memory payload) external onlyRescueAccount {
        (bool success,) = target.call(payload);
        require(success, "call failed");
    }

    function _processFlashLoan(uint256 loanAmount, uint256 loops) internal {
        SafeERC20Permit2Lib.forceApproveMaxWithPermit2(_asset, earnVault, address(0));

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

    function _revertNotSupported() internal pure {
        revert("not supported");
    }

    // ---------------- EVault compatibility stubs --------------------

    function symbol() external pure returns (string memory) {
        return "RS";
    }

    function name() external pure returns (string memory) {
        return "Rescue Strategy";
    }

    function decimals() external view returns (uint8) {
        return IERC20Metadata(address(_asset)).decimals();
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function asset() external view returns (address) {
        return address(_asset);
    }

    function totalAssets() external pure returns (uint256) {
        return 0;
    }

    function convertToShares(uint256) external pure returns (uint256) {
        return 0;
    }

    function convertToAssets(uint256) external pure returns (uint256) {
        return 0;
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

    function previewRedeem(uint256) external pure returns (uint256) {
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

    function withdraw(uint256, address, address) external pure returns (uint256) {
        _revertNotSupported();
    }

    function transferFromMax(address, address) external pure returns (bool) {
        _revertNotSupported();
    }

    function accumulatedFees() external pure returns (uint256) {
        return 0;
    }

    function accumulatedFeesAssets() external pure returns (uint256) {
        return 0;
    }

    function creator() external pure returns (address) {
        return address(0);
    }

    function skim(uint256, address) external pure returns (uint256) {
        _revertNotSupported();
    }

    function totalBorrows() external pure returns (uint256) {
        return 0;
    }

    function totalBorrowsExact() external pure returns (uint256) {
        return 0;
    }

    function cash() external pure returns (uint256) {
        return 0;
    }

    function debtOf(address) external pure returns (uint256) {
        return 0;
    }

    function debtOfExact(address) external pure returns (uint256) {
        return 0;
    }

    function interestRate() external pure returns (uint256) {
        return 0;
    }

    function interestAccumulator() external pure returns (uint256) {
        return 0;
    }

    function dToken() external pure returns (address) {
        return address(0);
    }

    function borrow(uint256, address) external pure returns (uint256) {
        _revertNotSupported();
    }

    function repay(uint256, address) external pure returns (uint256) {
        _revertNotSupported();
    }

    function repayWithShares(uint256, address) external pure returns (uint256, uint256) {
        _revertNotSupported();
    }

    function pullDebt(uint256, address) external pure {
        _revertNotSupported();
    }

    function flashLoan(uint256, bytes calldata) external pure {
        _revertNotSupported();
    }

    function touch() external pure {
        _revertNotSupported();
    }

    function checkLiquidation(address, address, address) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    function liquidate(address, address, uint256, uint256) external pure {
        _revertNotSupported();
    }

    function accountLiquidity(address, bool) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    function accountLiquidityFull(address, bool) external pure returns (address[] memory c, uint256[] memory cv, uint256 lv) {}

    function disableController() external pure {
        _revertNotSupported();
    }

    function checkAccountStatus(address, address[] calldata) external pure returns (bytes4) {
        return bytes4(0);
    }

    function checkVaultStatus() external pure returns (bytes4) {
        return bytes4(0);
    }

    function balanceTrackerAddress() external pure returns (address) {
        return address(0);
    }

    function balanceForwarderEnabled(address) external pure returns (bool) {
        return false;
    }

    function enableBalanceForwarder() external pure {
        _revertNotSupported();
    }

    function disableBalanceForwarder() external pure {
        _revertNotSupported();
    }

    function governorAdmin() external pure returns (address) {
        return address(0);
    }

    function feeReceiver() external pure returns (address) {
        return address(0);
    }

    function interestFee() external pure returns (uint16) {
        return 0;
    }

    function interestRateModel() external pure returns (address) {
        return address(0);
    }

    function protocolConfigAddress() external pure returns (address) {
        return address(0);
    }

    function protocolFeeShare() external pure returns (uint256) {
        return 0;
    }

    function protocolFeeReceiver() external pure returns (address) {
        return address(0);
    }

    function caps() external pure returns (uint16, uint16) {
        return (0, 0);
    }

    function LTVBorrow(address) external pure returns (uint16) {
        return 0;
    }

    function LTVLiquidation(address) external pure returns (uint16) {
        return 0;
    }

    function LTVFull(address collateral) external pure returns (
            uint16 borrowLTV,
            uint16 liquidationLTV,
            uint16 initialLiquidationLTV,
            uint48 targetTimestamp,
            uint32 rampDuration
    ) {}

    function LTVList() external pure returns (address[] memory l) {}

    function maxLiquidationDiscount() external pure returns (uint16) {
        return 0;
    }

    function liquidationCoolOffTime() external pure returns (uint16) {
        return 0;
    }

    function hookConfig() external pure returns (address hookTarget, uint32 hookedOps) {}

    function configFlags() external pure returns (uint32) {
        return 0;
    }

    function EVC() external pure returns (address) {
        return address(0);
    }

    function unitOfAccount() external pure returns (address) {
        return address(0);
    }

    function oracle() external pure returns (address) {
        return address(0);
    }

    function permit2Address() external pure returns (address) {
        return address(0);
    }

    function convertFees() external pure {
        _revertNotSupported();
    }

    function setGovernorAdmin(address) external pure {
        _revertNotSupported();
    }

    function setFeeReceiver(address) external pure {
        _revertNotSupported();
    }

    function setLTV(address, uint16, uint16, uint32) external pure {
        _revertNotSupported();
    }

    function setMaxLiquidationDiscount(uint16) external pure {
        _revertNotSupported();
    }

    function setLiquidationCoolOffTime(uint16) external pure {
        _revertNotSupported();
    }

    function setInterestRateModel(address) external pure {
        _revertNotSupported();
    }

    function setHookConfig(address, uint32) external pure {
        _revertNotSupported();
    }

    function setConfigFlags(uint32) external pure {
        _revertNotSupported();
    }

    function setCaps(uint16, uint16) external pure {
        _revertNotSupported();
    }

    function setInterestFee(uint16) external pure {
        _revertNotSupported();
    }

    function initialize(address) external pure {
        _revertNotSupported();
    }

    function MODULE_INITIALIZE() external pure returns (address) { return address(0); }
    function MODULE_TOKEN() external pure returns (address) { return address(0); }
    function MODULE_VAULT() external pure returns (address) { return address(0); }
    function MODULE_BORROWING() external pure returns (address) { return address(0); }
    function MODULE_LIQUIDATION() external pure returns (address) { return address(0); }
    function MODULE_RISKMANAGER() external pure returns (address) { return address(0); }
    function MODULE_BALANCE_FORWARDER() external pure returns (address) { return address(0); }
    function MODULE_GOVERNANCE() external pure returns (address) { return address(0); }
}
