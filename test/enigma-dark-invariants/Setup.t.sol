// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Utils
import "forge-std/console.sol";

// Libraries
import {ConstantsLib} from "../../src/lib/ConstantsLib.sol";
import {DeployPermit2} from "./utils/DeployPermit2.sol";

// Contracts
import {EulerEarn, IEulerEarn, Shared} from "../../src/EulerEarn.sol";
import {EulerEarnVault} from "../../src/module/EulerEarnVault.sol";
import {Hooks, HooksModule} from "../../src/module/Hooks.sol";
import {Rewards} from "../../src/module/Rewards.sol";
import {Fee} from "../../src/module/Fee.sol";
import {WithdrawalQueue} from "../../src/module/WithdrawalQueue.sol";
import {EulerEarnFactory} from "../../src/EulerEarnFactory.sol";
import {Strategy} from "../../src/module/Strategy.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {SequenceRegistry} from "evk/SequenceRegistry/SequenceRegistry.sol";
import {Base} from "evk/EVault/shared/Base.sol";
import {Dispatch} from "evk/EVault/Dispatch.sol";
import {EVault} from "evk/EVault/EVault.sol";

// Modules
import {Initialize} from "evk/EVault/modules/Initialize.sol";
import {Token} from "evk/EVault/modules/Token.sol";
import {Vault} from "evk/EVault/modules/Vault.sol";
import {Borrowing} from "evk/EVault/modules/Borrowing.sol";
import {Liquidation} from "evk/EVault/modules/Liquidation.sol";
import {BalanceForwarder} from "evk/EVault/modules/BalanceForwarder.sol";
import {Governance} from "evk/EVault/modules/Governance.sol";
import {RiskManager} from "evk/EVault/modules/RiskManager.sol";
import {TrackingRewardStreams} from "reward-streams/TrackingRewardStreams.sol";

// Interfaces
import {IEVault} from "evk/EVault/IEVault.sol";
import {IRMTestDefault} from "evk-test/mocks/IRMTestDefault.sol";

// Test Contracts
import {TestERC20} from "test/enigma-dark-invariants/utils/mocks/TestERC20.sol";
import {BaseTest} from "test/enigma-dark-invariants/base/BaseTest.t.sol";
import {MockPriceOracle} from "./utils/mocks/MockPriceOracle.sol";
import {Actor} from "./utils/Actor.sol";

