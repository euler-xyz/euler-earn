// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import "../../lib/euler-vault-kit/src/EVault/EVault.sol";
import {Assets, Owed} from "../../lib/euler-vault-kit/src/EVault/shared/types/Types.sol";

contract EVaultMock is EVault {
    constructor(Integrations memory integrations, DeployedModules memory modules) 
    EVault(integrations, modules)
    {}

    function mockSetTotalSupply(uint112 newValue) external {
        vaultStorage.totalBorrows = Owed.wrap(0);
        vaultStorage.cash = Assets.wrap(newValue);
    }

    // function mockSimulateWithdrawEuler(uint256 assets) external view returns (uint256) {
    //     return _simulateWithdrawEuler(assets);
    // }

    // function mockSetSupplyQueue(IERC4626[] memory ids) external {
    //     supplyQueue = ids;
    // }
}
