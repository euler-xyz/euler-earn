// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// Libraries
import {StorageLib as Storage, EulerEarnStorage} from "src/lib/StorageLib.sol";

// Contracts
import {EulerEarnVaultModule} from "src/module/EulerEarnVault.sol";
import {Shared} from "src/common/Shared.sol";

contract EulerEarnVaultModuleExtended is EulerEarnVaultModule {
    constructor(IntegrationsParams memory _integrationsParams) Shared(_integrationsParams) {}

    function getInterestLeft() external view returns (uint168) {
        EulerEarnStorage storage $ = Storage._getEulerEarnStorage();
        return $.interestLeft;
    }

    function getInterestSmearEnd() external view returns (uint168) {
        EulerEarnStorage storage $ = Storage._getEulerEarnStorage();
        return $.interestSmearEnd;
    }

    function lastInterestUpdate() external view returns (uint40) {
        EulerEarnStorage storage $ = Storage._getEulerEarnStorage();
        return $.lastInterestUpdate;
    }
}
