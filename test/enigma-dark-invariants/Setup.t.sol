// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Utils
import {Base} from "lib/euler-vault-kit/src/EVault/shared/Base.sol";
import {DeployPermit2} from "./utils/DeployPermit2.sol";

// Contracts
import {GenericFactory} from "lib/euler-vault-kit/src/GenericFactory/GenericFactory.sol";
import {EthereumVaultConnector} from "lib/ethereum-vault-connector/src/EthereumVaultConnector.sol";
import {ProtocolConfig} from "lib/euler-vault-kit/src/ProtocolConfig/ProtocolConfig.sol";
import {SequenceRegistry} from "lib/euler-vault-kit/src/SequenceRegistry/SequenceRegistry.sol";
import {Initialize} from "lib/euler-vault-kit/src/EVault/modules/Initialize.sol";
import {Token} from "lib/euler-vault-kit/src/EVault/modules/Token.sol";
import {Vault} from "lib/euler-vault-kit/src/EVault/modules/Vault.sol";
import {Borrowing} from "lib/euler-vault-kit/src/EVault/modules/Borrowing.sol";
import {Liquidation} from "lib/euler-vault-kit/src/EVault/modules/Liquidation.sol";
import {RiskManager} from "lib/euler-vault-kit/src/EVault/modules/RiskManager.sol";
import {BalanceForwarder} from "lib/euler-vault-kit/src/EVault/modules/BalanceForwarder.sol";
import {Governance} from "lib/euler-vault-kit/src/EVault/modules/Governance.sol";
import {EVault} from "lib/euler-vault-kit/src/EVault/EVault.sol";
import {IRMTestDefault} from "lib/euler-vault-kit/test/mocks/IRMTestDefault.sol";
import {EulerEarnFactory} from "src/EulerEarnFactory.sol";

// Interfaces
import {IERC4626} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IEVault} from "lib/euler-vault-kit/src/EVault/IEVault.sol";

// Test Contracts
import {TestERC20} from "./utils/mocks/TestERC20.sol";
import {BaseTest} from "./base/BaseTest.t.sol";
import {Actor} from "./utils/Actor.sol";
import {MockBalanceTracker} from "lib/euler-vault-kit/test/mocks/MockBalanceTracker.sol";
import {MockPriceOracle} from "lib/euler-vault-kit/test/mocks/MockPriceOracle.sol";
import {PerspectiveMock} from "test/mocks/PerspectiveMock.sol";

