// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../common/YieldAggregatorBase.t.sol";

contract WithdrawGasMetering is YieldAggregatorBase {
    uint256 user1InitialBalance = 100000e18;

    function setUp() public virtual override {
        super.setUp();

        uint256 initialStrategyAllocationPoints = 500e18;
        _addStrategy(manager, address(eTST), initialStrategyAllocationPoints);

        assetTST.mint(user1, user1InitialBalance);
    }

    /// this before removing cooldown period
    // before running this, undo the changes in src/module/YieldAggregatorVault.sol
    function testWithdrawSingleStrategyNoHarvest() public {
        uint256 amountToDeposit = 10000e18;

        // deposit into aggregator
        {
            uint256 balanceBefore = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

            vm.startPrank(user1);
            assetTST.approve(address(eulerYieldAggregatorVault), amountToDeposit);
            eulerYieldAggregatorVault.deposit(amountToDeposit, user1);
            vm.stopPrank();

            assertEq(eulerYieldAggregatorVault.balanceOf(user1), balanceBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalSupply(), totalSupplyBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore + amountToDeposit);
            assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - amountToDeposit);
        }

        // rebalance into strategy
        vm.warp(block.timestamp + 86400);
        {
            IYieldAggregator.Strategy memory strategyBefore = eulerYieldAggregatorVault.getStrategy(address(eTST));

            assertEq(eTST.convertToAssets(eTST.balanceOf(address(eulerYieldAggregatorVault))), strategyBefore.allocated);

            uint256 expectedStrategyCash = eulerYieldAggregatorVault.totalAssetsAllocatable()
                * strategyBefore.allocationPoints / eulerYieldAggregatorVault.totalAllocationPoints();

            vm.prank(user1);
            address[] memory strategiesToRebalance = new address[](1);
            strategiesToRebalance[0] = address(eTST);
            eulerYieldAggregatorVault.rebalance(strategiesToRebalance);

            assertEq(eulerYieldAggregatorVault.totalAllocated(), expectedStrategyCash);
            assertEq(eTST.convertToAssets(eTST.balanceOf(address(eulerYieldAggregatorVault))), expectedStrategyCash);
            assertEq(
                (eulerYieldAggregatorVault.getStrategy(address(eTST))).allocated,
                strategyBefore.allocated + expectedStrategyCash
            );
        }

        eulerYieldAggregatorVault.harvest();

        // full withdraw, will have to withdraw from strategy as cash reserve is not enough
        vm.warp(block.timestamp + 86400);
        {
            uint256 amountToRedeem = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 aggregatorTotalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 user1AssetTSTBalanceBefore = assetTST.balanceOf(user1);

            vm.prank(user1);
            eulerYieldAggregatorVault.redeem(amountToRedeem, user1, user1);

            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore - amountToRedeem);
            assertEq(eulerYieldAggregatorVault.totalSupply(), aggregatorTotalSupplyBefore - amountToRedeem);
            assertEq(
                assetTST.balanceOf(user1),
                user1AssetTSTBalanceBefore + eulerYieldAggregatorVault.convertToAssets(amountToRedeem)
            );
        }
    }

    /// this before removing cooldown period
    // before running this, undo the changes in src/module/YieldAggregatorVault.sol
    function testWithdrawFiveStrategiesNoHarvest() public {
        IEVault eTSTsecondary;
        IEVault eTSTthird;
        IEVault eTSTforth;
        IEVault eTSTfifth;

        {
            eTSTsecondary = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTsecondary.setHookConfig(address(0), 0);
            eTSTsecondary.setInterestRateModel(address(new IRMTestDefault()));
            eTSTsecondary.setMaxLiquidationDiscount(0.2e4);
            eTSTsecondary.setFeeReceiver(feeReceiver);

            uint256 initialStrategyAllocationPoints = 1000e18;
            _addStrategy(manager, address(eTSTsecondary), initialStrategyAllocationPoints);

            eTSTthird = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTthird.setHookConfig(address(0), 0);
            eTSTthird.setInterestRateModel(address(new IRMTestDefault()));
            eTSTthird.setMaxLiquidationDiscount(0.2e4);
            eTSTthird.setFeeReceiver(feeReceiver);

            _addStrategy(manager, address(eTSTthird), initialStrategyAllocationPoints);

            eTSTforth = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTforth.setHookConfig(address(0), 0);
            eTSTforth.setInterestRateModel(address(new IRMTestDefault()));
            eTSTforth.setMaxLiquidationDiscount(0.2e4);
            eTSTforth.setFeeReceiver(feeReceiver);

            _addStrategy(manager, address(eTSTforth), initialStrategyAllocationPoints);

            eTSTfifth = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTfifth.setHookConfig(address(0), 0);
            eTSTfifth.setInterestRateModel(address(new IRMTestDefault()));
            eTSTfifth.setMaxLiquidationDiscount(0.2e4);
            eTSTfifth.setFeeReceiver(feeReceiver);

            _addStrategy(manager, address(eTSTfifth), initialStrategyAllocationPoints);
        }

        uint256 amountToDeposit = 10000e18;

        // deposit into aggregator
        {
            uint256 balanceBefore = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

            vm.startPrank(user1);
            assetTST.approve(address(eulerYieldAggregatorVault), amountToDeposit);
            eulerYieldAggregatorVault.deposit(amountToDeposit, user1);
            vm.stopPrank();

            assertEq(eulerYieldAggregatorVault.balanceOf(user1), balanceBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalSupply(), totalSupplyBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore + amountToDeposit);
            assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - amountToDeposit);
        }

        // rebalance into strategy
        vm.warp(block.timestamp + 86400);
        {
            vm.prank(user1);
            address[] memory strategiesToRebalance = new address[](5);
            strategiesToRebalance[0] = address(eTST);
            strategiesToRebalance[1] = address(eTSTsecondary);
            strategiesToRebalance[2] = address(eTSTthird);
            strategiesToRebalance[3] = address(eTSTforth);
            strategiesToRebalance[4] = address(eTSTfifth);
            eulerYieldAggregatorVault.rebalance(strategiesToRebalance);
        }

        eulerYieldAggregatorVault.harvest();

        // full withdraw, will have to withdraw from strategy as cash reserve is not enough
        vm.warp(block.timestamp + 86400);
        {
            uint256 amountToRedeem = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 aggregatorTotalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 user1AssetTSTBalanceBefore = assetTST.balanceOf(user1);

            vm.prank(user1);
            eulerYieldAggregatorVault.redeem(amountToRedeem, user1, user1);

            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore - amountToRedeem);
            assertEq(eulerYieldAggregatorVault.totalSupply(), aggregatorTotalSupplyBefore - amountToRedeem);
            assertEq(
                assetTST.balanceOf(user1),
                user1AssetTSTBalanceBefore + eulerYieldAggregatorVault.convertToAssets(amountToRedeem)
            );
        }
    }

    function testWithdrawSingleStrategyNoYieldNoLoss() public {
        uint256 amountToDeposit = 10000e18;

        // deposit into aggregator
        {
            uint256 balanceBefore = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

            vm.startPrank(user1);
            assetTST.approve(address(eulerYieldAggregatorVault), amountToDeposit);
            eulerYieldAggregatorVault.deposit(amountToDeposit, user1);
            vm.stopPrank();

            assertEq(eulerYieldAggregatorVault.balanceOf(user1), balanceBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalSupply(), totalSupplyBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore + amountToDeposit);
            assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - amountToDeposit);
        }

        // rebalance into strategy
        vm.warp(block.timestamp + 86400);
        {
            IYieldAggregator.Strategy memory strategyBefore = eulerYieldAggregatorVault.getStrategy(address(eTST));

            assertEq(eTST.convertToAssets(eTST.balanceOf(address(eulerYieldAggregatorVault))), strategyBefore.allocated);

            uint256 expectedStrategyCash = eulerYieldAggregatorVault.totalAssetsAllocatable()
                * strategyBefore.allocationPoints / eulerYieldAggregatorVault.totalAllocationPoints();

            vm.prank(user1);
            address[] memory strategiesToRebalance = new address[](1);
            strategiesToRebalance[0] = address(eTST);
            eulerYieldAggregatorVault.rebalance(strategiesToRebalance);

            assertEq(eulerYieldAggregatorVault.totalAllocated(), expectedStrategyCash);
            assertEq(eTST.convertToAssets(eTST.balanceOf(address(eulerYieldAggregatorVault))), expectedStrategyCash);
            assertEq(
                (eulerYieldAggregatorVault.getStrategy(address(eTST))).allocated,
                strategyBefore.allocated + expectedStrategyCash
            );
        }

        // full withdraw, will have to withdraw from strategy as cash reserve is not enough
        vm.warp(block.timestamp + 86400);
        {
            uint256 amountToRedeem = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 aggregatorTotalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 user1AssetTSTBalanceBefore = assetTST.balanceOf(user1);

            vm.prank(user1);
            eulerYieldAggregatorVault.redeem(amountToRedeem, user1, user1);

            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore - amountToRedeem);
            assertEq(eulerYieldAggregatorVault.totalSupply(), aggregatorTotalSupplyBefore - amountToRedeem);
            assertEq(
                assetTST.balanceOf(user1),
                user1AssetTSTBalanceBefore + eulerYieldAggregatorVault.convertToAssets(amountToRedeem)
            );
        }
    }

    function testWithdrawTwoStrategiesNoYieldNoLoss() public {
        IEVault eTSTsecondary;
        {
            eTSTsecondary = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTsecondary.setHookConfig(address(0), 0);
            eTSTsecondary.setInterestRateModel(address(new IRMTestDefault()));
            eTSTsecondary.setMaxLiquidationDiscount(0.2e4);
            eTSTsecondary.setFeeReceiver(feeReceiver);

            uint256 initialStrategyAllocationPoints = 1000e18;
            _addStrategy(manager, address(eTSTsecondary), initialStrategyAllocationPoints);
        }

        uint256 amountToDeposit = 10000e18;
        // deposit into aggregator
        {
            uint256 balanceBefore = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

            vm.startPrank(user1);
            assetTST.approve(address(eulerYieldAggregatorVault), amountToDeposit);
            eulerYieldAggregatorVault.deposit(amountToDeposit, user1);
            vm.stopPrank();

            assertEq(eulerYieldAggregatorVault.balanceOf(user1), balanceBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalSupply(), totalSupplyBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore + amountToDeposit);
            assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - amountToDeposit);
        }

        // rebalance into strategy
        vm.warp(block.timestamp + 86400);
        {
            vm.prank(user1);
            address[] memory strategiesToRebalance = new address[](2);
            strategiesToRebalance[0] = address(eTST);
            strategiesToRebalance[1] = address(eTSTsecondary);
            eulerYieldAggregatorVault.rebalance(strategiesToRebalance);
        }

        // full withdraw, will have to withdraw from strategy as cash reserve is not enough
        vm.warp(block.timestamp + 86400);
        {
            uint256 amountToRedeem = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 aggregatorTotalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 user1AssetTSTBalanceBefore = assetTST.balanceOf(user1);

            vm.prank(user1);
            eulerYieldAggregatorVault.redeem(amountToRedeem, user1, user1);

            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore - amountToRedeem);
            assertEq(eulerYieldAggregatorVault.totalSupply(), aggregatorTotalSupplyBefore - amountToRedeem);
            assertEq(
                assetTST.balanceOf(user1),
                user1AssetTSTBalanceBefore + eulerYieldAggregatorVault.convertToAssets(amountToRedeem)
            );
        }
    }

    function testWithdrawThreeStrategiesNoYieldNoLoss() public {
        IEVault eTSTsecondary;
        IEVault eTSTthird;
        {
            eTSTsecondary = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTsecondary.setHookConfig(address(0), 0);
            eTSTsecondary.setInterestRateModel(address(new IRMTestDefault()));
            eTSTsecondary.setMaxLiquidationDiscount(0.2e4);
            eTSTsecondary.setFeeReceiver(feeReceiver);

            uint256 initialStrategyAllocationPoints = 1000e18;
            _addStrategy(manager, address(eTSTsecondary), initialStrategyAllocationPoints);

            eTSTthird = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTthird.setHookConfig(address(0), 0);
            eTSTthird.setInterestRateModel(address(new IRMTestDefault()));
            eTSTthird.setMaxLiquidationDiscount(0.2e4);
            eTSTthird.setFeeReceiver(feeReceiver);

            _addStrategy(manager, address(eTSTthird), initialStrategyAllocationPoints);
        }

        uint256 amountToDeposit = 10000e18;
        // deposit into aggregator
        {
            uint256 balanceBefore = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

            vm.startPrank(user1);
            assetTST.approve(address(eulerYieldAggregatorVault), amountToDeposit);
            eulerYieldAggregatorVault.deposit(amountToDeposit, user1);
            vm.stopPrank();

            assertEq(eulerYieldAggregatorVault.balanceOf(user1), balanceBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalSupply(), totalSupplyBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore + amountToDeposit);
            assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - amountToDeposit);
        }

        // rebalance into strategy
        vm.warp(block.timestamp + 86400);
        {
            vm.prank(user1);
            address[] memory strategiesToRebalance = new address[](3);
            strategiesToRebalance[0] = address(eTST);
            strategiesToRebalance[1] = address(eTSTsecondary);
            strategiesToRebalance[2] = address(eTSTthird);
            eulerYieldAggregatorVault.rebalance(strategiesToRebalance);
        }

        // full withdraw, will have to withdraw from strategy as cash reserve is not enough
        vm.warp(block.timestamp + 86400);
        {
            uint256 amountToRedeem = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 aggregatorTotalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 user1AssetTSTBalanceBefore = assetTST.balanceOf(user1);

            vm.prank(user1);
            eulerYieldAggregatorVault.redeem(amountToRedeem, user1, user1);

            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore - amountToRedeem);
            assertEq(eulerYieldAggregatorVault.totalSupply(), aggregatorTotalSupplyBefore - amountToRedeem);
            assertEq(
                assetTST.balanceOf(user1),
                user1AssetTSTBalanceBefore + eulerYieldAggregatorVault.convertToAssets(amountToRedeem)
            );
        }
    }

    function testWithdrawFiveStrategiesNoYieldNoLoss() public {
        IEVault eTSTsecondary;
        IEVault eTSTthird;
        IEVault eTSTforth;
        IEVault eTSTfifth;

        {
            eTSTsecondary = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTsecondary.setHookConfig(address(0), 0);
            eTSTsecondary.setInterestRateModel(address(new IRMTestDefault()));
            eTSTsecondary.setMaxLiquidationDiscount(0.2e4);
            eTSTsecondary.setFeeReceiver(feeReceiver);

            uint256 initialStrategyAllocationPoints = 1000e18;
            _addStrategy(manager, address(eTSTsecondary), initialStrategyAllocationPoints);

            eTSTthird = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTthird.setHookConfig(address(0), 0);
            eTSTthird.setInterestRateModel(address(new IRMTestDefault()));
            eTSTthird.setMaxLiquidationDiscount(0.2e4);
            eTSTthird.setFeeReceiver(feeReceiver);

            _addStrategy(manager, address(eTSTthird), initialStrategyAllocationPoints);

            eTSTforth = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTforth.setHookConfig(address(0), 0);
            eTSTforth.setInterestRateModel(address(new IRMTestDefault()));
            eTSTforth.setMaxLiquidationDiscount(0.2e4);
            eTSTforth.setFeeReceiver(feeReceiver);

            _addStrategy(manager, address(eTSTforth), initialStrategyAllocationPoints);

            eTSTfifth = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTfifth.setHookConfig(address(0), 0);
            eTSTfifth.setInterestRateModel(address(new IRMTestDefault()));
            eTSTfifth.setMaxLiquidationDiscount(0.2e4);
            eTSTfifth.setFeeReceiver(feeReceiver);

            _addStrategy(manager, address(eTSTfifth), initialStrategyAllocationPoints);
        }

        uint256 amountToDeposit = 10000e18;
        // deposit into aggregator
        {
            uint256 balanceBefore = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

            vm.startPrank(user1);
            assetTST.approve(address(eulerYieldAggregatorVault), amountToDeposit);
            eulerYieldAggregatorVault.deposit(amountToDeposit, user1);
            vm.stopPrank();

            assertEq(eulerYieldAggregatorVault.balanceOf(user1), balanceBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalSupply(), totalSupplyBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore + amountToDeposit);
            assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - amountToDeposit);
        }

        // rebalance into strategy
        vm.warp(block.timestamp + 86400);
        {
            vm.prank(user1);
            address[] memory strategiesToRebalance = new address[](5);
            strategiesToRebalance[0] = address(eTST);
            strategiesToRebalance[1] = address(eTSTsecondary);
            strategiesToRebalance[2] = address(eTSTthird);
            strategiesToRebalance[3] = address(eTSTforth);
            strategiesToRebalance[4] = address(eTSTfifth);
            eulerYieldAggregatorVault.rebalance(strategiesToRebalance);
        }

        // full withdraw, will have to withdraw from strategy as cash reserve is not enough
        vm.warp(block.timestamp + 86400);
        {
            uint256 amountToRedeem = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 aggregatorTotalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 user1AssetTSTBalanceBefore = assetTST.balanceOf(user1);

            vm.prank(user1);
            eulerYieldAggregatorVault.redeem(amountToRedeem, user1, user1);

            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore - amountToRedeem);
            assertEq(eulerYieldAggregatorVault.totalSupply(), aggregatorTotalSupplyBefore - amountToRedeem);
            assertEq(
                assetTST.balanceOf(user1),
                user1AssetTSTBalanceBefore + eulerYieldAggregatorVault.convertToAssets(amountToRedeem)
            );
        }
    }

    function testWithdrawSingleStrategyWithYield() public {
        uint256 amountToDeposit = 10000e18;

        // deposit into aggregator
        {
            uint256 balanceBefore = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

            vm.startPrank(user1);
            assetTST.approve(address(eulerYieldAggregatorVault), amountToDeposit);
            eulerYieldAggregatorVault.deposit(amountToDeposit, user1);
            vm.stopPrank();

            assertEq(eulerYieldAggregatorVault.balanceOf(user1), balanceBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalSupply(), totalSupplyBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore + amountToDeposit);
            assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - amountToDeposit);
        }

        // rebalance into strategy
        vm.warp(block.timestamp + 86400);
        {
            IYieldAggregator.Strategy memory strategyBefore = eulerYieldAggregatorVault.getStrategy(address(eTST));

            assertEq(eTST.convertToAssets(eTST.balanceOf(address(eulerYieldAggregatorVault))), strategyBefore.allocated);

            uint256 expectedStrategyCash = eulerYieldAggregatorVault.totalAssetsAllocatable()
                * strategyBefore.allocationPoints / eulerYieldAggregatorVault.totalAllocationPoints();

            vm.prank(user1);
            address[] memory strategiesToRebalance = new address[](1);
            strategiesToRebalance[0] = address(eTST);
            eulerYieldAggregatorVault.rebalance(strategiesToRebalance);

            assertEq(eulerYieldAggregatorVault.totalAllocated(), expectedStrategyCash);
            assertEq(eTST.convertToAssets(eTST.balanceOf(address(eulerYieldAggregatorVault))), expectedStrategyCash);
            assertEq((eulerYieldAggregatorVault.getStrategy(address(eTST))).allocated, expectedStrategyCash);
        }

        vm.warp(block.timestamp + 86400);
        // mock an increase of strategy balance by 10%
        uint256 aggrCurrentStrategyShareBalance = eTST.balanceOf(address(eulerYieldAggregatorVault));
        uint256 aggrCurrentStrategyUnderlyingBalance = eTST.convertToAssets(aggrCurrentStrategyShareBalance);
        uint256 aggrNewStrategyUnderlyingBalance = aggrCurrentStrategyUnderlyingBalance * 11e17 / 1e18;
        uint256 yield = aggrNewStrategyUnderlyingBalance - aggrCurrentStrategyUnderlyingBalance;
        assetTST.mint(address(eTST), yield);
        eTST.skim(type(uint256).max, address(eulerYieldAggregatorVault));

        // full withdraw, will have to withdraw from strategy as cash reserve is not enough
        {
            uint256 amountToRedeem = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 aggregatorTotalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 user1AssetTSTBalanceBefore = assetTST.balanceOf(user1);

            vm.prank(user1);
            eulerYieldAggregatorVault.redeem(amountToRedeem, user1, user1);

            assertEq(eTST.balanceOf(address(eulerYieldAggregatorVault)), yield);
            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore - amountToRedeem);
            assertEq(eulerYieldAggregatorVault.totalSupply(), aggregatorTotalSupplyBefore - amountToRedeem);
            assertEq(
                assetTST.balanceOf(user1),
                user1AssetTSTBalanceBefore + eulerYieldAggregatorVault.convertToAssets(amountToRedeem)
            );
        }
    }

    function testWithdrawTwoStrategiesWithYield() public {
        IEVault eTSTsecondary;
        {
            eTSTsecondary = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTsecondary.setHookConfig(address(0), 0);
            eTSTsecondary.setInterestRateModel(address(new IRMTestDefault()));
            eTSTsecondary.setMaxLiquidationDiscount(0.2e4);
            eTSTsecondary.setFeeReceiver(feeReceiver);

            uint256 initialStrategyAllocationPoints = 1000e18;
            _addStrategy(manager, address(eTSTsecondary), initialStrategyAllocationPoints);
        }

        uint256 amountToDeposit = 10000e18;

        // deposit into aggregator
        {
            uint256 balanceBefore = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

            vm.startPrank(user1);
            assetTST.approve(address(eulerYieldAggregatorVault), amountToDeposit);
            eulerYieldAggregatorVault.deposit(amountToDeposit, user1);
            vm.stopPrank();

            assertEq(eulerYieldAggregatorVault.balanceOf(user1), balanceBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalSupply(), totalSupplyBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore + amountToDeposit);
            assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - amountToDeposit);
        }

        // rebalance into strategy
        vm.warp(block.timestamp + 86400);
        {
            vm.prank(user1);
            address[] memory strategiesToRebalance = new address[](2);
            strategiesToRebalance[0] = address(eTST);
            strategiesToRebalance[1] = address(eTSTsecondary);
            eulerYieldAggregatorVault.rebalance(strategiesToRebalance);
        }

        vm.warp(block.timestamp + 86400);
        // mock an increase of strategy balance by 10%
        uint256 aggrCurrentStrategyShareBalance = eTST.balanceOf(address(eulerYieldAggregatorVault));
        uint256 aggrCurrentStrategyUnderlyingBalance = eTST.convertToAssets(aggrCurrentStrategyShareBalance);
        uint256 aggrNewStrategyUnderlyingBalance = aggrCurrentStrategyUnderlyingBalance * 11e17 / 1e18;
        uint256 yield = aggrNewStrategyUnderlyingBalance - aggrCurrentStrategyUnderlyingBalance;
        assetTST.mint(address(eTST), yield);
        eTST.skim(type(uint256).max, address(eulerYieldAggregatorVault));

        aggrCurrentStrategyShareBalance = eTSTsecondary.balanceOf(address(eulerYieldAggregatorVault));
        aggrCurrentStrategyUnderlyingBalance = eTSTsecondary.convertToAssets(aggrCurrentStrategyShareBalance);
        aggrNewStrategyUnderlyingBalance = aggrCurrentStrategyUnderlyingBalance * 11e17 / 1e18;
        yield = aggrNewStrategyUnderlyingBalance - aggrCurrentStrategyUnderlyingBalance;
        assetTST.mint(address(eTSTsecondary), yield);
        eTSTsecondary.skim(type(uint256).max, address(eulerYieldAggregatorVault));

        // full withdraw, will have to withdraw from strategy as cash reserve is not enough
        {
            uint256 amountToRedeem = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 aggregatorTotalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 user1AssetTSTBalanceBefore = assetTST.balanceOf(user1);

            vm.prank(user1);
            eulerYieldAggregatorVault.redeem(amountToRedeem, user1, user1);
        }
    }

    function testWithdrawFiveStrategiesWithYield() public {
        IEVault eTSTsecondary;
        IEVault eTSTthird;
        IEVault eTSTforth;
        IEVault eTSTfifth;

        {
            eTSTsecondary = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTsecondary.setHookConfig(address(0), 0);
            eTSTsecondary.setInterestRateModel(address(new IRMTestDefault()));
            eTSTsecondary.setMaxLiquidationDiscount(0.2e4);
            eTSTsecondary.setFeeReceiver(feeReceiver);

            eTSTthird = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTthird.setHookConfig(address(0), 0);
            eTSTthird.setInterestRateModel(address(new IRMTestDefault()));
            eTSTthird.setMaxLiquidationDiscount(0.2e4);
            eTSTthird.setFeeReceiver(feeReceiver);

            eTSTforth = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTforth.setHookConfig(address(0), 0);
            eTSTforth.setInterestRateModel(address(new IRMTestDefault()));
            eTSTforth.setMaxLiquidationDiscount(0.2e4);
            eTSTforth.setFeeReceiver(feeReceiver);

            eTSTfifth = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTfifth.setHookConfig(address(0), 0);
            eTSTfifth.setInterestRateModel(address(new IRMTestDefault()));
            eTSTfifth.setMaxLiquidationDiscount(0.2e4);
            eTSTfifth.setFeeReceiver(feeReceiver);

            uint256 initialStrategyAllocationPoints = 1000e18;
            _addStrategy(manager, address(eTSTsecondary), initialStrategyAllocationPoints);
            _addStrategy(manager, address(eTSTthird), initialStrategyAllocationPoints);
            _addStrategy(manager, address(eTSTforth), initialStrategyAllocationPoints);
            _addStrategy(manager, address(eTSTfifth), initialStrategyAllocationPoints);
        }

        uint256 amountToDeposit = 10000e18;

        // deposit into aggregator
        {
            uint256 balanceBefore = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

            vm.startPrank(user1);
            assetTST.approve(address(eulerYieldAggregatorVault), amountToDeposit);
            eulerYieldAggregatorVault.deposit(amountToDeposit, user1);
            vm.stopPrank();

            assertEq(eulerYieldAggregatorVault.balanceOf(user1), balanceBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalSupply(), totalSupplyBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore + amountToDeposit);
            assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - amountToDeposit);
        }

        // rebalance into strategy
        vm.warp(block.timestamp + 86400);
        {
            vm.prank(user1);
            address[] memory strategiesToRebalance = new address[](5);
            strategiesToRebalance[0] = address(eTST);
            strategiesToRebalance[1] = address(eTSTsecondary);
            strategiesToRebalance[2] = address(eTSTthird);
            strategiesToRebalance[3] = address(eTSTforth);
            strategiesToRebalance[4] = address(eTSTfifth);

            eulerYieldAggregatorVault.rebalance(strategiesToRebalance);
        }

        vm.warp(block.timestamp + 86400);
        // mock an increase of strategy balance by 10%
        uint256 aggrCurrentStrategyShareBalance = eTST.balanceOf(address(eulerYieldAggregatorVault));
        uint256 aggrCurrentStrategyUnderlyingBalance = eTST.convertToAssets(aggrCurrentStrategyShareBalance);
        uint256 aggrNewStrategyUnderlyingBalance = aggrCurrentStrategyUnderlyingBalance * 11e17 / 1e18;
        uint256 yield = aggrNewStrategyUnderlyingBalance - aggrCurrentStrategyUnderlyingBalance;
        assetTST.mint(address(eTST), yield);
        eTST.skim(type(uint256).max, address(eulerYieldAggregatorVault));

        aggrCurrentStrategyShareBalance = eTSTsecondary.balanceOf(address(eulerYieldAggregatorVault));
        aggrCurrentStrategyUnderlyingBalance = eTSTsecondary.convertToAssets(aggrCurrentStrategyShareBalance);
        aggrNewStrategyUnderlyingBalance = aggrCurrentStrategyUnderlyingBalance * 11e17 / 1e18;
        yield = aggrNewStrategyUnderlyingBalance - aggrCurrentStrategyUnderlyingBalance;
        assetTST.mint(address(eTSTsecondary), yield);
        eTSTsecondary.skim(type(uint256).max, address(eulerYieldAggregatorVault));

        assetTST.mint(address(eTSTthird), yield);
        eTSTthird.skim(type(uint256).max, address(eulerYieldAggregatorVault));

        assetTST.mint(address(eTSTforth), yield);
        eTSTforth.skim(type(uint256).max, address(eulerYieldAggregatorVault));

        assetTST.mint(address(eTSTfifth), yield);
        eTSTfifth.skim(type(uint256).max, address(eulerYieldAggregatorVault));

        // full withdraw, will have to withdraw from strategy as cash reserve is not enough
        {
            uint256 amountToRedeem = eulerYieldAggregatorVault.balanceOf(user1);

            vm.prank(user1);
            eulerYieldAggregatorVault.redeem(amountToRedeem, user1, user1);
        }
    }

    function testWithdrawSingleStrategyWithLoss() public {
        uint256 amountToDeposit = 10000e18;

        // deposit into aggregator
        {
            uint256 balanceBefore = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

            vm.startPrank(user1);
            assetTST.approve(address(eulerYieldAggregatorVault), amountToDeposit);
            eulerYieldAggregatorVault.deposit(amountToDeposit, user1);
            vm.stopPrank();

            assertEq(eulerYieldAggregatorVault.balanceOf(user1), balanceBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalSupply(), totalSupplyBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore + amountToDeposit);
            assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - amountToDeposit);
        }

        // rebalance into strategy
        vm.warp(block.timestamp + 86400);
        {
            IYieldAggregator.Strategy memory strategyBefore = eulerYieldAggregatorVault.getStrategy(address(eTST));

            assertEq(eTST.convertToAssets(eTST.balanceOf(address(eulerYieldAggregatorVault))), strategyBefore.allocated);

            uint256 expectedStrategyCash = eulerYieldAggregatorVault.totalAssetsAllocatable()
                * strategyBefore.allocationPoints / eulerYieldAggregatorVault.totalAllocationPoints();

            vm.prank(user1);
            address[] memory strategiesToRebalance = new address[](1);
            strategiesToRebalance[0] = address(eTST);
            eulerYieldAggregatorVault.rebalance(strategiesToRebalance);

            assertEq(eulerYieldAggregatorVault.totalAllocated(), expectedStrategyCash);
            assertEq(eTST.convertToAssets(eTST.balanceOf(address(eulerYieldAggregatorVault))), expectedStrategyCash);
            assertEq((eulerYieldAggregatorVault.getStrategy(address(eTST))).allocated, expectedStrategyCash);
        }

        vm.warp(block.timestamp + 86400);
        // mock decrease by 0%
        uint256 aggrCurrentStrategyBalance = eTST.balanceOf(address(eulerYieldAggregatorVault));
        uint256 aggrCurrentStrategyBalanceAfterNegYield = aggrCurrentStrategyBalance * 9e17 / 1e18;
        vm.mockCall(
            address(eTST),
            abi.encodeWithSelector(EVault.previewRedeem.selector, aggrCurrentStrategyBalance),
            abi.encode(aggrCurrentStrategyBalanceAfterNegYield)
        );
        vm.mockCall(
            address(eTST),
            abi.encodeWithSelector(EVault.maxWithdraw.selector, address(eulerYieldAggregatorVault)),
            abi.encode(aggrCurrentStrategyBalanceAfterNegYield)
        );

        // full withdraw, will have to withdraw from strategy as cash reserve is not enough
        {
            uint256 amountToRedeem = eulerYieldAggregatorVault.balanceOf(user1);

            vm.prank(user1);
            eulerYieldAggregatorVault.redeem(amountToRedeem, user1, user1);
        }
    }

    function testWithdrawFiveStrategiesWithLoss() public {
        IEVault eTSTsecondary;
        IEVault eTSTthird;
        IEVault eTSTforth;
        IEVault eTSTfifth;

        {
            eTSTsecondary = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTsecondary.setHookConfig(address(0), 0);
            eTSTsecondary.setInterestRateModel(address(new IRMTestDefault()));
            eTSTsecondary.setMaxLiquidationDiscount(0.2e4);
            eTSTsecondary.setFeeReceiver(feeReceiver);

            eTSTthird = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTthird.setHookConfig(address(0), 0);
            eTSTthird.setInterestRateModel(address(new IRMTestDefault()));
            eTSTthird.setMaxLiquidationDiscount(0.2e4);
            eTSTthird.setFeeReceiver(feeReceiver);

            eTSTforth = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTforth.setHookConfig(address(0), 0);
            eTSTforth.setInterestRateModel(address(new IRMTestDefault()));
            eTSTforth.setMaxLiquidationDiscount(0.2e4);
            eTSTforth.setFeeReceiver(feeReceiver);

            eTSTfifth = IEVault(
                factory.createProxy(
                    address(0), true, abi.encodePacked(address(assetTST), address(oracle), unitOfAccount)
                )
            );
            eTSTfifth.setHookConfig(address(0), 0);
            eTSTfifth.setInterestRateModel(address(new IRMTestDefault()));
            eTSTfifth.setMaxLiquidationDiscount(0.2e4);
            eTSTfifth.setFeeReceiver(feeReceiver);

            uint256 initialStrategyAllocationPoints = 1000e18;
            _addStrategy(manager, address(eTSTsecondary), initialStrategyAllocationPoints);
            _addStrategy(manager, address(eTSTthird), initialStrategyAllocationPoints);
            _addStrategy(manager, address(eTSTforth), initialStrategyAllocationPoints);
            _addStrategy(manager, address(eTSTfifth), initialStrategyAllocationPoints);
        }

        uint256 amountToDeposit = 10000e18;

        // deposit into aggregator
        {
            uint256 balanceBefore = eulerYieldAggregatorVault.balanceOf(user1);
            uint256 totalSupplyBefore = eulerYieldAggregatorVault.totalSupply();
            uint256 totalAssetsDepositedBefore = eulerYieldAggregatorVault.totalAssetsDeposited();
            uint256 userAssetBalanceBefore = assetTST.balanceOf(user1);

            vm.startPrank(user1);
            assetTST.approve(address(eulerYieldAggregatorVault), amountToDeposit);
            eulerYieldAggregatorVault.deposit(amountToDeposit, user1);
            vm.stopPrank();

            assertEq(eulerYieldAggregatorVault.balanceOf(user1), balanceBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalSupply(), totalSupplyBefore + amountToDeposit);
            assertEq(eulerYieldAggregatorVault.totalAssetsDeposited(), totalAssetsDepositedBefore + amountToDeposit);
            assertEq(assetTST.balanceOf(user1), userAssetBalanceBefore - amountToDeposit);
        }

        // rebalance into strategy
        vm.warp(block.timestamp + 86400);
        {
            vm.prank(user1);
            address[] memory strategiesToRebalance = new address[](5);
            strategiesToRebalance[0] = address(eTST);
            strategiesToRebalance[1] = address(eTSTsecondary);
            strategiesToRebalance[2] = address(eTSTthird);
            strategiesToRebalance[3] = address(eTSTforth);
            strategiesToRebalance[4] = address(eTSTfifth);

            eulerYieldAggregatorVault.rebalance(strategiesToRebalance);
        }

        vm.warp(block.timestamp + 86400);
        // mock decrease by 0%
        uint256 aggrCurrentStrategyBalance = eTST.balanceOf(address(eulerYieldAggregatorVault));
        uint256 aggrCurrentStrategyBalanceAfterNegYield = aggrCurrentStrategyBalance * 9e17 / 1e18;
        vm.mockCall(
            address(eTST),
            abi.encodeWithSelector(EVault.previewRedeem.selector, aggrCurrentStrategyBalance),
            abi.encode(aggrCurrentStrategyBalanceAfterNegYield)
        );
        vm.mockCall(
            address(eTST),
            abi.encodeWithSelector(EVault.maxWithdraw.selector, address(eulerYieldAggregatorVault)),
            abi.encode(aggrCurrentStrategyBalanceAfterNegYield)
        );

        aggrCurrentStrategyBalance = eTSTsecondary.balanceOf(address(eulerYieldAggregatorVault));
        aggrCurrentStrategyBalanceAfterNegYield = aggrCurrentStrategyBalance * 9e17 / 1e18;
        vm.mockCall(
            address(eTSTsecondary),
            abi.encodeWithSelector(EVault.previewRedeem.selector, aggrCurrentStrategyBalance),
            abi.encode(aggrCurrentStrategyBalanceAfterNegYield)
        );
        vm.mockCall(
            address(eTSTsecondary),
            abi.encodeWithSelector(EVault.maxWithdraw.selector, address(eulerYieldAggregatorVault)),
            abi.encode(aggrCurrentStrategyBalanceAfterNegYield)
        );

        aggrCurrentStrategyBalance = eTSTthird.balanceOf(address(eulerYieldAggregatorVault));
        aggrCurrentStrategyBalanceAfterNegYield = aggrCurrentStrategyBalance * 9e17 / 1e18;
        vm.mockCall(
            address(eTSTthird),
            abi.encodeWithSelector(EVault.previewRedeem.selector, aggrCurrentStrategyBalance),
            abi.encode(aggrCurrentStrategyBalanceAfterNegYield)
        );
        vm.mockCall(
            address(eTSTthird),
            abi.encodeWithSelector(EVault.maxWithdraw.selector, address(eulerYieldAggregatorVault)),
            abi.encode(aggrCurrentStrategyBalanceAfterNegYield)
        );

        aggrCurrentStrategyBalance = eTSTforth.balanceOf(address(eulerYieldAggregatorVault));
        aggrCurrentStrategyBalanceAfterNegYield = aggrCurrentStrategyBalance * 9e17 / 1e18;
        vm.mockCall(
            address(eTSTforth),
            abi.encodeWithSelector(EVault.previewRedeem.selector, aggrCurrentStrategyBalance),
            abi.encode(aggrCurrentStrategyBalanceAfterNegYield)
        );
        vm.mockCall(
            address(eTSTforth),
            abi.encodeWithSelector(EVault.maxWithdraw.selector, address(eulerYieldAggregatorVault)),
            abi.encode(aggrCurrentStrategyBalanceAfterNegYield)
        );

        aggrCurrentStrategyBalance = eTSTfifth.balanceOf(address(eulerYieldAggregatorVault));
        aggrCurrentStrategyBalanceAfterNegYield = aggrCurrentStrategyBalance * 9e17 / 1e18;
        vm.mockCall(
            address(eTSTfifth),
            abi.encodeWithSelector(EVault.previewRedeem.selector, aggrCurrentStrategyBalance),
            abi.encode(aggrCurrentStrategyBalanceAfterNegYield)
        );
        vm.mockCall(
            address(eTSTfifth),
            abi.encodeWithSelector(EVault.maxWithdraw.selector, address(eulerYieldAggregatorVault)),
            abi.encode(aggrCurrentStrategyBalanceAfterNegYield)
        );

        // full withdraw, will have to withdraw from strategy as cash reserve is not enough
        {
            uint256 amountToRedeem = eulerYieldAggregatorVault.balanceOf(user1);

            vm.prank(user1);
            eulerYieldAggregatorVault.redeem(amountToRedeem, user1, user1);
        }
    }
}
