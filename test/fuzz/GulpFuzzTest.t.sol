// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../common/EulerEarnBase.t.sol";

contract GulpFuzzTest is EulerEarnBase {
    function setUp() public virtual override {
        super.setUp();

        uint256 initialStrategyAllocationPoints = 500e18;
        _addStrategy(manager, address(eTST), initialStrategyAllocationPoints);
    }

    function testFuzzInterestAccruedUnderUint168(uint256 _interestAmount, uint256 _depositAmount, uint256 _timePassed)
        public
    {
        _depositAmount = bound(_depositAmount, 0, type(uint112).max);
        // this makes sure that the mint won't cause overflow in token accounting
        _interestAmount = bound(_interestAmount, 0, type(uint112).max - _depositAmount);
        _timePassed = bound(_timePassed, block.timestamp, type(uint40).max);

        assetTST.mint(user1, _depositAmount);
        vm.startPrank(user1);
        assetTST.approve(address(eulerEulerEarnVault), _depositAmount);
        eulerEulerEarnVault.deposit(_depositAmount, user1);
        vm.stopPrank();

        assetTST.mint(address(eulerEulerEarnVault), _interestAmount);
        eulerEulerEarnVault.gulp();
        eulerEulerEarnVault.updateInterestAccrued();

        vm.warp(_timePassed);
        uint256 interestAccrued = eulerEulerEarnVault.interestAccrued();

        assertLe(interestAccrued, type(uint168).max);
    }

    // this tests shows that when you have a very small deposit and a very large interestAmount minted to the contract
    function testFuzzGulpUnderUint168(uint256 _interestAmount, uint256 _depositAmount) public {
        _depositAmount = bound(_depositAmount, 1e7, type(uint112).max);
        _interestAmount = bound(_interestAmount, 0, type(uint256).max - _depositAmount); // this makes sure that the mint won't cause overflow

        assetTST.mint(address(eulerEulerEarnVault), _interestAmount);

        assetTST.mint(user1, _depositAmount);
        vm.startPrank(user1);
        assetTST.approve(address(eulerEulerEarnVault), _depositAmount);
        eulerEulerEarnVault.deposit(_depositAmount, user1);
        vm.stopPrank();

        eulerEulerEarnVault.gulp();

        (,, uint168 interestLeft) = eulerEulerEarnVault.getEulerEarnSavingRate();

        if (_interestAmount <= type(uint168).max) {
            assertEq(interestLeft, _interestAmount);
        } else {
            assertEq(interestLeft, type(uint168).max);
        }
    }

    // ESR implement has a min shares for gulp
    // This test to make sure everything works as expected when removing that min share for gulping requirement.
    function testFuzzGulpBelowMinSharesForGulp() public {
        uint256 depositAmount = 1337;
        assetTST.mint(user1, depositAmount);
        vm.startPrank(user1);
        assetTST.approve(address(eulerEulerEarnVault), depositAmount);
        eulerEulerEarnVault.deposit(depositAmount, user1);
        vm.stopPrank();

        uint256 interestAmount = 10e18;
        // Mint interest directly into the contract
        assetTST.mint(address(eulerEulerEarnVault), interestAmount);
        eulerEulerEarnVault.gulp();
        skip(eulerEulerEarnVault.interestSmearingPeriod());

        (,, uint168 interestLeft) = eulerEulerEarnVault.getEulerEarnSavingRate();
        assertEq(eulerEulerEarnVault.totalAssets(), depositAmount + interestAmount);
        assertEq(interestLeft, interestAmount);
    }
}
