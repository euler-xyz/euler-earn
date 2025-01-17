// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IEulerEarn} from "src/interface/IEulerEarn.sol";

// Libraries
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {TestERC20} from "../utils/mocks/TestERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "forge-std/console.sol";

// Contracts
import {Actor} from "../utils/Actor.sol";
import {HookAggregator} from "../hooks/HookAggregator.t.sol";

/// @title BaseHandler
/// @notice Contains common logic for all handlers
/// @dev inherits all suite assertions since per action assertions are implmenteds in the handlers
contract BaseHandler is HookAggregator {
    using EnumerableSet for EnumerableSet.UintSet;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SHARED VARAIBLES                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // ERC20

    /// @notice Sum of all balances in the vault
    uint256 internal ghost_sumBalances;

    /// @notice Sum of all balances per user in the vault
    mapping(address => uint256) internal ghost_sumBalancesPerUser;

    /// @notice Sum of all shares balances in the vault
    uint256 internal ghost_sumSharesBalances;

    /// @notice Sum of all shares balances per user in the vault
    mapping(address => uint256) internal ghost_sumSharesBalancesPerUser;

    // ERC4626

    /// @notice Track of the total amount borrowed
    uint256 internal ghost_totalBorrowed;

    /// @notice Track of the total amount borrowed per user
    mapping(address => uint256) internal ghost_owedAmountPerUser;

    /// @notice Track the enabled collaterals per user
    mapping(address => EnumerableSet.AddressSet) internal ghost_accountCollaterals;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   HELPERS: RANDOM GETTERS                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Helper function to get a random base asset
    function _getRandomBaseAsset(uint256 _i) internal view returns (address) {
        uint256 _baseAssetIndex = _i % baseAssets.length;
        return baseAssets[_baseAssetIndex];
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                             HELPERS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _simulateHarvest(uint256 _totalAssetsDeposited)
        internal
        view
        returns (uint256, uint256, uint256, uint256)
    {
        // track total yield and total loss to simulate loss socialization
        uint256 totalYield;
        uint256 totalLoss;

        // check if performance fee is on; store received fee per recipient if call is succesfull
        (address feeRecipient_, uint256 performanceFee) = eulerEulerEarnVault.performanceFeeConfig();
        uint256 accumulatedPerformanceFee;

        address[] memory withdrawalQueueArray = eulerEulerEarnVault.withdrawalQueue();
        for (uint256 i; i < withdrawalQueueArray.length; i++) {
            if ((eulerEulerEarnVault.getStrategy(withdrawalQueueArray[i])).status != IEulerEarn.StrategyStatus.Active) {
                continue;
            }

            uint256 allocated = (eulerEulerEarnVault.getStrategy(withdrawalQueueArray[i])).allocated;

            uint256 eulerEarnShares = IERC4626(withdrawalQueueArray[i]).balanceOf(address(eulerEulerEarnVault));
            uint256 underlying = IERC4626(withdrawalQueueArray[i]).previewRedeem(eulerEarnShares);
            if (underlying >= allocated) {
                totalYield += underlying - allocated;
            } else {
                totalLoss += allocated - underlying;
            }
        }

        if (totalYield > totalLoss) {
            if (feeRecipient_ != address(0) && performanceFee > 0) {
                uint256 performancefeeAssets =
                    Math.mulDiv(totalYield - totalLoss, performanceFee, 1e18, Math.Rounding.Floor);
                accumulatedPerformanceFee = eulerEulerEarnVault.previewDeposit(performancefeeAssets);

                _totalAssetsDeposited += performancefeeAssets;
            }
        } else if (totalYield < totalLoss) {
            _totalAssetsDeposited = _simulateLossDeduction(_totalAssetsDeposited, totalLoss - totalYield);
        }

        return (accumulatedPerformanceFee, _totalAssetsDeposited, totalYield, totalLoss);
    }

    function _simulateLossDeduction(uint256 cachedGhostTotalAssetsDeposited, uint256 _loss)
        private
        view
        returns (uint256)
    {
        // (,, uint168 interestLeft) = eulerEarn.getEulerEarnSavingRate();
        uint256 totalNotDistributed = eulerEulerEarnVault.totalAssetsAllocatable() - cachedGhostTotalAssetsDeposited;

        if (_loss > totalNotDistributed) {
            cachedGhostTotalAssetsDeposited -= (_loss - totalNotDistributed);
        }

        return cachedGhostTotalAssetsDeposited;
    }

    /// @notice Helper function to randomize a uint256 seed with a string salt
    function _randomize(uint256 seed, string memory salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, salt)));
    }

    /// @notice Helper function to get a random value
    function _getRandomValue(uint256 modulus) internal view returns (uint256) {
        uint256 randomNumber = uint256(keccak256(abi.encode(block.timestamp, block.prevrandao, msg.sender)));
        return randomNumber % modulus; // Adjust the modulus to the desired range
    }

    /// @notice Helper function to approve an amount of tokens to a spender, a proxy Actor
    function _approve(address token, Actor actor_, address spender, uint256 amount) internal {
        bool success;
        bytes memory returnData;
        (success, returnData) = actor_.proxy(token, abi.encodeWithSelector(0x095ea7b3, spender, amount));
        require(success, string(returnData));
    }

    /// @notice Helper function to safely approve an amount of tokens to a spender

    function _approve(address token, address owner, address spender, uint256 amount) internal {
        vm.prank(owner);
        _safeApprove(token, spender, 0);
        vm.prank(owner);
        _safeApprove(token, spender, amount);
    }

    /// @notice Helper function to safely approve an amount of tokens to a spender
    /// @dev This function is used to revert on failed approvals
    function _safeApprove(address token, address spender, uint256 amount) internal {
        (bool success, bytes memory retdata) =
            token.call(abi.encodeWithSelector(IERC20.approve.selector, spender, amount));
        assert(success);
        if (retdata.length > 0) assert(abi.decode(retdata, (bool)));
    }

    /// @notice Helper function to mint an amount of tokens to an address
    function _mint(address token, address receiver, uint256 amount) internal {
        TestERC20(token).mint(receiver, amount);
    }

    /// @notice Helper function to mint an amount of tokens to an address and approve them to a spender
    /// @param token Address of the token to mint
    /// @param owner Address of the new owner of the tokens
    /// @param spender Address of the spender to approve the tokens to
    /// @param amount Amount of tokens to mint and approve
    function _mintAndApprove(address token, address owner, address spender, uint256 amount) internal {
        _mint(token, owner, amount);
        _approve(token, owner, spender, amount);
    }

    function _mintApproveAndDeposit(address vault, address owner, uint256 amount) internal {
        _mintAndApprove(address(eulerEulerEarnVault.asset()), owner, vault, amount * 2);
        vm.prank(owner);
        eulerEulerEarnVault.deposit(amount, owner);
    }

    function _mintApproveAndMint(address vault, address owner, uint256 amount) internal {
        _mintAndApprove(
            address(eulerEulerEarnVault.asset()), owner, vault, eulerEulerEarnVault.convertToAssets(amount) * 2
        );
        eulerEulerEarnVault.mint(amount, owner);
    }

    function _getToGulp() internal view returns (uint256) {
        (,, uint168 interestLeft) = eulerEulerEarnVault.getEulerEarnSavingRate();
        return eulerEulerEarnVault.totalAssetsAllocatable() - eulerEulerEarnVault.totalAssetsDeposited() - interestLeft;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              HELPERS: GHOST VARIABLE UPDATES                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _increaseGhostAssets(uint256 assets, address receiver) internal {
        ghost_sumBalances += assets;
        ghost_sumBalancesPerUser[receiver] += assets;
    }

    function _decreaseGhostAssets(uint256 assets, address owner) internal {
        ghost_sumBalances -= assets;
        ghost_sumBalancesPerUser[owner] -= assets;
    }

    function _increaseGhostShares(uint256 shares, address receiver) internal {
        ghost_sumSharesBalances += shares;
        ghost_sumSharesBalancesPerUser[receiver] += shares;
    }

    function _decreaseGhostShares(uint256 shares, address owner) internal {
        ghost_sumSharesBalances -= shares;
        ghost_sumSharesBalancesPerUser[owner] -= shares;
    }
}
