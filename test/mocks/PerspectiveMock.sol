// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import {IPerspective} from "../../src/interfaces/IPerspective.sol";

import "forge-std/Test.sol";

contract PerspectiveMock is IPerspective {
    address[] internal verified; 
    mapping(address => bool) lookup;

    function name() external pure returns (string memory) {
        return "PerspectiveMock";
    }

    function perspectiveVerify(address vault, bool) external {
        verified.push(vault);
        lookup[vault] = true;
    }

    function isVerified(address vault) external view returns (bool) {
        return lookup[vault];
    }

    function verifiedLength() external view returns (uint256) {
        return verified.length;
    }

    function verifiedArray() external view returns (address[] memory) {
        return verified;
    }

}