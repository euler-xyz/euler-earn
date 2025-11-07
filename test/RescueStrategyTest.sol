// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IERC4626} from "openzeppelin-contracts/interfaces/IERC4626.sol";
import {IEulerEarn} from "../src/interfaces/IEulerEarn.sol";
import {IEulerEarnFactory} from "../src/interfaces/IEulerEarnFactory.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IAllowanceTransfer} from "../src/interfaces/IAllowanceTransfer.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {RescueStrategy} from "../src/RescueStrategy.sol";
import "forge-std/Test.sol";


contract RescuePOC is Test {
    // the earn vault to rescue:
    address constant EARN_VAULT = 0x3B4802FDb0E5d74aA37d58FD77d63e93d4f9A4AF; // https://app.euler.finance/earn/0x3B4802FDb0E5d74aA37d58FD77d63e93d4f9A4AF?network=ethereum 

    address constant OTHER_EARN_VAULT = 0x3cd3718f8f047aA32F775E2cb4245A164E1C99fB; // https://app.euler.finance/earn/0x3cd3718f8f047aA32F775E2cb4245A164E1C99fB?network=ethereum
    address constant FLASH_LOAN_SOURCE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb; // morpho
    address constant RESCUE_EOA = address(10000);
    address constant FUNDS_RECEIVER = address(20000);

	IEulerEarn vault;

	string FORK_RPC_URL = vm.envOr("FORK_RPC_URL_MAINNET", string(""));
	uint256 BLOCK_NUMBER = vm.envOr("FORK_BLOCK_NUMBER", uint256(0));

	uint256 fork;

	address user = makeAddr("user");
    RescueStrategy rescueStrategy;

 	function setUp() public {
		require(bytes(FORK_RPC_URL).length != 0, "No FORK_RPC_URL env found");
		require(RESCUE_EOA != address(0), "No RESCUE_EOA env found");
		require(EARN_VAULT != address(0), "No EARN_VAULT env found");
		require(FLASH_LOAN_SOURCE != address(0), "No FLASH_LOAN_SOURCE env found");
		require(FUNDS_RECEIVER != address(0), "No FUNDS_RECEIVER env found");

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
	}

    function testRescue_rescueOneGo() public {
        _installRescueStrategy();

        // create shares equal total supply + extra
        uint256 amount = vault.previewMint(vault.totalSupply()) * 10001 / 10000;

        vm.startPrank(RESCUE_EOA, RESCUE_EOA);
        rescueStrategy.rescueMorpho(amount, FLASH_LOAN_SOURCE);

        assertGt(IERC20(vault.asset()).balanceOf(FUNDS_RECEIVER), 0);

        console.log("Rescued", IERC20(vault.asset()).balanceOf(FUNDS_RECEIVER), IEulerEarn(vault.asset()).symbol());
        console.log("Received shares", IERC4626(vault).balanceOf(FUNDS_RECEIVER));
    }

    function testRescue_rescueMultiple() public {
        _installRescueStrategy();

        uint256 amount = 1000000000000;

        vm.startPrank(RESCUE_EOA, RESCUE_EOA);
        rescueStrategy.rescueMorpho(amount, FLASH_LOAN_SOURCE);
        rescueStrategy.rescueMorpho(amount, FLASH_LOAN_SOURCE);
        rescueStrategy.rescueMorpho(amount, FLASH_LOAN_SOURCE);

        assertGt(IERC20(vault.asset()).balanceOf(FUNDS_RECEIVER), 0);

        console.log("Rescued", IERC20(vault.asset()).balanceOf(FUNDS_RECEIVER), IEulerEarn(vault.asset()).symbol());
        console.log("Received shares", IERC4626(vault).balanceOf(FUNDS_RECEIVER));
    }

    function testRescue_rescueEOACanWithdrawAnyTime() public {
        _installRescueStrategy();

        vm.prank(user);
		vm.expectRevert("vault operations are paused");
        vault.withdraw(1e6, user, user);

        deal(address(vault), RESCUE_EOA, 1e6);

        vm.prank(RESCUE_EOA, RESCUE_EOA);
        vault.withdraw(1e6, RESCUE_EOA, RESCUE_EOA);

        assertEq(IERC20(vault.asset()).balanceOf(RESCUE_EOA), 1e6);
    }

    function testRescue_cantBeReused() public {
        rescueStrategy = new RescueStrategy(RESCUE_EOA, address(vault), FUNDS_RECEIVER);

		// install perspective in earn factory which will allow custom strategies
		_installPerspective();

        IEulerEarn otherVault = IEulerEarn(OTHER_EARN_VAULT); // hyperithm euler usdc mainnet

		vm.startPrank(otherVault.curator());

        vm.expectRevert("wrong vault");
		otherVault.submitCap(IERC4626(address(rescueStrategy)), type(uint184).max);
    }

    function testRescue_uninstall() public {
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

	function _installRescueStrategy() internal {
		// install perspective in earn factory which will allow custom strategies (use mock here)
		_installPerspective();

		// deploy strategy, set a cap for it and put in in the supply and withdraw queues
		rescueStrategy = new RescueStrategy(RESCUE_EOA, address(vault), FUNDS_RECEIVER);

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
    function isVerified(address) external pure returns(bool) {
        return true;
    }
}

