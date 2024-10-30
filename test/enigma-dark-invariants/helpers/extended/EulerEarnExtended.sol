// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// Interfaces
import {IEulerEarn} from "src/EulerEarn.sol";

// Contracts
import {EulerEarn} from "src/EulerEarn.sol";

contract EulerEarnExtended is EulerEarn {
    constructor(IntegrationsParams memory _integrationsParams, IEulerEarn.DeploymentParams memory _deploymentParams)
        EulerEarn(_integrationsParams, _deploymentParams)
    {}

    function getInterestLeft() external view returns (uint168) {}

    function getInterestSmearEnd() external view returns (uint40) {}

    function lastInterestUpdate() external view returns (uint40) {}
}
