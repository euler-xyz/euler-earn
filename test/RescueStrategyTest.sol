// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {IEulerEarn} from "../src/interfaces/IEulerEarn.sol";
import {IEulerEarnFactory} from "../src/interfaces/IEulerEarnFactory.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {RescueStrategy} from "../src/RescueStrategy.sol";
import {EulerEarnVaultLens as EarnIndexerLens, EulerEarnVaultInfoFull} from "../lib/euler-data-lenses/src/EulerEarnLens.sol";
import "forge-std/Test.sol";

contract RescuePOC is Test {
    // the earn vault to rescue:
    address constant EARN_VAULT = 0x3B4802FDb0E5d74aA37d58FD77d63e93d4f9A4AF; // https://app.euler.finance/earn/0x3B4802FDb0E5d74aA37d58FD77d63e93d4f9A4AF?network=ethereum

    address constant OTHER_EARN_VAULT = 0x3cd3718f8f047aA32F775E2cb4245A164E1C99fB; // https://app.euler.finance/earn/0x3cd3718f8f047aA32F775E2cb4245A164E1C99fB?network=ethereum
    address constant FLASH_LOAN_SOURCE_MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant FLASH_LOAN_SOURCE_EULER = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9; // Euler Prime - also a strategy in earn
    address constant FLASH_LOAN_SOURCE_AAVE = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant EARN_LENS = 0xA09144BeAe23D8e7836Aeb0Fe17DD2647241A8bE;
    address constant EVAULT_LENS = 0xc3c45633E45041BF3BE841f89d2cb51E2F657403;
    uint256 constant BLOCK_NUMBER = 23753054;

    IEulerEarn vault;
    IEulerEarn otherVault;

    EarnIndexerLens indexerLens;

    string FORK_RPC_URL = vm.envOr("FORK_RPC_URL_MAINNET", string(""));

    uint256 fork;

    address rescueAccount = makeAddr("rescueAccount");
    address user = makeAddr("user");
    RescueStrategy rescueStrategy;

    function setUp() public {
        require(bytes(FORK_RPC_URL).length != 0, "No FORK_RPC_URL env found");

        fork = vm.createSelectFork(FORK_RPC_URL);
        if (BLOCK_NUMBER > 0) {
            vm.rollFork(BLOCK_NUMBER);
        }

        vault = IEulerEarn(EARN_VAULT);
        otherVault = IEulerEarn(OTHER_EARN_VAULT); // hyperithm euler usdc mainnet

        deal(vault.asset(), user, 100e18);
        vm.startPrank(user);
        IERC20(vault.asset()).approve(vault.permit2Address(), type(uint256).max);
        IAllowanceTransfer(vault.permit2Address()).approve(
            vault.asset(), address(vault), type(uint160).max, type(uint48).max
        );

        indexerLens = new EarnIndexerLens();
    }

    function testRescue_assertRescueMode() public {
        _installPerspective();

        rescueStrategy = new RescueStrategy(rescueAccount, address(vault));
        IERC4626 id = IERC4626(address(rescueStrategy));

        vm.prank(rescueAccount);
        vm.expectRevert("rescue: supplyQueue len != 1");
        rescueStrategy.rescueEulerBatch(1, 1, FLASH_LOAN_SOURCE_EULER);

        IERC4626[] memory supplyQueue = new IERC4626[](1);
        supplyQueue[0] = vault.supplyQueue(0);

        vm.prank(vault.curator());
        vault.setSupplyQueue(supplyQueue);

        vm.prank(rescueAccount);
        vm.expectRevert("rescue: supplyQueue[0] != rescue");
        rescueStrategy.rescueEulerBatch(1, 1, FLASH_LOAN_SOURCE_EULER);

        vm.prank(vault.curator());
        vault.submitCap(id, type(uint184).max);

        skip(vault.timelock());

        vm.prank(vault.curator());
        vault.acceptCap(id);
        supplyQueue[0] = id;

        vm.prank(vault.curator());
        vault.setSupplyQueue(supplyQueue);

        vm.prank(rescueAccount);
        vm.expectRevert("rescue: withdrawQueue[0] != rescue");
        rescueStrategy.rescueEulerBatch(1, 1, FLASH_LOAN_SOURCE_EULER);
    }

    function testRescue_pauseForUsers() public {
        _installRescueStrategy();

        vm.startPrank(user);
        vm.expectRevert("vault operations are paused");
        vault.deposit(10, user);
        vm.expectRevert("vault operations are paused");
        vault.mint(10, user);
        vm.expectRevert("vault operations are paused");
        vault.withdraw(0, user, user);
        vm.expectRevert("vault operations are paused");
        vault.redeem(0, user, user);

        assertEq(vault.maxWithdrawFromStrategy(IERC4626(address(rescueStrategy))), 0);
    }

    mapping (address => uint256) strategyCaps;
    function testRescue_rescueEulerBatch() public {
        _installRescueStrategy();

        uint256 withdrawQueueLength = vault.withdrawQueueLength();

        for (uint256 i = 0; i < withdrawQueueLength; i++) {
            address strategy = address(vault.withdrawQueue(i));
            strategyCaps[strategy] = vault.config(vault.withdrawQueue(i)).cap;
        }

        uint256 amount = 100_000e6;
        uint256 loops = 1;
        uint256 snapshot = vm.snapshotState();
        // only rescue account
        vm.prank(user);
        vm.expectRevert("unauthorized");
        rescueStrategy.rescueEulerBatch(amount, loops, FLASH_LOAN_SOURCE_EULER);

        vm.startPrank(rescueAccount);
        vm.expectEmit(true, true, false, false);
        emit RescueStrategy.Rescued(address(vault), 0);
        rescueStrategy.rescueEulerBatch(amount, loops, FLASH_LOAN_SOURCE_EULER);

        assertGt(IERC20(vault.asset()).balanceOf(rescueAccount), 0);
        assertEq(IEVC(vault.EVC()).getControllers(address(rescueStrategy)).length, 0);
        uint256 rescueOneLoop = IERC20(vault.asset()).balanceOf(rescueAccount);

        console.log("Rescued", rescueOneLoop, IEulerEarn(vault.asset()).symbol());
        console.log("Received shares", IERC4626(vault).balanceOf(rescueAccount));

        vm.revertToState(snapshot);
        loops = 2;

        rescueStrategy.rescueEulerBatch(amount, loops, FLASH_LOAN_SOURCE_EULER);
        assertEq(IERC20(vault.asset()).balanceOf(rescueAccount), rescueOneLoop * 2);

        // caps are unchanged on other strategies

        for (uint256 i = 0; i < withdrawQueueLength; i++) {
            address strategy = address(vault.withdrawQueue(i));
            if (strategy != address(rescueStrategy)) {
                assertEq(strategyCaps[strategy], vault.config(vault.withdrawQueue(i)).cap);
            }
        }
    }

    function testRescue_rescueMorpho() public {
        _installRescueStrategy();

        // create shares equal total supply + extra
        uint256 amount = vault.previewMint(vault.totalSupply()) * 10001 / 10000 / 2;
        uint256 loops = 2;

        // only rescue account
        vm.prank(user);
        vm.expectRevert("unauthorized");
        rescueStrategy.rescueMorpho(amount, loops, FLASH_LOAN_SOURCE_MORPHO);

        vm.startPrank(rescueAccount);
        rescueStrategy.rescueMorpho(amount, loops, FLASH_LOAN_SOURCE_MORPHO);

        assertGt(IERC20(vault.asset()).balanceOf(rescueAccount), 0);

        console.log("Rescued", IERC20(vault.asset()).balanceOf(rescueAccount), IEulerEarn(vault.asset()).symbol());
        console.log("Received shares", IERC4626(vault).balanceOf(rescueAccount));
    }

    function testRescue_rescueAave() public {
        _installRescueStrategy();

        uint256 amount = 5_000_000e6;
        uint256 loops = 1;
        address feeProvider = makeAddr("feeProvider");
        address asset = vault.asset();

        // only rescue account
        vm.prank(user);
        vm.expectRevert("unauthorized");
        rescueStrategy.rescueAave(amount, loops, FLASH_LOAN_SOURCE_AAVE, feeProvider);

        vm.prank(rescueAccount);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        rescueStrategy.rescueAave(amount, loops, FLASH_LOAN_SOURCE_AAVE, feeProvider);

        deal(asset, feeProvider, amount * 5 / 10000);
        vm.prank(feeProvider);
        IERC20(asset).approve(address(rescueStrategy), type(uint256).max);

        vm.prank(rescueAccount);
        rescueStrategy.rescueAave(amount, loops, FLASH_LOAN_SOURCE_AAVE, feeProvider);

        assertGt(IERC20(asset).balanceOf(rescueAccount), 0);

        console.log("Rescued", IERC20(asset).balanceOf(rescueAccount), IEulerEarn(vault.asset()).symbol());
        console.log("Received shares", IERC4626(vault).balanceOf(rescueAccount));
    }

    function testRescue_rescueMultipleMorpho() public {
        _installRescueStrategy();

        uint256 amount = 1000000000000;
        uint256 loops = 1;

        vm.startPrank(rescueAccount);
        rescueStrategy.rescueMorpho(amount, loops, FLASH_LOAN_SOURCE_MORPHO);
        rescueStrategy.rescueMorpho(amount, loops, FLASH_LOAN_SOURCE_MORPHO);
        rescueStrategy.rescueMorpho(amount, loops, FLASH_LOAN_SOURCE_MORPHO);

        assertGt(IERC20(vault.asset()).balanceOf(rescueAccount), 0);

        console.log("Rescued", IERC20(vault.asset()).balanceOf(rescueAccount), IEulerEarn(vault.asset()).symbol());
        console.log("Received shares", IERC4626(vault).balanceOf(rescueAccount));
    }

    function testRescue_rescueAccountCantWithdrawOutsideRescue() public {
        _installRescueStrategy();

        vm.prank(user);
        vm.expectRevert("vault operations are paused");
        vault.withdraw(1e6, user, user);

        deal(address(vault), rescueAccount, 1e6);

        vm.prank(rescueAccount);
        vm.expectRevert("vault operations are paused");
        vault.withdraw(1e6, rescueAccount, rescueAccount);
    }

    function testRescue_cantBeReused() public {
        rescueStrategy = new RescueStrategy(rescueAccount, address(vault));

        // install perspective in earn factory which will allow custom strategies
        _installPerspective();

        vm.startPrank(otherVault.curator());

        otherVault.submitCap(IERC4626(address(rescueStrategy)), type(uint184).max);
        skip(vault.timelock());

        vm.expectRevert("wrong vault");
        otherVault.acceptCap(IERC4626(address(rescueStrategy)));
    }

    function testRescue_uninstall() public {
        _installRescueStrategy();

        // exchange rate should remain constant (besides rounding)
        uint256 sharePriceBefore = vault.convertToAssets(1e18);
        uint256 lostAssetsBefore = vault.lostAssets();

        vm.startPrank(user);
        vm.expectRevert("vault operations are paused");
        vault.deposit(10, user);

        // rescue
        uint256 amount = vault.previewMint(vault.totalSupply()) * 10001 / 10000 ;
        uint256 loops = 1;

        vm.startPrank(rescueAccount);
        rescueStrategy.rescueMorpho(amount, loops, FLASH_LOAN_SOURCE_MORPHO);

        assertApproxEqAbs(sharePriceBefore, vault.convertToAssets(1e18), 1e5);
        // all the deposited amount is counted as lost
        assertEq(vault.lostAssets(), lostAssetsBefore + amount);

        vm.startPrank(vault.curator());

        IERC4626 id = IERC4626(address(rescueStrategy));
        vault.submitCap(id, 0);

        uint256 withdrawQueueLength = vault.withdrawQueueLength();
        uint256[] memory newIndexes = new uint256[](withdrawQueueLength - 1);
        newIndexes[0] = withdrawQueueLength - 1;

        for (uint256 i = 1; i < withdrawQueueLength; i++) {
            newIndexes[i - 1] = i;
        }

        vault.updateWithdrawQueue(newIndexes);

        IERC4626[] memory supplyQueue = new IERC4626[](1);
        supplyQueue[0] = vault.withdrawQueue(0);
        vault.setSupplyQueue(supplyQueue);

        // the vault is functional

        assertApproxEqAbs(sharePriceBefore, vault.convertToAssets(1e18), 1e5);

        vm.startPrank(user);
        vault.deposit(10, user);
        uint256 balance = vault.balanceOf(user);
        assertGt(balance, 0);
        vault.mint(10, user);
        assertEq(vault.balanceOf(user), balance + 10);
        vault.redeem(10, user, user);
        assertEq(vault.balanceOf(user), balance);
        vault.withdraw(vault.maxWithdraw(user), user, user);
        assertEq(vault.balanceOf(user), 0);

        assertApproxEqAbs(sharePriceBefore, vault.convertToAssets(1e18), 1e6);
    }

    function testRescue_onlyRescueAccountCallFunc() external {
        _installRescueStrategy();

        vm.prank(user);
        vm.expectRevert("unauthorized");
        rescueStrategy.call(address(0), "");

        vm.prank(rescueAccount);
        rescueStrategy.call(address(0), "");
    }

    function testRescue_flashloanCallbacks() external {
        _installRescueStrategy();

        vm.expectRevert("unauthorized");
        rescueStrategy.onBatchLoan(1, 1);
        vm.expectRevert("unauthorized");
        rescueStrategy.onFlashLoan("");
        vm.expectRevert("unauthorized");
        rescueStrategy.onMorphoFlashLoan(1, "");
        vm.expectRevert("unauthorized");
        rescueStrategy.executeOperation(address(1), 1, 1, address(1), "");
    }

    function testRescue_callLenses() external {
        _installRescueStrategy();
        // lens calls don't revert

        // onchain lens
        (bool success, bytes memory data) = EARN_LENS.call(abi.encodeWithSignature("getVaultInfoFull(address)", address(vault)));
        assertTrue(success && data.length > 0);

        // lens used in the indexer by setting the `code` in eth_call
        EulerEarnVaultInfoFull memory lensData = indexerLens.getVaultInfoFull(address(vault));
        assertEq(lensData.vault, address(vault));

        // evault lens
        (success, data) = EVAULT_LENS.call(abi.encodeWithSignature("getVaultInfoFull(address)", address(rescueStrategy)));
        assertTrue(success && data.length > 0);
    }

    function testRescue_maxWithdrawView() external {
        _installRescueStrategy();
        vm.prank(user);
        assertEq(rescueStrategy.maxWithdraw(user), 0);

        vm.startPrank(address(vault));
        assertEq(rescueStrategy.maxWithdraw(user), 0);
    }

    function testRescue_maxDepositView() external {
        _installRescueStrategy();
        vm.prank(user);
        assertEq(rescueStrategy.maxDeposit(user), 0);

        vm.startPrank(address(vault));
        assertEq(rescueStrategy.maxDeposit(user), 0);
    }

    function testRescue_deposit() external {
        _installRescueStrategy();
        vm.prank(user);
        vm.expectRevert("not supported");
        rescueStrategy.deposit(1, user);

        vm.prank(address(vault));
        vm.expectRevert("only during rescue");
        rescueStrategy.deposit(1, address(vault));
    }

    function testRescue_balanceOfView() external {
        _installRescueStrategy();
        vm.prank(user);
        assertEq(rescueStrategy.balanceOf(user), 0);

        vm.startPrank(address(vault));
        assertEq(rescueStrategy.balanceOf(user), 0);

        vm.startPrank(address(otherVault));
        vm.expectRevert("wrong vault");
        rescueStrategy.balanceOf(user);

    }

    function _installRescueStrategy() internal {
        // install perspective in earn factory which will allow custom strategies (use mock here)
        _installPerspective();

        // deploy strategy, set a cap for it and put in in the supply and withdraw queues
        rescueStrategy = new RescueStrategy(rescueAccount, address(vault));

        vm.startPrank(vault.curator());

        IERC4626 id = IERC4626(address(rescueStrategy));

        vault.submitCap(id, type(uint184).max);

        skip(vault.timelock());

        vault.acceptCap(id);

        IERC4626[] memory supplyQueue = new IERC4626[](1);
        supplyQueue[0] = id;

        vault.setSupplyQueue(supplyQueue);

        // move the new strategy to the front of the queue
        uint256 withdrawQueueLength = vault.withdrawQueueLength();
        uint256[] memory newIndexes = new uint256[](withdrawQueueLength);
        newIndexes[0] = withdrawQueueLength - 1;

        for (uint256 i = 1; i < withdrawQueueLength; i++) {
            newIndexes[i] = i - 1;
        }

        vault.updateWithdrawQueue(newIndexes);

        vm.stopPrank();
    }

    function _installPerspective() internal {
        vm.startPrank(Ownable(vault.creator()).owner());

        IEulerEarnFactory factory = IEulerEarnFactory(vault.creator());
        factory.setPerspective(address(new MockPerspective()));

        vm.stopPrank();
    }
}

contract MockPerspective {
    function isVerified(address) external pure returns (bool) {
        return true;
    }
}
