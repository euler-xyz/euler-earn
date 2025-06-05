// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IEulerEarn} from "./IEulerEarn.sol";

/// @title IEulerEarnFactory
/// @author Forked with gratitude from Morpho Labs. Inspired by Silo Labs.
/// @custom:contact security@morpho.org
/// @custom:contact security@euler.xyz
/// @notice Interface of EulerEarn's factory.
interface IEulerEarnFactory {
    /// @notice The address of the supported perspective contract.
    function supportedPerspective() external view returns (address);

    /// @notice Whether a EulerEarn vault was created with the factory.
    function isEulerEarn(address target) external view returns (bool);

    function setPerspective(address _perspective) external;

    function isVerified(address id) external view returns (bool);

    /// @notice Creates a new EulerEarn vault.
    /// @param initialOwner The owner of the vault.
    /// @param initialTimelock The initial timelock of the vault.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    /// @param salt The salt to use for the EulerEarn vault's CREATE2 address.
    function createEulerEarn(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IEulerEarn eulerEarn);
}
