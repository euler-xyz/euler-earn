// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {ErrorsLib} from "src/lib/ErrorsLib.sol";
import {EventsLib} from "src/lib/EventsLib.sol";
import {AmountCapLib as AggAmountCapLib, AmountCap as AggAmountCap} from "src/lib/AmountCapLib.sol";
import {ConstantsLib} from "src/lib/ConstantsLib.sol";

// Contracts
import {EulerEarn, IEulerEarn, Shared} from "src/EulerEarn.sol";
import {EulerEarnVault} from "src/module/EulerEarnVault.sol";
import {Hooks, HooksModule} from "src/module/Hooks.sol";
import {Rewards} from "src/module/Rewards.sol";
import {Fee} from "src/module/Fee.sol";
import {WithdrawalQueue} from "src/module/WithdrawalQueue.sol";
import {EulerEarnFactory} from "src/EulerEarnFactory.sol";
import {Strategy} from "src/module/Strategy.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";

// Interfaces
import {IEVault} from "evk/EVault/IEVault.sol";

// Mock Contracts
import {TestERC20} from "test/enigma-dark-invariants/utils/mocks/TestERC20.sol";
import {MockPriceOracle} from "../utils/mocks/MockPriceOracle.sol";

// Utils
import {Actor} from "../utils/Actor.sol";

/// @notice BaseStorage contract for all test contracts, works in tandem with BaseTest
abstract contract BaseStorage {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       CONSTANTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    uint256 constant MAX_TOKEN_AMOUNT = 1e29;

    uint256 constant ONE_DAY = 1 days;
    uint256 constant ONE_MONTH = ONE_YEAR / 12;
    uint256 constant ONE_YEAR = 365 days;

    uint256 internal constant NUMBER_OF_ACTORS = 3;
    uint256 internal constant INITIAL_ETH_BALANCE = 1e26;
    uint256 internal constant INITIAL_COLL_BALANCE = 1e21;

    uint256 internal constant CASH_RESERVE_ALLOCATION_POINTS = 1000e18;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTORS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Stores the actor during a handler call
    Actor internal actor;

    /// @notice Mapping of fuzzer user addresses to actors
    mapping(address => Actor) internal actors;

    /// @notice Array of all actor addresses
    address[] internal actorAddresses;

    /// @notice The address that is targeted when executing an action
    address internal targetActor;

    /// @notice permissioned addresses
    address internal deployer = address(this);
    address internal manager = address(this);

    address internal feeRecipient;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SUITE STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // CORE MODULES
    EulerEarnVault eulerEarnVaultModule;
    Rewards rewardsModule;
    Hooks hooksModule;
    Fee feeModule;
    Strategy strategyModule;
    WithdrawalQueue withdrawalQueueModule;

    // EXTRA
    /// @notice The Factory contract that deploys EulerEarn contracts
    EulerEarnFactory eulerEulerEarnVaultFactory;

    /// @notice The implementation contract for EulerEarn
    address eulerEarnImpl;

    /// @notice The EulerEarn contract
    EulerEarn eulerEulerEarnVault;
    GenericFactory factory;

    IEVault eTST;
    IEVault eTST2;
    IEVault eTST3;

    // HELPER CONTRACTS
    /// @notice Helper parameters
    Shared.IntegrationsParams integrationsParams;
    IEulerEarn.DeploymentParams deploymentParams;
    MockPriceOracle oracle;
    ProtocolConfig protocolConfig;
    address balanceTracker;
    address sequenceRegistry;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       EXTRA VARIABLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Array of base assets for the suite
    address[] internal baseAssets;

    /// @notice Mock asset used on the suite
    TestERC20 internal assetTST;

    /// @notice Evc contract
    EthereumVaultConnector evc;

    /// @notice Permit2 contract
    address permit2;

    address[] internal strategies;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STRUCTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
