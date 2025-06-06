// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import "../EulerEarn.sol";

import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

contract EulerEarnMock is EulerEarn {
    constructor(
        address owner,
        address evc,
        address permit2,
        uint256 initialTimelock,
        address _asset,
        string memory __name,
        string memory __symbol
    ) EulerEarn(owner, evc, permit2, initialTimelock, _asset, __name, __symbol) {}

    function mockSetCap(IERC4626 id, uint184 supplyCap) external {
        _setCap(id, supplyCap);
    }

    function mockSimulateWithdrawEuler(uint256 assets) external view returns (uint256) {
        return _simulateWithdrawEuler(assets);
    }

    function mockSetSupplyQueue(IERC4626[] memory ids) external {
        supplyQueue = ids;
    }
}
