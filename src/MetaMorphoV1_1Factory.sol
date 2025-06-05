// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {IEulerEarn} from "./interfaces/IEulerEarn.sol";
import {IEulerEarnFactory} from "./interfaces/IEulerEarnFactory.sol";
import {IPerspective} from "./interfaces/IPerspective.sol";

import {EventsLib} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

import {EulerEarn} from "./EulerEarn.sol";

import {Ownable, Context} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {EVCUtil} from "../lib/ethereum-vault-connector/src/utils/EVCUtil.sol";

/// @title EulerEarnFactory
/// @author Forked with gratitude from Morpho Labs. Inspired by Silo Labs.
/// @custom:contact security@morpho.org
/// @custom:contact security@euler.xyz
/// @notice This contract allows to create EulerEarn vaults, and to index them easily.
contract EulerEarnFactory is Ownable, EVCUtil, IEulerEarnFactory {
    /* STORAGE */
    
    IPerspective public perspective;

    /// @inheritdoc IEulerEarnFactory
    mapping(address => bool) public isEulerEarn;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param _owner The owner of the factory contract.
    /// @param _perspective The address of the supported perspective contract.
    constructor(address _owner, address _evc, address _perspective) Ownable(_owner) EVCUtil(_evc) {
        if (_perspective == address(0)) revert ErrorsLib.ZeroAddress();

        perspective = IPerspective(_perspective);
    }

    /* EXTERNAL */

    /// @inheritdoc IEulerEarnFactory
    function supportedPerspective() external view returns (address) {
        return address(perspective);
    }

    /// @inheritdoc IEulerEarnFactory
    function isVerified(address id) external view returns (bool) {
        return perspective.isVerified(id);
    }

    /// @inheritdoc IEulerEarnFactory
    function setPerspective(address _perspective) public onlyEVCAccountOwner onlyOwner {
        if (_perspective == address(0)) revert ErrorsLib.ZeroAddress();

        perspective = IPerspective(_perspective);

        emit EventsLib.SetPerspective(_perspective);
    }

    /// @inheritdoc IEulerEarnFactory
    function createEulerEarn(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IEulerEarn eulerEarn) {
        eulerEarn = IEulerEarn(
            address(new EulerEarn{salt: salt}(initialOwner, address(evc), initialTimelock, asset, name, symbol))
        );

        isEulerEarn[address(eulerEarn)] = true;

        emit EventsLib.CreateEulerEarn(
            address(eulerEarn), _msgSender(), initialOwner, initialTimelock, asset, name, symbol, salt
        );
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view virtual override (EVCUtil, Context) returns (address) {
        return EVCUtil._msgSender();
    }
}
