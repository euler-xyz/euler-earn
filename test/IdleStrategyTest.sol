// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import {stdError} from "../lib/forge-std/src/StdError.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC4626} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import {IdleStrategyDonateable} from "../src/IdleStrategy.sol";
import "./helpers/IntegrationTest.sol";

contract IdleStrategyTest is IntegrationTest {
    IdleStrategyDonateable idleStrategy;

    function setUp() public override {
        super.setUp();

        idleStrategy = new IdleStrategyDonateable(address(vault));

        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);
    }


    // ============ Integration Tests ============

    function testDepositAndWithdraw() public {
        uint256 amount = 1e18;

        // amount = bound(amount, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        // Setup: enable idle strategy in vault
        perspective.perspectiveVerify(address(idleStrategy));
        _setCap(IERC4626(address(idleStrategy)), type(uint136).max);
        IERC4626[] memory supplyQueue = new IERC4626[](1);
        supplyQueue[0] = IERC4626(address(idleStrategy));

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);
        
        // User deposits to vault
        loanToken.setBalance(SUPPLIER, amount);
        vm.prank(SUPPLIER);
        vault.deposit(amount, ONBEHALF);
        
        // Check that assets are in idle strategy
        assertEq(loanToken.balanceOf(address(idleStrategy)), amount, "idle strategy should have assets");
        
        // User withdraws from vault
        uint256 shares = vault.balanceOf(ONBEHALF);
        vm.prank(ONBEHALF);
        vault.redeem(shares, RECEIVER, ONBEHALF);
        
        // // Check that assets were withdrawn from idle strategy
        // assertEq(loanToken.balanceOf(address(idleStrategy)), 0, "idle strategy should be empty");
    }

    function testDonate() public {
        uint256 depositAmount = 1e18;
        uint256 donationAmount = 0.5e18;



        // Setup: enable idle strategy in vault
        perspective.perspectiveVerify(address(idleStrategy));

        _setCap(IERC4626(address(idleStrategy)), type(uint136).max);
        IERC4626[] memory supplyQueue = new IERC4626[](1);
        supplyQueue[0] = IERC4626(address(idleStrategy));

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);
        
        // User deposits to vault
        loanToken.setBalance(SUPPLIER, depositAmount);
        vm.prank(SUPPLIER);
        vault.deposit(depositAmount, ONBEHALF);

        // donation to the idle strategy
        loanToken.setBalance(SUPPLIER, donationAmount);
        vm.prank(SUPPLIER);
        loanToken.transfer(address(idleStrategy), donationAmount);

        // all the donated assets are accounted for the single depositor
        assertApproxEqAbs(vault.maxWithdraw(ONBEHALF), depositAmount + donationAmount, 1e6);
        
        // User withdraws from vault
        uint256 shares = vault.balanceOf(ONBEHALF);
        vm.prank(ONBEHALF);
        vault.redeem(shares, RECEIVER, ONBEHALF);
        
        // Check that assets were withdrawn from idle strategy
        assertApproxEqAbs(loanToken.balanceOf(RECEIVER), depositAmount + donationAmount, 1e6);
    }
}
