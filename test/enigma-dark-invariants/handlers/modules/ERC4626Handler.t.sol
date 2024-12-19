// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title ERC4626Handler
/// @notice Handler test contract for a set of actions
contract ERC4626Handler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function deposit(uint256 assets, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = address(eulerEulerEarnVault);

        uint256 previewedShares = eulerEulerEarnVault.previewDeposit(assets);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(IERC4626.deposit.selector, assets, receiver));

        if (success) {
            _after();

            uint256 shares = abi.decode(returnData, (uint256));

            _increaseGhostAssets(assets, address(receiver));
            _increaseGhostShares(shares, address(receiver));

            /// @dev ERC4626_DEPOSIT_INVARIANT_B
            assertLe(previewedShares, shares, ERC4626_DEPOSIT_INVARIANT_B);

            /// @dev HSPOST_USER_A
            assertEq(defaultVarsBefore.balance + assets, defaultVarsAfter.balance, HSPOST_USER_A);

            /// @dev HSPOST_USER_D
            if (defaultVarsBefore.totalSupply != 0) {
                assertEq(defaultVarsBefore.totalAssets + assets, defaultVarsAfter.totalAssets, HSPOST_USER_D);
            }

            /// @dev HSPOST_USER_F
            assertEq(defaultVarsBefore.balance + assets, defaultVarsAfter.balance, HSPOST_USER_F);

            /// @dev HSPOST_USER_G
            assertEq(
                defaultVarsBefore.totalAssetsDeposited + assets, defaultVarsAfter.totalAssetsDeposited, HSPOST_USER_F
            );

            /// @dev GPOST_BASE_D
            if (defaultVarsAfter.totalSupply > defaultVarsBefore.totalSupply) {
                assertGe(defaultVarsAfter.totalAssetsDeposited, defaultVarsBefore.totalAssetsDeposited, GPOST_BASE_D);
            }
        }
    }

    function mint(uint256 shares, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        address target = address(eulerEulerEarnVault);

        uint256 previewedAssets = eulerEulerEarnVault.previewMint(shares);

        _before();
        (success, returnData) = actor.proxy(target, abi.encodeWithSelector(IERC4626.mint.selector, shares, receiver));

        if (success) {
            _after();

            uint256 assets = abi.decode(returnData, (uint256));

            _increaseGhostAssets(assets, address(receiver));
            _increaseGhostShares(shares, address(receiver));

            /// @dev ERC4626_MINT_INVARIANT_B
            assertGe(previewedAssets, assets, ERC4626_MINT_INVARIANT_B);

            /// @dev HSPOST_USER_A
            assertEq(defaultVarsBefore.balance + assets, defaultVarsAfter.balance, HSPOST_USER_A);

            /// @dev HSPOST_USER_D
            if (defaultVarsBefore.totalSupply != 0) {
                assertEq(defaultVarsBefore.totalAssets + assets, defaultVarsAfter.totalAssets, HSPOST_USER_D);
            }

            /// @dev HSPOST_USER_F
            assertEq(defaultVarsBefore.balance + assets, defaultVarsAfter.balance, HSPOST_USER_F);

            /// @dev HSPOST_USER_G
            assertEq(
                defaultVarsBefore.totalAssetsDeposited + assets, defaultVarsAfter.totalAssetsDeposited, HSPOST_USER_F
            );

            /// @dev GPOST_BASE_D
            if (defaultVarsAfter.totalSupply > defaultVarsBefore.totalSupply) {
                assertGe(defaultVarsAfter.totalAssetsDeposited, defaultVarsBefore.totalAssetsDeposited, GPOST_BASE_D);
            }
        }
    }

    function withdraw(uint256 assets, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address target = address(eulerEulerEarnVault);

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        uint256 previewedShares = eulerEulerEarnVault.previewWithdraw(assets);

        (uint256 accumulatedPerformanceFee,) = _simulateHarvest(0);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC4626.withdraw.selector, assets, receiver, address(actor)));

        if (success) {
            _after();

            uint256 shares = abi.decode(returnData, (uint256));

            _decreaseGhostAssets(assets, address(actor));
            _decreaseGhostShares(shares, address(actor));

            /// @dev ERC4626_WITHDRAW_INVARIANT_B
            assertGe(previewedShares, shares, ERC4626_WITHDRAW_INVARIANT_B);

            /// @dev HSPOST_USER_B
            if (assets <= defaultVarsBefore.balance) {
                assertEq(defaultVarsBefore.balance - assets, defaultVarsAfter.balance, HSPOST_USER_B);
            } else {
                assertEq(0, defaultVarsAfter.balance, HSPOST_USER_B);

                /// @dev HSPOST_USER_C
                uint256 delta = assets - defaultVarsBefore.balance;
                assertEq(defaultVarsBefore.totalAllocated - delta, defaultVarsAfter.totalAllocated, HSPOST_USER_C);
            }

            /// @dev HSPOST_USER_E
            assertEq(defaultVarsBefore.totalAssets - assets, defaultVarsAfter.totalAssets, HSPOST_USER_E);
        }
    }

    function redeem(uint256 shares, uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address target = address(eulerEulerEarnVault);

        // Get one of the three actors randomly
        address receiver = _getRandomActor(i);

        uint256 previewedAssets = eulerEulerEarnVault.previewRedeem(shares);

        (uint256 accumulatedPerformanceFee,) = _simulateHarvest(0);

        _before();
        (success, returnData) =
            actor.proxy(target, abi.encodeWithSelector(IERC4626.redeem.selector, shares, receiver, address(actor)));

        if (success) {
            _after();

            uint256 assets = abi.decode(returnData, (uint256));

            _decreaseGhostAssets(assets, address(actor));
            _decreaseGhostShares(shares, address(actor));

            /// @dev ERC4626_REDEEM_INVARIANT_B
            assertLe(previewedAssets, assets, ERC4626_REDEEM_INVARIANT_B);

            /// @dev HSPOST_USER_B
            if (assets <= defaultVarsBefore.balance) {
                assertEq(defaultVarsBefore.balance - assets, defaultVarsAfter.balance, HSPOST_USER_B);
            } else {
                assertEq(0, defaultVarsAfter.balance, HSPOST_USER_B);

                /// @dev HSPOST_USER_C
                uint256 delta = assets - defaultVarsBefore.balance;
                assertEq(defaultVarsBefore.totalAllocated - delta, defaultVarsAfter.totalAllocated, HSPOST_USER_C);
            }

            /// @dev HSPOST_USER_E
            assertEq(
                defaultVarsBefore.totalAssets - assets,
                defaultVarsAfter.totalAssets - accumulatedPerformanceFee,
                HSPOST_USER_E
            );
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  NON-REVERT PROPERTIES                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_ERC4626_MINT_INVARIANT_C() public setup {
        address _account = address(actor);
        uint256 maxMint = eulerEulerEarnVault.maxMint(_account);
        uint256 accountBalance = assetTST.balanceOf(_account);

        uint256 maxMintToAssets = eulerEulerEarnVault.convertToAssets(maxMint) + 1;

        if (accountBalance < maxMintToAssets) {
            assetTST.mint(_account, maxMintToAssets - assetTST.balanceOf(_account));
        }

        vm.prank(_account);
        try eulerEulerEarnVault.mint(maxMint, _account) {}
        catch {
            assertTrue(false, ERC4626_MINT_INVARIANT_C);
        }
    }

    function assert_ERC4626_WITHDRAW_INVARIANT_C() public setup {
        require(eulerEulerEarnVault.totalSupply() != type(uint208).max);
        address _account = address(actor);
        uint256 maxWithdraw = eulerEulerEarnVault.maxWithdraw(_account);

        vm.prank(_account);
        if (eulerEulerEarnVault.totalSupply() != type(uint208).max) {
            try eulerEulerEarnVault.withdraw(maxWithdraw, _account, _account) {}
            catch {
                assertTrue(false, ERC4626_WITHDRAW_INVARIANT_C);
            }
        }
    }

    function assert_ERC4626_REDEEM_INVARIANT_C() public setup {
        require(eulerEulerEarnVault.totalSupply() != type(uint208).max);
        address _account = address(actor);
        uint256 maxRedeem = eulerEulerEarnVault.maxRedeem(_account);

        vm.prank(_account);
        try eulerEulerEarnVault.redeem(maxRedeem, _account, _account) {}
        catch {
            assertTrue(false, ERC4626_REDEEM_INVARIANT_C);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                               ROUNDTRIP PROPERTIES & CALLS                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function ERC4626_roundtrip_invariantA(uint256 _assets) external {
        _mintAndApprove(address(eulerEulerEarnVault.asset()), address(this), address(eulerEulerEarnVault), _assets);

        uint256 shares = eulerEulerEarnVault.deposit(_assets, address(this));

        uint256 redeemedAssets = eulerEulerEarnVault.redeem(shares, address(this), address(this));
    }

    function ERC4626_roundtrip_invariantB(uint256 _assets) external {
        _mintAndApprove(address(eulerEulerEarnVault.asset()), address(this), address(eulerEulerEarnVault), _assets);

        uint256 shares = eulerEulerEarnVault.deposit(_assets, address(this));

        uint256 withdrawnShares = eulerEulerEarnVault.withdraw(_assets, address(this), address(this));

        /// @dev restore original state to not break invariants
        eulerEulerEarnVault.redeem(eulerEulerEarnVault.balanceOf(address(this)), address(this), address(this));
    }

    function assert_ERC4626_roundtrip_invariantC(uint256 _shares) external {
        _mintApproveAndMint(address(eulerEulerEarnVault), address(this), _shares);

        uint256 redeemedAssets = eulerEulerEarnVault.redeem(_shares, address(this), address(this));

        uint256 mintedShares = eulerEulerEarnVault.deposit(redeemedAssets, address(this));

        /// @dev restore original state to not break invariants
        eulerEulerEarnVault.redeem(mintedShares, address(this), address(this));

        assertLe(mintedShares, _shares, ERC4626_ROUNDTRIP_INVARIANT_C);
    }

    function assert_ERC4626_roundtrip_invariantD(uint256 _shares) external {
        _mintApproveAndMint(address(eulerEulerEarnVault), address(this), _shares);

        uint256 redeemedAssets = eulerEulerEarnVault.redeem(_shares, address(this), address(this));

        uint256 depositedAssets = eulerEulerEarnVault.mint(_shares, address(this));

        /// @dev restore original state to not break invariants
        eulerEulerEarnVault.withdraw(depositedAssets, address(this), address(this));

        assertGe(depositedAssets, redeemedAssets, ERC4626_ROUNDTRIP_INVARIANT_D);
    }

    function ERC4626_roundtrip_invariantE(uint256 _shares) external {
        _mintAndApprove(
            address(eulerEulerEarnVault.asset()),
            address(this),
            address(eulerEulerEarnVault),
            eulerEulerEarnVault.convertToAssets(_shares)
        );

        uint256 depositedAssets = eulerEulerEarnVault.mint(_shares, address(this));

        uint256 withdrawnShares = eulerEulerEarnVault.withdraw(depositedAssets, address(this), address(this));

        /// @dev restore original state to not break invariants
        eulerEulerEarnVault.redeem(eulerEulerEarnVault.balanceOf(address(this)), address(this), address(this));
    }

    function ERC4626_roundtrip_invariantF(uint256 _shares) external {
        _mintAndApprove(
            address(eulerEulerEarnVault.asset()),
            address(this),
            address(eulerEulerEarnVault),
            eulerEulerEarnVault.convertToAssets(_shares)
        );

        uint256 depositedAssets = eulerEulerEarnVault.mint(_shares, address(this));

        uint256 redeemedAssets = eulerEulerEarnVault.redeem(_shares, address(this), address(this));
    }

    function assert_ERC4626_roundtrip_invariantG(uint256 _assets) external {
        _mintApproveAndDeposit(address(eulerEulerEarnVault), address(this), _assets);

        uint256 redeemedShares = eulerEulerEarnVault.withdraw(_assets, address(this), address(this));

        uint256 depositedAssets = eulerEulerEarnVault.mint(redeemedShares, address(this));

        /// @dev restore original state to not break invariants
        eulerEulerEarnVault.redeem(eulerEulerEarnVault.balanceOf(address(this)), address(this), address(this));

        assertGe(depositedAssets, _assets, ERC4626_ROUNDTRIP_INVARIANT_G);
    }

    function assert_ERC4626_roundtrip_invariantH(uint256 _assets) external {
        _mintApproveAndDeposit(address(eulerEulerEarnVault), address(this), _assets);

        uint256 redeemedShares = eulerEulerEarnVault.withdraw(_assets, address(this), address(this));

        uint256 mintedShares = eulerEulerEarnVault.deposit(_assets, address(this));

        /// @dev restore original state to not break invariants
        eulerEulerEarnVault.redeem(eulerEulerEarnVault.balanceOf(address(this)), address(this), address(this));

        assertLe(mintedShares, redeemedShares, ERC4626_ROUNDTRIP_INVARIANT_H);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
