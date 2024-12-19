// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IEulerEarnVaultModuleHandler {
    function rebalance(uint8 i, uint8 j, uint8 k) external;
    function harvest() external;
}