/// @notice Setup contract for the invariant test Suite, inherited by Tester
contract Setup is BaseTest {
    function _setUp() internal {
        // Deploy the suite assets
        _deployAssets();

        // Deploy Euler Contracts
        _deployEulerContracts();

        // Deploy core contracts of the protocol: markets
        _deployProtocolCore();

        // Deploy actors
        _setUpActors();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ASSETS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _deployAssets() internal {
        collateralToken = new TestERC20("Collateral Token", "CT", 18);
        baseAssets.push(address(collateralToken));
        allAssets.push(address(collateralToken));
        vm.label(address(collateralToken), "Collateral Token");

        loanToken = new TestERC20("Loan Token", "LT", 18);
        baseAssets.push(address(loanToken));
        allAssets.push(address(loanToken));
        vm.label(address(loanToken), "Loan Token");
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       EULER CONTRACTS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy Euler Contracts
    function _deployEulerContracts() internal {
        // Deploy factory
        factory = new GenericFactory(OWNER);
        vm.label(address(factory), "Factory");

        // Deploy Ethereum Vault Connector
        evc = new EthereumVaultConnector();
        vm.label(address(evc), "EVC");
        protocolConfig = new ProtocolConfig(OWNER, FEE_RECIPIENT);
        balanceTracker = new MockBalanceTracker();
        oracle = new MockPriceOracle();
        vm.label(address(oracle), "Oracle");
        unitOfAccount = address(1);
        permit2 = DeployPermit2.deployPermit2();
        vm.label(address(permit2), "Permit2");
        sequenceRegistry = address(new SequenceRegistry());

        // Deploy Integrations & Modules
        integrations =
            Base.Integrations(address(evc), address(protocolConfig), sequenceRegistry, address(balanceTracker), permit2);

        modules.initialize = address(new Initialize(integrations));
        modules.token = address(new Token(integrations));
        modules.vault = address(new Vault(integrations));
        modules.borrowing = address(new Borrowing(integrations));
        modules.liquidation = address(new Liquidation(integrations));
        modules.riskManager = address(new RiskManager(integrations));
        modules.balanceForwarder = address(new BalanceForwarder(integrations));
        modules.governance = address(new Governance(integrations));

        address evaultImpl = address(new EVault(integrations, modules));
        factory.setImplementation(evaultImpl);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       CORE CONTRACTS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy protocol core contracts
    function _deployProtocolCore() internal {
        perspective = new PerspectiveMock();

        // DEPLOY MARKETS
        // Idle Vault
        idleVault = IERC4626(
            factory.createProxy(address(0), true, abi.encodePacked(address(loanToken), address(oracle), unitOfAccount))
        );
        IEVault(address(idleVault)).setHookConfig(address(0), 0);
        perspective.perspectiveVerify(address(idleVault));
        vm.label(address(idleVault), "IdleVault");

        // Collateral Vault eTST
        eTST = IEVault(
            factory.createProxy(
                address(0), true, abi.encodePacked(address(collateralToken), address(oracle), unitOfAccount)
            )
        );
        vm.label(address(eTST), "eTST (Collateral Vault)");
        eTST.setHookConfig(address(0), 0);
        _pushEVault(address(eTST), false);

        // Loan Vault eTST2
        eTST2 = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(loanToken), address(oracle), unitOfAccount))
        );
        vm.label(address(eTST2), "eTST2 (Loan Vault)");
        eTST2.setHookConfig(address(0), 0);
        eTST2.setInterestRateModel(address(new IRMTestDefault()));
        eTST2.setMaxLiquidationDiscount(0.2e4);
        eTST2.setLTV(address(eTST), 0.8e4, 0.8e4, 0);
        perspective.perspectiveVerify(address(eTST2));
        _pushEVault(address(eTST2), true);

        // Loan Vault eTST3
        eTST3 = IEVault(
            factory.createProxy(address(0), true, abi.encodePacked(address(loanToken), address(oracle), unitOfAccount))
        );
        vm.label(address(eTST3), "eTST3 (Loan Vault)");
        eTST3.setHookConfig(address(0), 0);
        eTST3.setInterestRateModel(address(new IRMTestDefault()));
        eTST3.setMaxLiquidationDiscount(0.2e4);
        eTST3.setLTV(address(eTST), 0.85e4, 0.85e4, 0);
        perspective.perspectiveVerify(address(eTST3));
        _pushEVault(address(eTST3), true);

        // DEPLOY EULER EARN CONTRACTS
        eulerEarnFactory = new EulerEarnFactory(OWNER, address(evc), permit2, address(perspective));

        // Deploy Euler Earn
        eulerEarn = eulerEarnFactory.createEulerEarn(
            OWNER, TIMELOCK, address(loanToken), "EulerEarn Vault", "EEV", bytes32(uint256(1))
        );
        vm.label(address(eulerEarn), "EulerEarn Vault");
        eulerEarn.setCurator(OWNER);
        eulerEarn.setIsAllocator(OWNER, true);
        eulerEarn.setFeeRecipient(FEE_RECIPIENT);
        allAssets.push(address(eulerEarn));
        allVaults.push(IERC4626(address(eulerEarn)));
        eulerEarnVaults.push(address(eulerEarn));

        // Deploy Nested Euler Earn
        eulerEarn2 = eulerEarnFactory.createEulerEarn(
            OWNER, TIMELOCK, address(loanToken), "EulerEarn2 Vault", "EEV2", bytes32(uint256(1))
        );
        vm.label(address(eulerEarn2), "EulerEarn2 Vault");
        eulerEarn2.setCurator(OWNER);
        eulerEarn2.setIsAllocator(OWNER, true);
        eulerEarn2.setFeeRecipient(FEE_RECIPIENT);
        allAssets.push(address(eulerEarn2));
        allVaults.push(IERC4626(address(eulerEarn2)));
        allMarkets.push(IERC4626(address(eulerEarn2)));
        eulerEarnVaults.push(address(eulerEarn2));

        // Set Infinite Cap for Idle Vault
        eulerEarn.submitCap(idleVault, type(uint184).max);
        eulerEarn2.submitCap(idleVault, type(uint184).max);
        vm.warp(block.timestamp + eulerEarn.timelock());
        eulerEarn.acceptCap(idleVault);
        eulerEarn2.acceptCap(idleVault);

        // Idle Vault must be pushed last
        _pushEVault(address(idleVault), false);

        // TODO missing public allocator
    }

    function _pushEVault(address _eVault, bool _isLoanVault) internal {
        allMarkets.push(IERC4626(_eVault));
        allVaults.push(IERC4626(_eVault));
        eVaults.push(IEVault(_eVault));
        if (_isLoanVault) {
            loanVaults.push(IEVault(_eVault));
        }
        allAssets.push(address(_eVault));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTORS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy protocol actors and initialize their balances
    function _setUpActors() internal {
        // Initialize the three actors of the fuzzers
        address[] memory addresses = new address[](3);
        addresses[0] = USER1;
        addresses[1] = USER2;
        addresses[2] = USER3;

        // Initialize the tokens array
        address[] memory tokens = new address[](2);
        tokens[0] = address(loanToken);
        tokens[1] = address(collateralToken);

        address[] memory contracts_ = new address[](6);
        contracts_[0] = address(idleVault);
        contracts_[1] = address(eTST);
        contracts_[2] = address(eTST2);
        contracts_[3] = address(eTST3);
        contracts_[4] = address(eulerEarn);
        contracts_[5] = address(eulerEarn2);

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

        // Enable collateral for the actor
        vm.prank(address(_actor));
        evc.enableCollateral(address(_actor), address(eTST));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /*     function _sortLoanMarkets() internal {TODO check if this is needed
        uint256 length = unsortedMarkets.length;
        address[] memory sortedMarkets = new address[](length);

        // Copy unsortedMarkets into sortedMarkets
        for (uint256 i = 0; i < length; i++) {
            sortedMarkets[i] = address(unsortedMarkets[i]);
        }

        // Sort using Bubble Sort
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                if (sortedMarkets[j] > sortedMarkets[j + 1]) {
                    (sortedMarkets[j], sortedMarkets[j + 1]) = (sortedMarkets[j + 1], sortedMarkets[j]);
                }
            }
        }

        // Push sorted addresses into the markets array
        for (uint256 i = 0; i < length; i++) {
            markets.push(IERC4626(sortedMarkets[i]));
        }
    } */

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          LOGGING                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
