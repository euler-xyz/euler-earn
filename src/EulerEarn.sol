// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IEulerEarn} from "./interface/IEulerEarn.sol";
// contracts
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {
    Dispatch,
    StrategyModule,
    EulerEarnVaultModule,
    FeeModule,
    RewardsModule,
    HooksModule,
    StrategyModule,
    WithdrawalQueueModule
} from "./Dispatch.sol";
import {IAccessControl, AccessControlUpgradeable} from "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin-upgradeable/utils/ContextUpgradeable.sol";
import {Checkpoints} from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {Shared} from "./common/Shared.sol";
// libs
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {StorageLib as Storage, EulerEarnStorage} from "./lib/StorageLib.sol";
import {AmountCap} from "./lib/AmountCapLib.sol";
import {ErrorsLib as Errors} from "./lib/ErrorsLib.sol";
import {ConstantsLib as Constants} from "./lib/ConstantsLib.sol";

/// @title EulerEarn contract
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @dev inspired by Yearn v3 ❤️
contract EulerEarn is Dispatch, AccessControlEnumerableUpgradeable, IEulerEarn {
    using SafeCast for uint256;

    /// @dev Constructor.
    constructor(IntegrationsParams memory _integrationsParams, IEulerEarn.DeploymentParams memory _deploymentParams)
        Shared(_integrationsParams)
        Dispatch(
            _deploymentParams.eulerEarnVaultModule,
            _deploymentParams.rewardsModule,
            _deploymentParams.hooksModule,
            _deploymentParams.feeModule,
            _deploymentParams.strategyModule,
            _deploymentParams.withdrawalQueueModule
        )
    {}

    /// @dev Initialize the EulerEarn.
    /// @param _initParams InitParams struct.
    function init(IEulerEarn.InitParams calldata _initParams) public initializer {
        __ERC4626_init_unchained(IERC20(_initParams.asset));
        __ERC20_init_unchained(_initParams.name, _initParams.symbol);
        __ERC20Votes_init_unchained();
        __EIP712_init_unchained(_initParams.name, "1");
        __AccessControlEnumerable_init_unchained();
        __AccessControl_init_unchained();
        __Votes_init_unchained();
        __Nonces_init_unchained();
        __Context_init_unchained();
        __ERC165_init_unchained();

        // Make sure the asset is a contract. Token transfers using a library will not revert if address has no code.
        require(_initParams.asset.code.length != 0, Errors.InvalidAssetAddress());
        require(_initParams.initialCashAllocationPoints != 0, Errors.InitialAllocationPointsZero());
        require(_initParams.smearingPeriod >= Constants.MIN_INTEREST_SMEAR_PERIOD, Errors.InvalidSmearingPeriod());

        EulerEarnStorage storage $ = Storage._getEulerEarnStorage();
        $.locked = Constants.REENTRANCYLOCK__UNLOCKED;
        $.strategies[address(0)] = IEulerEarn.Strategy({
            allocated: 0,
            allocationPoints: _initParams.initialCashAllocationPoints.toUint96(),
            status: IEulerEarn.StrategyStatus.Active,
            cap: AmountCap.wrap(0)
        });
        $.totalAllocationPoints = _initParams.initialCashAllocationPoints;

        $.smearingPeriod = _initParams.smearingPeriod;

        // Setup DEFAULT_ADMIN
        _grantRole(DEFAULT_ADMIN_ROLE, _initParams.eulerEarnVaultOwner);

        // Setup role admins
        _setRoleAdmin(Constants.GUARDIAN, Constants.GUARDIAN_ADMIN);
        _setRoleAdmin(Constants.STRATEGY_OPERATOR, Constants.STRATEGY_OPERATOR_ADMIN);
        _setRoleAdmin(Constants.EULER_EARN_MANAGER, Constants.EULER_EARN_MANAGER_ADMIN);
        _setRoleAdmin(Constants.WITHDRAWAL_QUEUE_MANAGER, Constants.WITHDRAWAL_QUEUE_MANAGER_ADMIN);
        _setRoleAdmin(Constants.REBALANCER, Constants.REBALANCER_ADMIN);
    }

    /// @dev Overriding grantRole().
    function grantRole(bytes32 _role, address _account)
        public
        override (IAccessControl, AccessControlUpgradeable)
        onlyEVCAccountOwner
    {
        super.grantRole(_role, _account);
    }

    /// @dev Overriding revokeRole().
    function revokeRole(bytes32 _role, address _account)
        public
        override (IAccessControl, AccessControlUpgradeable)
        onlyEVCAccountOwner
    {
        super.revokeRole(_role, _account);
    }

    /// @dev Overriding renounceRole().
    function renounceRole(bytes32 _role, address _callerConfirmation)
        public
        override (IAccessControl, AccessControlUpgradeable)
        onlyEVCAccountOwner
    {
        super.renounceRole(_role, _callerConfirmation);
    }

    /// @dev See {FeeModule-setFeeRecipient}.
    function setFeeRecipient(address _newFeeRecipient)
        public
        override (IEulerEarn, FeeModule)
        onlyEVCAccountOwner
        onlyRole(Constants.EULER_EARN_MANAGER)
        use(feeModule)
    {}

    /// @dev See {FeeModule-setPerformanceFee}.
    function setPerformanceFee(uint96 _newFee)
        public
        override (IEulerEarn, FeeModule)
        onlyEVCAccountOwner
        onlyRole(Constants.EULER_EARN_MANAGER)
        use(feeModule)
    {}

    /// @dev See {RewardsModule-optInStrategyRewards}.
    function optInStrategyRewards(address _strategy)
        public
        override (IEulerEarn, RewardsModule)
        onlyEVCAccountOwner
        onlyRole(Constants.EULER_EARN_MANAGER)
        use(rewardsModule)
    {}

    /// @dev See {RewardsModule-optOutStrategyRewards}.
    function optOutStrategyRewards(address _strategy)
        public
        override (IEulerEarn, RewardsModule)
        onlyEVCAccountOwner
        onlyRole(Constants.EULER_EARN_MANAGER)
        use(rewardsModule)
    {}

    /// @dev See {RewardsModule-optOutStrategyRewards}.
    function enableRewardForStrategy(address _strategy, address _reward)
        public
        override (IEulerEarn, RewardsModule)
        onlyEVCAccountOwner
        onlyRole(Constants.EULER_EARN_MANAGER)
        use(rewardsModule)
    {}

    /// @dev See {RewardsModule-disableRewardForStrategy}.
    function disableRewardForStrategy(address _strategy, address _reward, bool _forfeitRecentReward)
        public
        override (IEulerEarn, RewardsModule)
        onlyEVCAccountOwner
        onlyRole(Constants.EULER_EARN_MANAGER)
        use(rewardsModule)
    {}

    /// @dev See {RewardsModule-claimStrategyReward}.
    function claimStrategyReward(address _strategy, address _reward, address _recipient, bool _forfeitRecentReward)
        public
        override (IEulerEarn, RewardsModule)
        onlyEVCAccountOwner
        onlyRole(Constants.EULER_EARN_MANAGER)
        use(rewardsModule)
    {}

    /// @dev See {HooksModule-setHooksConfig}.
    function setHooksConfig(address _hooksTarget, uint32 _hookedFns)
        public
        override (IEulerEarn, HooksModule)
        onlyEVCAccountOwner
        onlyRole(Constants.EULER_EARN_MANAGER)
        use(hooksModule)
    {}

    /// @dev See {EulerEarnVaultModule-skim}.
    function skim(address _token, address _recipient)
        public
        override (IEulerEarn, EulerEarnVaultModule)
        onlyEVCAccountOwner
        onlyRole(Constants.EULER_EARN_MANAGER)
        use(eulerEarnVaultModule)
    {}

    /// @dev See {StrategyModule-addStrategy}.
    function addStrategy(address _strategy, uint256 _allocationPoints)
        public
        override (IEulerEarn, StrategyModule)
        onlyEVCAccountOwner
        onlyRole(Constants.STRATEGY_OPERATOR)
        use(strategyModule)
    {}

    /// @dev See {StrategyModule-removeStrategy}.
    function removeStrategy(address _strategy)
        public
        override (IEulerEarn, StrategyModule)
        onlyEVCAccountOwner
        onlyRole(Constants.STRATEGY_OPERATOR)
        use(strategyModule)
    {}

    /// @dev See {StrategyModule-setStrategyCap}.
    function setStrategyCap(address _strategy, uint16 _cap)
        public
        override (IEulerEarn, StrategyModule)
        onlyEVCAccountOwner
        onlyRole(Constants.GUARDIAN)
        use(strategyModule)
    {}

    /// @dev See {StrategyModule-adjustAllocationPoints}.
    function adjustAllocationPoints(address _strategy, uint256 _newPoints)
        public
        override (IEulerEarn, StrategyModule)
        onlyEVCAccountOwner
        onlyRole(Constants.GUARDIAN)
        use(strategyModule)
    {}

    /// @dev See {StrategyModule-toggleStrategyEmergencyStatus}.
    function toggleStrategyEmergencyStatus(address _strategy)
        public
        override (IEulerEarn, StrategyModule)
        onlyEVCAccountOwner
        onlyRole(Constants.GUARDIAN)
        use(strategyModule)
    {}

    /// @dev See {WithdrawalQueue-reorderWithdrawalQueue}.
    function reorderWithdrawalQueue(uint8 _index1, uint8 _index2)
        public
        override (IEulerEarn, WithdrawalQueueModule)
        onlyEVCAccountOwner
        onlyRole(Constants.WITHDRAWAL_QUEUE_MANAGER)
        use(withdrawalQueueModule)
    {}

    /// @dev See {EulerEarnVaultModule-rebalance}.
    function rebalance(address[] calldata _strategies)
        public
        override (IEulerEarn, EulerEarnVaultModule)
        onlyEVCAccountOwner
        onlyRole(Constants.REBALANCER)
        use(eulerEarnVaultModule)
    {}

    /// @dev See {RewardsModule-enableBalanceForwarder}.
    function enableBalanceForwarder() public override (IEulerEarn, RewardsModule) use(rewardsModule) {}

    /// @dev See {RewardsModule-disableBalanceForwarder}.
    function disableBalanceForwarder() public override (IEulerEarn, RewardsModule) use(rewardsModule) {}

    /// @dev See {EulerEarnVaultModule-harvest}.
    function harvest() public override (IEulerEarn, EulerEarnVaultModule) use(eulerEarnVaultModule) {}

    /// @dev See {EulerEarnVaultModule-updateInterestAccrued}.
    function updateInterestAccrued() public override (IEulerEarn, EulerEarnVaultModule) use(eulerEarnVaultModule) {}

    /// @dev See {EulerEarnVaultModule-gulp}.
    function gulp() public override (IEulerEarn, EulerEarnVaultModule) use(eulerEarnVaultModule) {}

    /// @dev See {EulerEarnVaultModule-deposit}.
    function deposit(uint256 _assets, address _receiver)
        public
        override (IEulerEarn, EulerEarnVaultModule)
        use(eulerEarnVaultModule)
        returns (uint256)
    {}

    /// @dev See {EulerEarnVaultModule-mint}.
    function mint(uint256 _shares, address _receiver)
        public
        override (IEulerEarn, EulerEarnVaultModule)
        use(eulerEarnVaultModule)
        returns (uint256)
    {}

    /// @dev See {EulerEarnVaultModule-withdraw}.
    function withdraw(uint256 _assets, address _receiver, address _owner)
        public
        override (IEulerEarn, EulerEarnVaultModule)
        use(eulerEarnVaultModule)
        returns (uint256 shares)
    {}

    /// @dev See {EulerEarnVaultModule-redeem}.
    function redeem(uint256 _shares, address _receiver, address _owner)
        public
        override (IEulerEarn, EulerEarnVaultModule)
        use(eulerEarnVaultModule)
        returns (uint256 assets)
    {}

    /// @dev See {EulerEarnVaultModule-transfer}.
    function transfer(address _to, uint256 _value) public override (IEulerEarn, EulerEarnVaultModule) returns (bool) {
        return super.transfer(_to, _value);
    }

    /// @dev See {EulerEarnVaultModule-approve}.
    function approve(address _spender, uint256 _value)
        public
        override (IEulerEarn, EulerEarnVaultModule)
        returns (bool)
    {
        return super.approve(_spender, _value);
    }

    /// @dev See {EulerEarnVaultModule-transferFrom}.
    function transferFrom(address _from, address _to, uint256 _value)
        public
        override (IEulerEarn, EulerEarnVaultModule)
        returns (bool)
    {
        return super.transferFrom(_from, _to, _value);
    }

    /// @dev See {EulerEarnVaultModule-delegate}.
    function delegate(address _delegatee) public override (IEulerEarn, EulerEarnVaultModule) {
        super.delegate(_delegatee);
    }

    /// @dev See {EulerEarnVaultModule-delegateBySig}.
    function delegateBySig(address _delegatee, uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s)
        public
        override (IEulerEarn, EulerEarnVaultModule)
    {
        super.delegateBySig(_delegatee, _nonce, _expiry, _v, _r, _s);
    }

    /// @dev See {EulerEarnVaultModule-interestAccrued}.
    function interestAccrued() public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.interestAccrued();
    }

    /// @dev See {EulerEarnVaultModule-getEulerEarnSavingRate}.
    function getEulerEarnSavingRate()
        public
        view
        override (IEulerEarn, EulerEarnVaultModule)
        returns (uint40, uint40, uint168)
    {
        return super.getEulerEarnSavingRate();
    }

    /// @dev See {EulerEarnVaultModule-totalAllocated}.
    function totalAllocated() public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.totalAllocated();
    }

    /// @dev See {EulerEarnVaultModule-totalAssetsDeposited}.
    function totalAssetsDeposited() public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.totalAssetsDeposited();
    }

    /// @dev See {EulerEarnVaultModule-lastHarvestTimestamp}.
    function lastHarvestTimestamp() public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.lastHarvestTimestamp();
    }

    /// @dev See {EulerEarnVaultModule-totalAssetsAllocatable}.
    function totalAssetsAllocatable() public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.totalAssetsAllocatable();
    }

    /// @dev See {EulerEarnVaultModule-totalAssets}.
    function totalAssets() public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.totalAssets();
    }

    /// @dev See {EulerEarnVaultModule-convertToShares}.
    function convertToShares(uint256 _assets)
        public
        view
        override (IEulerEarn, EulerEarnVaultModule)
        returns (uint256)
    {
        return super.convertToShares(_assets);
    }

    /// @dev See {EulerEarnVaultModule-convertToAssets}.
    function convertToAssets(uint256 _shares)
        public
        view
        override (IEulerEarn, EulerEarnVaultModule)
        returns (uint256)
    {
        return super.convertToAssets(_shares);
    }

    /// @dev See {EulerEarnVaultModule-maxWithdraw}.
    function maxWithdraw(address _owner) public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.maxWithdraw(_owner);
    }

    /// @dev See {EulerEarnVaultModule-maxRedeem}.
    function maxRedeem(address _owner) public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.maxRedeem(_owner);
    }

    /// @dev See {EulerEarnVaultModule-previewDeposit}.
    function previewDeposit(uint256 _assets)
        public
        view
        override (IEulerEarn, EulerEarnVaultModule)
        returns (uint256)
    {
        return super.previewDeposit(_assets);
    }

    /// @dev See {EulerEarnVaultModule-previewMint}.
    function previewMint(uint256 _shares) public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.previewMint(_shares);
    }

    /// @dev See {EulerEarnVaultModule-previewWithdraw}.
    function previewWithdraw(uint256 _assets)
        public
        view
        override (IEulerEarn, EulerEarnVaultModule)
        returns (uint256)
    {
        return super.previewWithdraw(_assets);
    }

    /// @dev See {EulerEarnVaultModule-previewRedeem}.
    function previewRedeem(uint256 _shares) public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.previewRedeem(_shares);
    }

    /// @dev See {EulerEarnVaultModule-balanceOf}.
    function balanceOf(address _account) public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.balanceOf(_account);
    }

    /// @dev See {EulerEarnVaultModule-totalSupply}.
    function totalSupply() public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.totalSupply();
    }

    /// @dev See {EulerEarnVaultModule-decimals}.
    function decimals() public view override (IEulerEarn, EulerEarnVaultModule) returns (uint8) {
        return super.decimals();
    }

    /// @dev See {EulerEarnVaultModule-maxDeposit}.
    function maxDeposit(address _owner) public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.maxDeposit(_owner);
    }

    /// @dev See {EulerEarnVaultModule-maxMint}.
    function maxMint(address _owner) public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.maxMint(_owner);
    }

    /// @dev See {EulerEarnVaultModule-asset}.
    function asset() public view override (IEulerEarn, EulerEarnVaultModule) returns (address) {
        return super.asset();
    }

    /// @dev See {EulerEarnVaultModule-name}.
    function name() public view override (IEulerEarn, EulerEarnVaultModule) returns (string memory) {
        return super.name();
    }

    /// @dev See {EulerEarnVaultModule-symbol}.
    function symbol() public view override (IEulerEarn, EulerEarnVaultModule) returns (string memory) {
        return super.symbol();
    }

    /// @dev See {EulerEarnVaultModule-allowance}.
    function allowance(address _owner, address _spender)
        public
        view
        override (IEulerEarn, EulerEarnVaultModule)
        returns (uint256)
    {
        return super.allowance(_owner, _spender);
    }

    /// @dev See {EulerEarnVaultModule-numCheckpoints}.
    function numCheckpoints(address _account)
        public
        view
        override (IEulerEarn, EulerEarnVaultModule)
        returns (uint32)
    {
        return super.numCheckpoints(_account);
    }

    /// @dev See {EulerEarnVaultModule-checkpoints}.
    function checkpoints(address _account, uint32 _pos)
        public
        view
        override (IEulerEarn, EulerEarnVaultModule)
        returns (Checkpoints.Checkpoint208 memory)
    {
        return super.checkpoints(_account, _pos);
    }

    /// @dev See {EulerEarnVaultModule-clock}.
    function clock() public view override (IEulerEarn, EulerEarnVaultModule) returns (uint48) {
        return super.clock();
    }

    /// @dev See {EulerEarnVaultModule-CLOCK_MODE}.
    function CLOCK_MODE() public view override (IEulerEarn, EulerEarnVaultModule) returns (string memory) {
        return super.CLOCK_MODE();
    }

    /// @dev See {EulerEarnVaultModule-getVotes}.
    function getVotes(address _account) public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.getVotes(_account);
    }

    /// @dev See {EulerEarnVaultModule-getPastVotes}.
    function getPastVotes(address _account, uint256 _timepoint)
        public
        view
        override (IEulerEarn, EulerEarnVaultModule)
        returns (uint256)
    {
        return super.getPastVotes(_account, _timepoint);
    }

    /// @dev See {EulerEarnVaultModule-getPastTotalSupply}.
    function getPastTotalSupply(uint256 _timepoint)
        public
        view
        override (IEulerEarn, EulerEarnVaultModule)
        returns (uint256)
    {
        return super.getPastTotalSupply(_timepoint);
    }

    /// @dev See {EulerEarnVaultModule-delegates}.
    function delegates(address _account) public view override (IEulerEarn, EulerEarnVaultModule) returns (address) {
        return super.delegates(_account);
    }

    /// @dev See {StrategyModule-getStrategy}.
    function getStrategy(address _strategy)
        public
        view
        override (IEulerEarn, StrategyModule)
        returns (IEulerEarn.Strategy memory)
    {
        return super.getStrategy(_strategy);
    }

    /// @dev See {StrategyModule-totalAllocationPoints}.
    function totalAllocationPoints() public view override (IEulerEarn, StrategyModule) returns (uint256) {
        return super.totalAllocationPoints();
    }

    /// @dev See {FeeModule-performanceFeeConfig}.
    function performanceFeeConfig() public view override (IEulerEarn, FeeModule) returns (address, uint96) {
        return super.performanceFeeConfig();
    }

    /// @dev See {HooksModule-getHooksConfig}.
    function getHooksConfig() public view override (IEulerEarn, HooksModule) returns (address, uint32) {
        return super.getHooksConfig();
    }

    /// @dev See {RewardsModule-balanceTrackerAddress}.
    function balanceTrackerAddress() public view override (IEulerEarn, RewardsModule) returns (address) {
        return super.balanceTrackerAddress();
    }

    /// @dev See {RewardsModule-balanceForwarderEnabled}.
    function balanceForwarderEnabled(address _account)
        public
        view
        override (IEulerEarn, RewardsModule)
        returns (bool)
    {
        return super.balanceForwarderEnabled(_account);
    }

    /// @dev See {WithdrawalQueueModule-withdrawalQueue}.
    function withdrawalQueue() public view override (IEulerEarn, WithdrawalQueueModule) returns (address[] memory) {
        return super.withdrawalQueue();
    }

    /// @dev See {EulerEarnVaultModule-isCheckingHarvestCoolDown}.
    function isCheckingHarvestCoolDown() public view override (IEulerEarn, EulerEarnVaultModule) returns (bool) {
        return super.isCheckingHarvestCoolDown();
    }

    /// @dev See {EulerEarnVaultModule-interestSmearingPeriod}.
    function interestSmearingPeriod() public view override (IEulerEarn, EulerEarnVaultModule) returns (uint256) {
        return super.interestSmearingPeriod();
    }

    /// @dev See {EulerEarnVaultModule-permit2Address}.
    function permit2Address() public view override (IEulerEarn, EulerEarnVaultModule) returns (address) {
        return super.permit2Address();
    }

    /// @dev See {EVCUtil-EVC}.
    function EVC() public view override (IEulerEarn, EVCUtil) returns (address) {
        return address(evc);
    }

    /// @dev Overriding _msgSender().
    function _msgSender() internal view override (Dispatch, ContextUpgradeable) returns (address) {
        return Dispatch._msgSender();
    }

    /// @dev See {ERC20VotesUpgradeable-_getVotingUnits}.
    function _getVotingUnits(address _account) internal view override returns (uint256) {
        return _balanceOf(_account);
    }
}
