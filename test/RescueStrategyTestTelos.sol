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
import {IEVault} from "../lib/euler-vault-kit/src/EVault/IEVault.sol";
import "forge-std/Test.sol";

contract RescuePOC is Test {
    
    // address constant EARN_VAULT = 0x3B4802FDb0E5d74aA37d58FD77d63e93d4f9A4AF; // https://app.euler.finance/earn/0x3B4802FDb0E5d74aA37d58FD77d63e93d4f9A4AF?network=ethereum

    // address constant OTHER_EARN_VAULT = 0x3cd3718f8f047aA32F775E2cb4245A164E1C99fB; // https://app.euler.finance/earn/0x3cd3718f8f047aA32F775E2cb4245A164E1C99fB?network=ethereum
    // address constant FLASH_LOAN_SOURCE_MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    // address constant FLASH_LOAN_SOURCE_EULER = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9; // Euler Prime - also a strategy in earn
    // address constant FLASH_LOAN_SOURCE_AAVE = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    // uint256 constant BLOCK_NUMBER = 23753054;

    // TELOS WBTC
    // address constant EARN_VAULT = 0xA5cbf5cd429af63EA9989aE1ff4C9d37acFa6767; // https://app.euler.finance/earn/0x3B4802FDb0E5d74aA37d58FD77d63e93d4f9A4AF?network=ethereum
    // address constant RESCUE_STRATEGY = 0x79E41D6B7B2171AEe1c855eD1a0ae98a00c8942E;
    // address constant RESCUE_ACCOUNT = 0x1b81cE5C6E1B206f3C20716571e295849eE8E440;
    // address constant FLASH_LOAN_SOURCE_MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    // address constant FLASH_LOAN_SOURCE_EULER = 0x998D761eC1BAdaCeb064624cc3A1d37A46C88bA4; // Euler Prime - also a strategy in earn
    // address constant FLASH_LOAN_SOURCE_AAVE = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    // uint256 constant AAVE_AMOUNT = 100e8;
    // uint256 constant BLOCK_NUMBER = 23826172;

    // TELOS WETH
    // address constant EARN_VAULT = 0xd217A07493b6BA272Ff806EE5eaBdFF86C292cc6; // https://app.euler.finance/earn/0x3B4802FDb0E5d74aA37d58FD77d63e93d4f9A4AF?network=ethereum
    // address constant RESCUE_STRATEGY = 0xA2369184C6C167Bce403d70571A478b289FC5e0D;
    // address constant RESCUE_ACCOUNT = 0x1b81cE5C6E1B206f3C20716571e295849eE8E440;
    // address constant FLASH_LOAN_SOURCE_MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    // address constant FLASH_LOAN_SOURCE_EULER = 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2; // Euler Prime - also a strategy in earn
    // address constant FLASH_LOAN_SOURCE_AAVE = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    // uint256 constant AAVE_AMOUNT = 100e18;
    // uint256 constant BLOCK_NUMBER = 23826172;

    // TELOS USDC
    // address constant EARN_VAULT = 0x49C5733d71511A78a3E12925ea832f49031c97e9;
    // address constant RESCUE_STRATEGY = 0x1BB6f40AE469C2664815E45f5Fb771Ef3Fcb751d;
    // address constant RESCUE_ACCOUNT = 0x1b81cE5C6E1B206f3C20716571e295849eE8E440;
    // address constant FLASH_LOAN_SOURCE_MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    // address constant FLASH_LOAN_SOURCE_EULER = 0xAB2726DAf820Aa9270D14Db9B18c8d187cbF2f30; // Euler Prime - also a strategy in earn
    // address constant FLASH_LOAN_SOURCE_AAVE = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    // uint256 constant AAVE_AMOUNT = 1_000_000e6;
    // uint256 constant BLOCK_NUMBER = 23826172;

    // TELOS USDT0
    address constant EARN_VAULT = 0xa9C251F8304b1B3Fc2b9e8fcae78D94Eff82Ac66;
    address constant RESCUE_STRATEGY = 0xcbE1A31931aA9108E2eDbcd8008B16e4f6Be91B7;
    address constant RESCUE_ACCOUNT = 0x1b81cE5C6E1B206f3C20716571e295849eE8E440;
    address constant FLASH_LOAN_SOURCE_MORPHO = 0x2fF74A46536f5c67ef5A42FD5B4e2Ed8A2cee249;
    address constant FLASH_LOAN_SOURCE_EULER = 0x8Aec278c2fD4cc07B10A8865AEd33775f93EACe6; // Euler Prime - also a strategy in earn
    address constant FLASH_LOAN_SOURCE_AAVE = 0x925a2A7214Ed92428B5b1B090F80b25700095e12;
    uint256 constant AAVE_AMOUNT = 1_000_000e6;
    uint256 constant BLOCK_NUMBER = 6548274;

    IEulerEarn vault;

    string FORK_RPC_URL = vm.envOr("FORK_RPC_URL_MAINNET", string(""));

    uint256 fork;

    address rescueAccount = RESCUE_ACCOUNT;
    address user = makeAddr("user");
    RescueStrategy rescueStrategy;

    function setUp() public {
        require(bytes(FORK_RPC_URL).length != 0, "No FORK_RPC_URL env found");

        fork = vm.createSelectFork(FORK_RPC_URL);
        if (BLOCK_NUMBER > 0) {
            vm.rollFork(BLOCK_NUMBER);
        }

        vault = IEulerEarn(EARN_VAULT);

        deal(vault.asset(), user, 100e18);
        vm.startPrank(user);
        IERC20(vault.asset()).approve(vault.permit2Address(), type(uint256).max);
        IAllowanceTransfer(vault.permit2Address()).approve(
            vault.asset(), address(vault), type(uint160).max, type(uint48).max
        );
    }

    // function testRescueTelos_assertRescueMode() public {
    //     _installPerspective();

    //     rescueStrategy = new RescueStrategy(rescueAccount, address(vault));
    //     IERC4626 id = IERC4626(address(rescueStrategy));

    //     vm.prank(rescueAccount);
    //     vm.expectRevert("rescue: supplyQueue len != 1");
    //     rescueStrategy.rescueEulerBatch(1, 1, FLASH_LOAN_SOURCE_EULER);

    //     IERC4626[] memory supplyQueue = new IERC4626[](1);
    //     supplyQueue[0] = vault.supplyQueue(0);

    //     vm.prank(vault.curator());
    //     vault.setSupplyQueue(supplyQueue);

    //     vm.prank(rescueAccount);
    //     vm.expectRevert("rescue: supplyQueue[0] != rescue");
    //     rescueStrategy.rescueEulerBatch(1, 1, FLASH_LOAN_SOURCE_EULER);

    //     vm.prank(vault.curator());
    //     vault.submitCap(id, type(uint184).max);

    //     skip(vault.timelock());

    //     vm.prank(vault.curator());
    //     vault.acceptCap(id);
    //     supplyQueue[0] = id;

    //     vm.prank(vault.curator());
    //     vault.setSupplyQueue(supplyQueue);

    //     vm.prank(rescueAccount);
    //     vm.expectRevert("rescue: withdrawQueue[0] != rescue");
    //     rescueStrategy.rescueEulerBatch(1, 1, FLASH_LOAN_SOURCE_EULER);
    // }

    function testRescueTelos_pauseForUsers() public {
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
    }

    function testRescueTelos_rescueEulerBatch() public {
        _installRescueStrategy();

        uint256 amount = IEVault(FLASH_LOAN_SOURCE_EULER).cash();
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
        if (IERC4626(vault).balanceOf(rescueAccount) == 0) {
            vm.revertTo(snapshot);
            loops = 2;

            rescueStrategy.rescueEulerBatch(amount, loops, FLASH_LOAN_SOURCE_EULER);
            assertEq(IERC20(vault.asset()).balanceOf(rescueAccount), rescueOneLoop * 2);
        }
    }

    function testRescueTelos_rescueMorpho() public {
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

    function testRescueTelos_rescueAave() public {
        _installRescueStrategy();

        uint256 amount = AAVE_AMOUNT;
        uint256 loops = 1;
        address feeProvider = makeAddr("feeProvider");
        address asset = vault.asset();
        console.log('asset: ', asset);

        // only rescue account
        vm.prank(user);
        vm.expectRevert("unauthorized");
        rescueStrategy.rescueAave(amount, loops, FLASH_LOAN_SOURCE_AAVE, feeProvider);

        vm.prank(rescueAccount);
        vm.expectRevert();
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

    function testRescueTelos_rescueMultipleMorpho() public {
        _installRescueStrategy();

        uint256 amount = IERC20(vault.asset()).balanceOf(FLASH_LOAN_SOURCE_MORPHO);
        uint256 loops = 1;

        vm.startPrank(rescueAccount);
        rescueStrategy.rescueMorpho(amount, loops, FLASH_LOAN_SOURCE_MORPHO);
        rescueStrategy.rescueMorpho(amount, loops, FLASH_LOAN_SOURCE_MORPHO);
        rescueStrategy.rescueMorpho(amount, loops, FLASH_LOAN_SOURCE_MORPHO);

        assertGt(IERC20(vault.asset()).balanceOf(rescueAccount), 0);

        console.log("Rescued", IERC20(vault.asset()).balanceOf(rescueAccount), IEulerEarn(vault.asset()).symbol());
        console.log("Received shares", IERC4626(vault).balanceOf(rescueAccount));
    }

    function testRescueTelos_rescueAccountCantWithdrawOutsideRescue() public {
        _installRescueStrategy();

        vm.prank(user);
        vm.expectRevert("vault operations are paused");
        vault.withdraw(1e6, user, user);

        deal(address(vault), rescueAccount, 1e6);

        vm.prank(rescueAccount);
        vm.expectRevert("vault operations are paused");
        vault.withdraw(1e6, rescueAccount, rescueAccount);
    }

    // function testRescueTelos_cantBeReused() public {
    //     rescueStrategy = new RescueStrategy(rescueAccount, address(vault));

    //     // install perspective in earn factory which will allow custom strategies
    //     _installPerspective();

    //     IEulerEarn otherVault = IEulerEarn(OTHER_EARN_VAULT); // hyperithm euler usdc mainnet

    //     vm.startPrank(otherVault.curator());

    //     otherVault.submitCap(IERC4626(address(rescueStrategy)), type(uint184).max);
    //     skip(vault.timelock());

    //     vm.expectRevert("wrong vault");
    //     otherVault.acceptCap(IERC4626(address(rescueStrategy)));
    // }

    function testRescueTelos_uninstall() public {
        _installRescueStrategy();

        vm.startPrank(user);
        vm.expectRevert("vault operations are paused");
        vault.deposit(10, user);

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

        // plasma
        if (EARN_VAULT == 0xa9C251F8304b1B3Fc2b9e8fcae78D94Eff82Ac66) {
            vault.submitCap(supplyQueue[0], type(uint136).max);
            skip(vault.timelock());
            vault.acceptCap(supplyQueue[0]);
        }

        vault.setSupplyQueue(supplyQueue);

        // the vault is functional

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
    }

    function testRescueTelos_onlyRescueAccountCallFunc() external {
        _installRescueStrategy();

        vm.prank(user);
        vm.expectRevert("unauthorized");
        rescueStrategy.call(address(0), "");

        vm.prank(rescueAccount);
        rescueStrategy.call(address(0), "");
    }

    function testRescueTelos_flashloanCallbacks() external {
        _installRescueStrategy();

        vm.expectRevert("vault operations are paused");
        rescueStrategy.onBatchLoan(1, 1);
        vm.expectRevert("vault operations are paused");
        rescueStrategy.onFlashLoan("");
        vm.expectRevert("vault operations are paused");
        rescueStrategy.onMorphoFlashLoan(1, "");
        vm.expectRevert("vault operations are paused");
        rescueStrategy.executeOperation(address(1), 1, 1, address(1), "");
    }


    function _installRescueStrategy() internal {
        // deploy strategy, set a cap for it and put in in the supply and withdraw queues
        rescueStrategy = RescueStrategy(RESCUE_STRATEGY);

        vm.startPrank(vault.curator());

        IERC4626 id = IERC4626(address(rescueStrategy));

        // vault.submitCap(id, type(uint184).max);

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
}
