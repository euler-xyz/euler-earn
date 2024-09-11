// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// interfaces
import {IERC4626} from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IYieldAggregator} from "../interface/IYieldAggregator.sol";
import {IBalanceTracker} from "reward-streams/src/interfaces/IBalanceTracker.sol";
// contracts
import {Shared} from "../common/Shared.sol";
import {
    IERC20Metadata,
    ERC20Upgradeable,
    ERC4626Upgradeable
} from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {
    ERC20VotesUpgradeable,
    Checkpoints
} from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin-upgradeable/utils/ContextUpgradeable.sol";
// libs
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {StorageLib as Storage, YieldAggregatorStorage} from "../lib/StorageLib.sol";
import {ErrorsLib as Errors} from "../lib/ErrorsLib.sol";
import {EventsLib as Events} from "../lib/EventsLib.sol";
import {ConstantsLib as Constants} from "../lib/ConstantsLib.sol";
import {AmountCapLib, AmountCap} from "../lib/AmountCapLib.sol";

/// @title YieldAggregatorVaultModule contract
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
abstract contract YieldAggregatorVaultModule is ERC4626Upgradeable, ERC20VotesUpgradeable, Shared {
    using Math for uint256;
    using AmountCapLib for AmountCap;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /// @notice Rebalance strategies allocation.
    /// @dev The strategies to rebalance will be harvested.
    /// @param _strategies Strategies addresses.
    function rebalance(address[] calldata _strategies) public virtual nonReentrant {
        _executeHarvest(_strategies);

        for (uint256 i; i < _strategies.length; ++i) {
            _rebalance(_strategies[i]);
        }
    }

    /// @notice Harvest all the strategies.
    /// @dev This function will loop through the strategies following the withdrawal queue order and harvest all.
    ///      Harvested positive and negative yields will be aggregated and only net amount will be accounted.
    /// @dev This function does not check for the cooldown period.
    function harvest() public virtual nonReentrant {
        _updateInterestAccrued();

        _harvest(false);
    }

    /// @notice Update accrued interest and count it in the total assets deposited.
    function updateInterestAccrued() public virtual nonReentrant {
        _updateInterestAccrued();
    }

    /// @notice Gulp positive yield.
    function gulp() public virtual nonReentrant {
        _gulp();
    }

    /// @notice Deposit `_assets` amount into the yield aggregator.
    /// @dev See {IERC4626-deposit}.
    /// @dev This function will call DEPOSIT hook if enabled.
    /// @return Amount of shares minted.
    function deposit(uint256 _assets, address _receiver) public virtual override nonReentrant returns (uint256) {
        _callHooksTarget(Constants.DEPOSIT, _msgSender());

        uint256 shares = _convertToShares(_assets, Math.Rounding.Floor);
        _deposit(_msgSender(), _receiver, _assets, shares);

        return shares;
    }

    /// @notice Mint `_shares` amount.
    /// @dev See {IERC4626-mint}.
    /// @dev This function will call MINT hook if enabled.
    /// @return Amount of assets deposited.
    function mint(uint256 _shares, address _receiver) public virtual override nonReentrant returns (uint256) {
        _callHooksTarget(Constants.MINT, _msgSender());

        uint256 assets = _convertToAssets(_shares, Math.Rounding.Ceil);
        _deposit(_msgSender(), _receiver, assets, _shares);

        return assets;
    }

    /// @notice Withdraw `_assets` amount from yield aggregator. This function will try to withdraw from cash reserve,
    ///         if not enough, will loop through the strategies following the withdrawal queue order till the withdraw amount is filled.
    /// @dev See {IERC4626-withdraw}.
    /// @dev This function will update the accrued interest and call WITHDRAW hook if enabled.
    /// @return Amount of shares burned.
    function withdraw(uint256 _assets, address _receiver, address _owner)
        public
        virtual
        override
        nonReentrant
        returns (uint256)
    {
        _updateInterestAccrued();

        _callHooksTarget(Constants.WITHDRAW, _msgSender());

        _harvest(false);

        uint256 maxAssets = _convertToAssets(_balanceOf(_owner), Math.Rounding.Floor);
        if (_assets > maxAssets) {
            revert Errors.ERC4626ExceededMaxWithdraw(_owner, _assets, maxAssets);
        }

        uint256 shares = _convertToShares(_assets, Math.Rounding.Ceil);
        _withdraw(_msgSender(), _receiver, _owner, _assets, shares);

        return shares;
    }

    /// @notice Redeem `_shares` amount from yield aggregator. This function will try to withdraw from cash reserve,
    ///         if not enough, will loop through the strategies following the withdrawal queue order till the withdraw amount is filled.
    /// @dev See {IERC4626-redeem}.
    /// @dev This function will update the accrued interest and call REDEEM hook if enabled.
    /// @return Amount of assets withdrawn.
    function redeem(uint256 _shares, address _receiver, address _owner)
        public
        virtual
        override
        nonReentrant
        returns (uint256)
    {
        _updateInterestAccrued();

        _callHooksTarget(Constants.REDEEM, _msgSender());

        _harvest(false);

        uint256 maxShares = _balanceOf(_owner);
        if (_shares > maxShares) {
            revert Errors.ERC4626ExceededMaxRedeem(_owner, _shares, maxShares);
        }

        uint256 assets = _convertToAssets(_shares, Math.Rounding.Floor);

        _withdraw(_msgSender(), _receiver, _owner, assets, _shares);

        return assets;
    }

    /// @dev See {IERC20-transfer}.
    function transfer(address _to, uint256 _value) public virtual override (ERC20Upgradeable, IERC20) returns (bool) {
        return super.transfer(_to, _value);
    }

    /// @dev See {IERC20-approve}.
    function approve(address _spender, uint256 _value)
        public
        virtual
        override (ERC20Upgradeable, IERC20)
        returns (bool)
    {
        return super.approve(_spender, _value);
    }

    /// @dev See {IERC20-transferFrom}.
    function transferFrom(address _from, address _to, uint256 _value)
        public
        virtual
        override (ERC20Upgradeable, IERC20)
        returns (bool)
    {
        return super.transferFrom(_from, _to, _value);
    }

    /// @dev See {VotesUpgradeable-delegate}.
    function delegate(address _delegatee) public virtual override {
        super.delegate(_delegatee);
    }

    /// @dev See {VotesUpgradeable-delegateBySig}.
    function delegateBySig(address _delegatee, uint256 _nonce, uint256 _expiry, uint8 _v, bytes32 _r, bytes32 _s)
        public
        virtual
        override
    {
        super.delegateBySig(_delegatee, _nonce, _expiry, _v, _r, _s);
    }

    /// @notice Return the accrued interest.
    /// @return Accrued interest.
    function interestAccrued() public view virtual nonReentrantView returns (uint256) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        return _interestAccruedFromCache($.interestLeft);
    }

    /// @notice Get saving rate data.
    /// @return Last interest update timestamp.
    /// @return Timestamp when interest smearing end.
    /// @return Amount of interest left to distribute.
    function getYieldAggregatorSavingRate() public view virtual nonReentrantView returns (uint40, uint40, uint168) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        return ($.lastInterestUpdate, $.interestSmearEnd, $.interestLeft);
    }

    /// @notice Get the total allocated amount.
    /// @return Total allocated amount.
    function totalAllocated() public view virtual nonReentrantView returns (uint256) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        return $.totalAllocated;
    }

    /// @notice Get the total assets deposited into the yield aggregator.
    /// @return Total assets deposited.
    function totalAssetsDeposited() public view virtual nonReentrantView returns (uint256) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        return $.totalAssetsDeposited;
    }

    /// @notice Get the latest harvest timestamp.
    /// @return Latest harvest timestamp.
    function lastHarvestTimestamp() public view virtual nonReentrantView returns (uint256) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        return $.lastHarvestTimestamp;
    }

    /// @notice get the total assets allocatable
    /// @dev the total assets allocatable is the amount of assets deposited into the aggregator + assets already deposited into strategies
    /// @return total assets allocatable.
    function totalAssetsAllocatable() public view virtual nonReentrantView returns (uint256) {
        return _totalAssetsAllocatable();
    }

    /// @notice Return the total amount of assets deposited, plus the accrued interest.
    /// @return total assets amount.
    function totalAssets() public view virtual override nonReentrantView returns (uint256) {
        return _totalAssets();
    }

    /// @notice Convert to the amount of shares that the Vault would exchange for the amount of assets provided.
    /// @dev See {IERC4626-convertToShares}.
    /// @return Amount of shares.
    function convertToShares(uint256 _assets) public view virtual override nonReentrantView returns (uint256) {
        return _convertToShares(_assets, Math.Rounding.Floor);
    }

    /// @notice Convert to the amount of assets that the Vault would exchange for the amount of shares provided.
    /// @dev See {IERC4626-convertToAssets}.
    /// @return Amount of assets.
    function convertToAssets(uint256 _shares) public view virtual override nonReentrantView returns (uint256) {
        return _convertToAssets(_shares, Math.Rounding.Floor);
    }

    /// @notice Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance.
    /// @dev See {IERC4626-maxWithdraw}.
    /// @return Amount of asset to be withdrawn.
    function maxWithdraw(address _owner) public view virtual override nonReentrantView returns (uint256) {
        (uint256 totalAssetsExpected, uint256 totalSupplyExpected) = previewHarvest();

        uint256 maxAssets = _balanceOf(_owner).mulDiv(
            totalAssetsExpected + 1, totalSupplyExpected + 10 ** _decimalsOffset(), Math.Rounding.Floor
        );

        return _simulateStrategiesWithdraw(maxAssets);
    }

    /// @notice Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault.
    /// @dev See {IERC4626-maxRedeem}.
    /// @return Amount of shares.
    function maxRedeem(address _owner) public view virtual override nonReentrantView returns (uint256) {
        (uint256 totalAssetsExpected, uint256 totalSupplyExpected) = previewHarvest();

        uint256 maxAssets = _balanceOf(_owner).mulDiv(
            totalAssetsExpected + 1, totalSupplyExpected + 10 ** _decimalsOffset(), Math.Rounding.Floor
        );

        uint256 assets = _simulateStrategiesWithdraw(maxAssets);

        return
            assets.mulDiv(totalSupplyExpected + 10 ** _decimalsOffset(), totalAssetsExpected + 1, Math.Rounding.Floor);
    }

    /// @notice Preview a deposit call and return the amount of shares to be minted.
    /// @dev See {IERC4626-previewDeposit}.
    /// @return Amount of shares.
    function previewDeposit(uint256 _assets) public view virtual override nonReentrantView returns (uint256) {
        return _convertToShares(_assets, Math.Rounding.Floor);
    }

    /// @notice Preview a mint call and return the amount of assets to be deposited.
    /// @dev See {IERC4626-previewMint}.
    /// @return Amount of assets.
    function previewMint(uint256 _shares) public view virtual override nonReentrantView returns (uint256) {
        return _convertToAssets(_shares, Math.Rounding.Ceil);
    }

    /// @notice Preview a withdraw call and return the amount of shares to be burned.
    /// @dev See {IERC4626-previewWithdraw}.
    /// @return Amount of shares.
    function previewWithdraw(uint256 _assets) public view virtual override nonReentrantView returns (uint256) {
        (uint256 totalAssetsExpected, uint256 totalSupplyExpected) = previewHarvest();

        return
            _assets.mulDiv(totalSupplyExpected + 10 ** _decimalsOffset(), totalAssetsExpected + 1, Math.Rounding.Ceil);
    }

    /// @notice Preview a redeem call and return the amount of assets to be withdrawn.
    /// @dev See {IERC4626-previewRedeem}.
    /// @return Amount of assets.
    function previewRedeem(uint256 _shares) public view virtual override nonReentrantView returns (uint256) {
        (uint256 totalAssetsExpected, uint256 totalSupplyExpected) = previewHarvest();

        return
            _shares.mulDiv(totalAssetsExpected + 1, totalSupplyExpected + 10 ** _decimalsOffset(), Math.Rounding.Floor);
    }

    /// @notice Return the `_account` aggregator's balance.
    /// @dev Overriding this function to add the `nonReentrantView` modifier.
    function balanceOf(address _account)
        public
        view
        virtual
        override (ERC20Upgradeable, IERC20)
        nonReentrantView
        returns (uint256)
    {
        return _balanceOf(_account);
    }

    /// @notice Return the yield aggregator total balance.
    /// @dev Overriding this function to add the `nonReentrantView` modifier.
    function totalSupply() public view virtual override (ERC20Upgradeable, IERC20) nonReentrantView returns (uint256) {
        return _totalSupply();
    }

    /// @notice Return the yield aggregator token decimals.
    /// @dev Not protected with `nonReentrantView()`
    function decimals() public view virtual override (ERC4626Upgradeable, ERC20Upgradeable) returns (uint8) {
        return ERC4626Upgradeable.decimals();
    }

    /// @notice Returns the maximum amount of the underlying asset that can be deposited into the yield aggregator.
    /// @dev Not protected with `nonReentrantView()`
    function maxDeposit(address) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    /// @notice Returns the maximum amount of the Vault shares that can be minted for the receiver.
    /// @dev Not protected with `nonReentrantView()`
    function maxMint(address) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    /// @notice Returns the yield aggregator asset.
    /// @dev Not protected with `nonReentrantView()`
    /// @return Asset address.
    function asset() public view virtual override returns (address) {
        return _asset();
    }

    /// @notice Returns the name of the yield aggregator.
    /// @dev Not protected with `nonReentrantView()`
    /// @return Name.
    function name() public view virtual override (ERC20Upgradeable, IERC20Metadata) returns (string memory) {
        return super.name();
    }

    ///@dev Returns the symbol of the yield aggregator, usually a shorter version of the name.
    /// @dev Not protected with `nonReentrantView()`
    /// @return Symbol.
    function symbol() public view virtual override (ERC20Upgradeable, IERC20Metadata) returns (string memory) {
        return super.symbol();
    }

    /// @dev See {IERC20-allowance}.
    /// @dev Not protected with `nonReentrantView()`
    function allowance(address _owner, address _spender)
        public
        view
        virtual
        override (ERC20Upgradeable, IERC20)
        returns (uint256)
    {
        return super.allowance(_owner, _spender);
    }

    /// @notice Get number of checkpoints for `_account`.
    /// @dev Not protected with `nonReentrantView()`
    /// @param _account Account address.
    /// @return Number of checkpoints.
    function numCheckpoints(address _account) public view virtual override returns (uint32) {
        return super.numCheckpoints(_account);
    }

    /// @dev Get the `_pos`-th checkpoint for `_account`.
    /// @dev Not protected with `nonReentrantView()`
    function checkpoints(address _account, uint32 _pos)
        public
        view
        virtual
        override
        returns (Checkpoints.Checkpoint208 memory)
    {
        return super.checkpoints(_account, _pos);
    }

    /// @dev See {VotesUpgradeable-clock}.
    /// @dev Not protected with `nonReentrantView()`
    function clock() public view virtual override returns (uint48) {
        return super.clock();
    }

    /// @dev See {VotesUpgradeable-CLOCK_MODE}.
    /// @dev Not protected with `nonReentrantView()`
    function CLOCK_MODE() public view virtual override returns (string memory) {
        return super.CLOCK_MODE();
    }

    /// @dev See {VotesUpgradeable-getVotes}.
    /// @dev Not protected with `nonReentrantView()`
    function getVotes(address _account) public view virtual override returns (uint256) {
        return super.getVotes(_account);
    }

    /// @dev See {VotesUpgradeable-getPastVotes}.
    /// @dev Not protected with `nonReentrantView()`
    function getPastVotes(address _account, uint256 _timepoint) public view virtual override returns (uint256) {
        return super.getPastVotes(_account, _timepoint);
    }

    /// @dev See {VotesUpgradeable-getPastTotalSupply}.
    /// @dev Not protected with `nonReentrantView()`
    function getPastTotalSupply(uint256 _timepoint) public view virtual override returns (uint256) {
        return super.getPastTotalSupply(_timepoint);
    }

    /// @dev See {VotesUpgradeable-delegates}.
    /// @dev Not protected with `nonReentrantView()`
    function delegates(address _account) public view virtual override returns (address) {
        return super.delegates(_account);
    }

    /// @dev Increase the total assets deposited.
    /// @dev See {IERC4626-_deposit}.
    function _deposit(address _caller, address _receiver, uint256 _assets, uint256 _shares) internal override {
        super._deposit(_caller, _receiver, _assets, _shares);

        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();
        $.totalAssetsDeposited += _assets;
    }

    /// @dev Withdraw needed amount from yield aggregator.
    ///      If cash reserve is not enough for withdraw, this function will loop through the withdrawal queue
    ///      and do withdraws till the amount is retrieved, or revert with `NotEnoughAssets()` error.
    /// @dev See {IERC4626-_withdraw}.
    function _withdraw(address _caller, address _receiver, address _owner, uint256 _assets, uint256 _shares)
        internal
        override
    {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();
        uint256 assetsRetrieved = IERC20(_asset()).balanceOf(address(this));

        if (assetsRetrieved < _assets) {
            uint256 numStrategies = $.withdrawalQueue.length;
            for (uint256 i; i < numStrategies; ++i) {
                IERC4626 strategy = IERC4626($.withdrawalQueue[i]);

                if ($.strategies[address(strategy)].status != IYieldAggregator.StrategyStatus.Active) continue;

                uint256 underlyingBalance = strategy.maxWithdraw(address(this));
                uint256 desiredAssets = _assets - assetsRetrieved;
                uint256 withdrawAmount = (underlyingBalance >= desiredAssets) ? desiredAssets : underlyingBalance;

                // Do actual withdraw from strategy
                strategy.withdraw(withdrawAmount, address(this), address(this));

                // Update allocated assets
                $.strategies[address(strategy)].allocated -= uint120(withdrawAmount);
                $.totalAllocated -= withdrawAmount;

                assetsRetrieved += withdrawAmount;

                if (assetsRetrieved >= _assets) {
                    break;
                }
            }
        }

        if (assetsRetrieved < _assets) {
            revert Errors.NotEnoughAssets();
        }

        $.totalAssetsDeposited -= _assets;

        super._withdraw(_caller, _receiver, _owner, _assets, _shares);
    }

    /// @dev Override _update hook to call IBalanceTracker.balanceTrackerHook().
    /// @dev This also re-implement the ERC20VotesUpgradeable._update() logic to use `_totalSupply()` instead of the nonReentrantView protected `totalSupply()`.
    /// @param _from Address sending the amount.
    /// @param _to Address receiving the amount.
    /// @param _value Amount to update.
    function _update(address _from, address _to, uint256 _value)
        internal
        override (ERC20VotesUpgradeable, ERC20Upgradeable)
    {
        /// call `_update()` on ERC20Upgradeable
        ERC20Upgradeable._update(_from, _to, _value);

        /// ERC20VotesUpgradeable `_update()`
        if (_from == address(0)) {
            uint256 supply = _totalSupply();
            uint256 cap = _maxSupply();
            if (supply > cap) {
                revert Errors.ERC20ExceededSafeSupply(supply, cap);
            }
        }
        _transferVotingUnits(_from, _to, _value);

        if (_from == _to) return;

        IBalanceTracker balanceTracker = IBalanceTracker(_balanceTrackerAddress());

        if ((_from != address(0)) && (_balanceForwarderEnabled(_from))) {
            balanceTracker.balanceTrackerHook(_from, _balanceOf(_from), false);
        }

        if ((_to != address(0)) && (_balanceForwarderEnabled(_to))) {
            balanceTracker.balanceTrackerHook(_to, _balanceOf(_to), false);
        }
    }

    /// @dev Override _msgSender() to recognize EVC authentication.
    /// @return address Sender address.
    function _msgSender() internal view virtual override (ContextUpgradeable, Shared) returns (address) {
        return Shared._msgSender();
    }

    /// @dev Internal conversion function (from assets to shares) with support for rounding direction.
    /// @param _assets Amount of assets.
    /// @param _rounding Rounding direction.
    /// @return Amount of shares.
    function _convertToShares(uint256 _assets, Math.Rounding _rounding) internal view override returns (uint256) {
        return _assets.mulDiv(_totalSupply() + 10 ** _decimalsOffset(), _totalAssets() + 1, _rounding);
    }

    /// @dev Internal conversion function (from shares to assets) with support for rounding direction.
    /// @param _shares Amount of shares.
    /// @param _rounding Rounding direction.
    /// @return Amount of assets.
    function _convertToAssets(uint256 _shares, Math.Rounding _rounding) internal view override returns (uint256) {
        return _shares.mulDiv(_totalAssets() + 1, _totalSupply() + 10 ** _decimalsOffset(), _rounding);
    }

    /// @dev Loop through strategies, harvest, aggregate positive and negative yield and account for net amount.
    /// @dev Loss socialization will be taken out from interest left + amount available to gulp first, if not enough, socialize on deposits.
    /// @dev Performance fee will only be applied on net positive yield across all strategies.
    /// @param _checkCooldown a boolean to indicate whether to check for cooldown period or not.
    function _harvest(bool _checkCooldown) private {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        // if (_checkCooldown && ($.lastHarvestTimestamp + Constants.HARVEST_COOLDOWN >= block.timestamp)) {
        //     return;
        // }

        // $.lastHarvestTimestamp = uint40(block.timestamp);

        _executeHarvest($.withdrawalQueue);
    }

    /// @dev Execute harvest across array of strategies.
    /// @param _strategies Array of strategies.
    function _executeHarvest(address[] memory _strategies) private {
        uint256 totalPositiveYield;
        uint256 totalNegativeYield;
        for (uint256 i; i < _strategies.length; ++i) {
            (uint256 positiveYield, uint256 loss) = _harvestStrategy(_strategies[i]);

            totalPositiveYield += positiveYield;
            totalNegativeYield += loss;
        }

        // we should deduct loss before updating totalAllocated to not underflow
        if (totalNegativeYield > totalPositiveYield) {
            unchecked {
                _deductLoss(totalNegativeYield - totalPositiveYield);
            }
        } else if (totalNegativeYield < totalPositiveYield) {
            unchecked {
                _accruePerformanceFee(totalPositiveYield - totalNegativeYield);
            }
        }

        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        $.totalAllocated = $.totalAllocated + totalPositiveYield - totalNegativeYield;

        _gulp();

        emit Events.Harvest($.totalAllocated, totalPositiveYield, totalNegativeYield);
    }

    /// @dev Execute harvest on a single strategy.
    /// @param _strategy Strategy address.
    /// @return Amount of positive yield if any, else 0.
    /// @return Amount of loss if any, else 0.
    function _harvestStrategy(address _strategy) private returns (uint256, uint256) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        uint120 strategyAllocatedAmount = $.strategies[_strategy].allocated;

        if (strategyAllocatedAmount == 0 || $.strategies[_strategy].status != IYieldAggregator.StrategyStatus.Active) {
            return (0, 0);
        }

        // Use `previewRedeem()` to get the actual assets amount, bypassing any limits or revert.
        uint256 aggregatorShares = IERC4626(_strategy).balanceOf(address(this));
        uint256 aggregatorAssets = IERC4626(_strategy).previewRedeem(aggregatorShares);
        $.strategies[_strategy].allocated = uint120(aggregatorAssets);

        uint256 positiveYield;
        uint256 loss;
        if (aggregatorAssets == strategyAllocatedAmount) {
            return (positiveYield, loss);
        } else if (aggregatorAssets > strategyAllocatedAmount) {
            unchecked {
                positiveYield = aggregatorAssets - strategyAllocatedAmount;
            }
        } else {
            unchecked {
                loss = strategyAllocatedAmount - aggregatorAssets;
            }
        }

        emit Events.ExecuteHarvest(_strategy, aggregatorAssets, strategyAllocatedAmount);

        return (positiveYield, loss);
    }

    /// @dev Accrue performace fee on aggregated harvested positive yield.
    /// @dev Fees will be minted as shares to fee recipient.
    /// @param _yield Net positive yield.
    function _accruePerformanceFee(uint256 _yield) private {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        address cachedFeeRecipient = $.feeRecipient;
        uint96 cachedPerformanceFee = $.performanceFee;

        if (cachedFeeRecipient == address(0) || cachedPerformanceFee == 0) return;

        (uint256 feeAssets, uint256 feeShares) = _applyPerformanceFee(_yield, cachedPerformanceFee);

        if (feeShares != 0) {
            // Move feeAssets from gulpable amount to totalAssetsDeposited to not dilute other depositors.
            $.totalAssetsDeposited += feeAssets;

            _mint(cachedFeeRecipient, feeShares);
        }

        emit Events.AccruePerformanceFee(cachedFeeRecipient, _yield, feeShares);
    }

    /// @dev Rebalance strategy by depositing or withdrawing the amount to rebalance to hit target allocation.
    ///      If current allocation is greater than target allocation, the aggregator will withdraw the excess assets.
    ///      If current allocation is less than target allocation, the aggregator will:
    ///         - Try to deposit the delta, if the cash is not sufficient, deposit all the available cash
    ///         - If all the available cash is greater than the max deposit, deposit the max deposit
    /// @param _strategy Strategy address.
    function _rebalance(address _strategy) private {
        if (_strategy == Constants.CASH_RESERVE) {
            return; //nothing to rebalance as that's the cash reserve
        }

        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        IYieldAggregator.Strategy memory strategyData = $.strategies[_strategy];

        if (strategyData.status != IYieldAggregator.StrategyStatus.Active) return;

        uint256 totalAllocationPointsCache = $.totalAllocationPoints;
        uint256 totalAssetsAllocatableCache = _totalAssetsAllocatable();
        uint256 targetAllocation =
            totalAssetsAllocatableCache * strategyData.allocationPoints / totalAllocationPointsCache;

        uint120 capAmount = uint120(strategyData.cap.resolve());
        // capAmount will be max uint256 if no cap is set
        if (targetAllocation > capAmount) targetAllocation = capAmount;

        uint256 amountToRebalance;
        bool isDeposit;
        if (strategyData.allocated > targetAllocation) {
            // Withdraw
            unchecked {
                amountToRebalance = strategyData.allocated - targetAllocation;
            }

            uint256 maxWithdrawableFromStrategy = IERC4626(_strategy).maxWithdraw(address(this));
            if (amountToRebalance > maxWithdrawableFromStrategy) {
                amountToRebalance = maxWithdrawableFromStrategy;
            }
        } else if (strategyData.allocated < targetAllocation) {
            // Deposit
            uint256 targetCash = totalAssetsAllocatableCache * $.strategies[Constants.CASH_RESERVE].allocationPoints
                / totalAllocationPointsCache;
            uint256 currentCash = totalAssetsAllocatableCache - $.totalAllocated;

            // Calculate available cash to put in strategies
            uint256 cashAvailable;
            unchecked {
                cashAvailable = (currentCash > targetCash) ? currentCash - targetCash : 0;

                amountToRebalance = targetAllocation - strategyData.allocated;
            }

            if (amountToRebalance > cashAvailable) {
                amountToRebalance = cashAvailable;
            }

            uint256 maxDepositInStrategy = IERC4626(_strategy).maxDeposit(address(this));
            if (amountToRebalance > maxDepositInStrategy) {
                amountToRebalance = maxDepositInStrategy;
            }

            isDeposit = true;
        }

        if (amountToRebalance == 0) {
            return;
        }

        if (isDeposit) {
            // Do required approval (safely) and deposit
            IERC20(_asset()).forceApprove(_strategy, amountToRebalance);
            IERC4626(_strategy).deposit(amountToRebalance, address(this));
            $.strategies[_strategy].allocated = (strategyData.allocated + amountToRebalance).toUint120();
            $.totalAllocated += amountToRebalance;
        } else {
            IERC4626(_strategy).withdraw(amountToRebalance, address(this), address(this));
            $.strategies[_strategy].allocated = (strategyData.allocated - amountToRebalance).toUint120();
            $.totalAllocated -= amountToRebalance;
        }

        emit Events.Rebalance(_strategy, amountToRebalance, isDeposit);
    }

    /// @notice Return the total amount of assets deposited, plus the accrued interest.
    /// @return total asset amount.
    function _totalAssets() private view returns (uint256) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        return $.totalAssetsDeposited + _interestAccruedFromCache($.interestLeft);
    }

    /// @dev Preview a harvest flow and return the expected result of `_totalAssets()` and `_totalSupply()` amount after a harvest.
    /// @return Expected amount to be returned from `_totalAssets()` if called after a harvest.
    /// @return Expected amount to be returned from `_totalSupply()` if called after a harvest.
    function previewHarvest() private view returns (uint256, uint256) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();

        uint256 totalAssetsDepositedExpected = $.totalAssetsDeposited;
        uint256 totalSupplyExpected = _totalSupply();
        uint168 interestLeftExpected = $.interestLeft;

        if ($.lastHarvestTimestamp + Constants.HARVEST_COOLDOWN >= block.timestamp) {
            return (totalAssetsDepositedExpected + _interestAccruedFromCache(interestLeftExpected), totalSupplyExpected);
        }

        uint256 totalPositiveYield;
        uint256 totalNegativeYield;
        for (uint256 i; i < $.withdrawalQueue.length; ++i) {
            address strategy = $.withdrawalQueue[i];
            uint120 strategyAllocatedAmount = $.strategies[strategy].allocated;

            if (strategyAllocatedAmount == 0 || $.strategies[strategy].status != IYieldAggregator.StrategyStatus.Active)
            {
                continue;
            }

            uint256 aggregatorShares = IERC4626(strategy).balanceOf(address(this));
            uint256 aggregatorAssets = IERC4626(strategy).previewRedeem(aggregatorShares);

            if (aggregatorAssets > strategyAllocatedAmount) {
                totalPositiveYield += aggregatorAssets - strategyAllocatedAmount;
            } else if (aggregatorAssets < strategyAllocatedAmount) {
                totalNegativeYield += strategyAllocatedAmount - aggregatorAssets;
            }
        }

        if (totalNegativeYield > totalPositiveYield) {
            interestLeftExpected = 0;

            uint256 totalNotDistributed = _totalAssetsAllocatable() - totalAssetsDepositedExpected;
            uint256 lossAmount;
            unchecked {
                lossAmount = totalNegativeYield - totalPositiveYield;
            }

            if (lossAmount > totalNotDistributed) {
                lossAmount -= totalNotDistributed;

                totalAssetsDepositedExpected -= lossAmount;
            }
        } else if (totalNegativeYield < totalPositiveYield) {
            uint96 cachedPerformanceFee = $.performanceFee;

            if ($.feeRecipient != address(0) && cachedPerformanceFee != 0) {
                uint256 yield;
                unchecked {
                    yield = totalPositiveYield - totalNegativeYield;
                }

                (uint256 feeAssets, uint256 feeShares) = _applyPerformanceFee(yield, cachedPerformanceFee);

                totalAssetsDepositedExpected += feeAssets;
                totalSupplyExpected += feeShares;
            }
        }

        // If there was no loss deduction, apply `_interestAccruedFromCache()`
        // We do not apply it if there was a call to `_deductLoss()` as: interestLeftExpected == 0 => _interestAccruedFromCache(interestLeftExpected) == 0
        if (interestLeftExpected != 0) {
            return (totalAssetsDepositedExpected + _interestAccruedFromCache(interestLeftExpected), totalSupplyExpected);
        }

        return (totalAssetsDepositedExpected, totalSupplyExpected);
    }

    function _simulateStrategiesWithdraw(uint256 _requestedAssets) private view returns (uint256) {
        YieldAggregatorStorage storage $ = Storage._getYieldAggregatorStorage();
        uint256 assetsRetrieved = IERC20(_asset()).balanceOf(address(this));

        if (assetsRetrieved < _requestedAssets) {
            uint256 numStrategies = $.withdrawalQueue.length;
            for (uint256 i; i < numStrategies; ++i) {
                IERC4626 strategy = IERC4626($.withdrawalQueue[i]);

                if ($.strategies[address(strategy)].status != IYieldAggregator.StrategyStatus.Active) continue;

                uint256 underlyingBalance = strategy.maxWithdraw(address(this));

                uint256 desiredAssets;
                unchecked {
                    desiredAssets = _requestedAssets - assetsRetrieved;
                }

                uint256 withdrawAmount = (underlyingBalance >= desiredAssets) ? desiredAssets : underlyingBalance;

                assetsRetrieved += withdrawAmount;

                if (assetsRetrieved >= _requestedAssets) {
                    break;
                }
            }
        }

        if (_requestedAssets > assetsRetrieved) _requestedAssets = assetsRetrieved;

        return _requestedAssets;
    }

    /// @dev Apply performance fee on `_yield` amount and return fee assets and shares amounts.
    /// @param _yield Amount of positive yield.
    /// @param _performanceFee Performance fee.
    /// @return Fee assets
    /// @return Fee shares
    function _applyPerformanceFee(uint256 _yield, uint96 _performanceFee) private view returns (uint256, uint256) {
        // `feeAssets` will be rounded down to 0 if `yield * performanceFee < 1e18`.
        uint256 feeAssets = _yield.mulDiv(_performanceFee, 1e18, Math.Rounding.Floor);
        uint256 feeShares = _convertToShares(feeAssets, Math.Rounding.Floor);

        return (feeAssets, feeShares);
    }
}

contract YieldAggregatorVault is YieldAggregatorVaultModule {
    constructor(address _evc) Shared(_evc) {}
}