/// @notice Setup contract for the invariant test Suite, inherited by Tester
contract Setup is BaseTest {
    /// @notice Number of actors to deploy
    function _setUp() internal {
        // Deploy protocol contracts and protocol actors
        _deployProtocolCore();

        // Deploy strategies
        _deployStrategies();
    }

    /// @notice Deploy protocol core contracts
    function _deployProtocolCore() internal {
        // Deploy the EVC
        evc = new EthereumVaultConnector();

        // Deploy permit2 contract
        permit2 = DeployPermit2.deployPermit2();

        // Setup fee recipient
        feeRecipient = _makeAddr("feeRecipient");
        protocolConfig = new ProtocolConfig(address(this), feeRecipient);

        // Deploy the oracle and integrations
        balanceTracker = address(new TrackingRewardStreams(address(evc), 2 weeks));
        oracle = new MockPriceOracle();
        sequenceRegistry = address(new SequenceRegistry());

        // Setup parameters
        integrationsParams = Shared.IntegrationsParams({
            evc: address(evc),
            balanceTracker: balanceTracker,
            permit2: permit2,
            isHarvestCoolDownCheckOn: true
        });

        // Deploy base assets
        assetTST = new TestERC20("Test Token", "TST", 18); //TODO configure different decimals base assets
        baseAssets.push(address(assetTST));

        // Deploy modules
        eulerEarnVaultModule = new EulerEarnVault(integrationsParams);
        rewardsModule = new Rewards(integrationsParams);
        hooksModule = new Hooks(integrationsParams);
        feeModule = new Fee(integrationsParams);
        strategyModule = new Strategy(integrationsParams);
        withdrawalQueueModule = new WithdrawalQueue(integrationsParams);

        // Setup deploy params
        deploymentParams = IEulerEarn.DeploymentParams({
            eulerEarnVaultModule: address(eulerEarnVaultModule),
            rewardsModule: address(rewardsModule),
            hooksModule: address(hooksModule),
            feeModule: address(feeModule),
            strategyModule: address(strategyModule),
            withdrawalQueueModule: address(withdrawalQueueModule)
        });
        eulerEarnImpl = address(new EulerEarn(integrationsParams, deploymentParams));

        eulerEulerEarnVaultFactory = new EulerEarnFactory(eulerEarnImpl);

        // Deploy the EulerEarn contract using the factory
        eulerEulerEarnVault = EulerEarn(
            eulerEulerEarnVaultFactory.deployEulerEarn(
                address(assetTST), "assetTST_Agg", "assetTST_Agg", CASH_RESERVE_ALLOCATION_POINTS
            )
        );

        // grant admin roles to deployer
        eulerEulerEarnVault.grantRole(ConstantsLib.GUARDIAN_ADMIN, deployer);
        eulerEulerEarnVault.grantRole(ConstantsLib.STRATEGY_OPERATOR_ADMIN, deployer);
        eulerEulerEarnVault.grantRole(ConstantsLib.EULER_EARN_MANAGER_ADMIN, deployer);
        eulerEulerEarnVault.grantRole(ConstantsLib.WITHDRAWAL_QUEUE_MANAGER_ADMIN, deployer);

        // grant roles to manager
        eulerEulerEarnVault.grantRole(ConstantsLib.GUARDIAN, manager);
        eulerEulerEarnVault.grantRole(ConstantsLib.STRATEGY_OPERATOR, manager);
        eulerEulerEarnVault.grantRole(ConstantsLib.EULER_EARN_MANAGER, manager);
        eulerEulerEarnVault.grantRole(ConstantsLib.WITHDRAWAL_QUEUE_MANAGER, manager);

        // Set performance fee recipient
        eulerEulerEarnVault.setFeeRecipient(feeRecipient);
    }

    function _deployStrategies() internal {
        // Deploy the modules
        Base.Integrations memory integrations =
            Base.Integrations(address(evc), address(protocolConfig), sequenceRegistry, balanceTracker, permit2);

        Dispatch.DeployedModules memory modules = Dispatch.DeployedModules({
            initialize: address(new Initialize(integrations)),
            token: address(new Token(integrations)),
            vault: address(new Vault(integrations)),
            borrowing: address(new Borrowing(integrations)),
            liquidation: address(new Liquidation(integrations)),
            riskManager: address(new RiskManager(integrations)),
            balanceForwarder: address(new BalanceForwarder(integrations)),
            governance: address(new Governance(integrations))
        });

        // Deploy the vault implementation
        address evaultImpl = address(new EVault(integrations, modules));

        // Deploy the vault factory and set the implementation
        factory = new GenericFactory(deployer);
        factory.setImplementation(evaultImpl);

        // Deploy the vaults (strategies)
        eTST = _deployEVault(address(assetTST));
        strategies.push(address(eTST));

        eTST2 = _deployEVault(address(assetTST));
        strategies.push(address(eTST2));

        eTST3 = _deployEVault(address(assetTST));
        strategies.push(address(eTST3));
    }

    function _deployEVault(address asset) internal returns (IEVault eVault) {
        // Deploy the eTST
        eVault = IEVault(factory.createProxy(address(0), true, abi.encodePacked(asset, address(oracle), address(1))));

        // Configure the vault
        eVault.setHookConfig(address(0), 0);
        eVault.setInterestRateModel(address(new IRMTestDefault()));
        eVault.setMaxLiquidationDiscount(0.2e4);
        eVault.setFeeReceiver(address(10));
    }

    /// @notice Deploy protocol actors and initialize their balances
    function _setUpActors() internal {
        // Initialize the three actors of the fuzzers
        address[] memory addresses = new address[](3);
        addresses[0] = USER1;
        addresses[1] = USER2;
        addresses[2] = USER3;

        // Initialize the tokens array
        address[] memory tokens = new address[](1);
        tokens[0] = address(assetTST);

        address[] memory contracts_ = new address[](1);
        contracts_[0] = address(eulerEulerEarnVault);

        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            // Deploy actor proxies and approve system contracts_
            address _actor = _setUpActor(addresses[i], tokens, contracts_);

            // Mint initial balances to actors
            for (uint256 j = 0; j < tokens.length; j++) {
                TestERC20 _token = TestERC20(tokens[j]);
                _token.mint(_actor, INITIAL_BALANCE);
            }
            actorAddresses.push(_actor);
        }
    }

    /// @notice Deploy an actor proxy contract for a user address
    /// @param userAddress Address of the user
    /// @param tokens Array of token addresses
    /// @param contracts_ Array of contract addresses to aprove tokens to
    /// @return actorAddress Address of the deployed actor
    function _setUpActor(address userAddress, address[] memory tokens, address[] memory contracts_)
        internal
        returns (address actorAddress)
    {
        bool success;
        Actor _actor = new Actor(tokens, contracts_);
        actors[userAddress] = _actor;
        (success,) = address(_actor).call{value: INITIAL_ETH_BALANCE}("");
        assert(success);
        actorAddress = address(_actor);
    }
}
