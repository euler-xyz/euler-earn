// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// a16z properties tests
import {ERC4626Test} from "erc4626-tests/ERC4626.test.sol";
// contracts
import {EulerAggregationVault} from "../src/core/EulerAggregationVault.sol";
import {Hooks} from "../src/core/module/Hooks.sol";
import {Rewards} from "../src/core/module/Rewards.sol";
import {Fee} from "../src/core/module/Fee.sol";
import {Rebalance} from "../src/core/module/Rebalance.sol";
import {WithdrawalQueue} from "../src/core/module/WithdrawalQueue.sol";
import {EulerAggregationVaultFactory} from "../src/core/EulerAggregationVaultFactory.sol";
import {Strategy} from "../src/core/module/Strategy.sol";
// mocks
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
// evc setup
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";

contract A16zPropertyTests is ERC4626Test {
    uint256 public constant CASH_RESERVE_ALLOCATION_POINTS = 1000e18;

    EthereumVaultConnector public evc;
    address public factoryOwner;

    // core modules
    Rewards rewardsImpl;
    Hooks hooksImpl;
    Fee feeModuleImpl;
    Strategy strategyModuleImpl;
    Rebalance rebalanceModuleImpl;
    WithdrawalQueue withdrawalQueueModuleImpl;

    EulerAggregationVaultFactory eulerAggregationVaultFactory;
    EulerAggregationVault eulerAggregationVault;

    function setUp() public override {
        factoryOwner = makeAddr("FACTORY_OWNER");
        evc = new EthereumVaultConnector();

        rewardsImpl = new Rewards();
        hooksImpl = new Hooks();
        feeModuleImpl = new Fee();
        strategyModuleImpl = new Strategy();
        rebalanceModuleImpl = new Rebalance();
        withdrawalQueueModuleImpl = new WithdrawalQueue();

        EulerAggregationVaultFactory.FactoryParams memory factoryParams = EulerAggregationVaultFactory.FactoryParams({
            owner: factoryOwner,
            evc: address(evc),
            balanceTracker: address(0),
            rewardsModuleImpl: address(rewardsImpl),
            hooksModuleImpl: address(hooksImpl),
            feeModuleImpl: address(feeModuleImpl),
            strategyModuleImpl: address(strategyModuleImpl),
            rebalanceModuleImpl: address(rebalanceModuleImpl),
            withdrawalQueueModuleImpl: address(withdrawalQueueModuleImpl)
        });
        eulerAggregationVaultFactory = new EulerAggregationVaultFactory(factoryParams);
        vm.prank(factoryOwner);

        _underlying_ = address(new ERC20Mock());
        _vault_ = eulerAggregationVaultFactory.deployEulerAggregationVault(
            _underlying_, "E20M_Agg", "E20M_Agg", CASH_RESERVE_ALLOCATION_POINTS
        );
        _delta_ = 0;
        _vaultMayBeEmpty = false;
        _unlimitedAmount = false;
    }

    function testToAvoidCoverage() public pure {
        return;
    }
}
