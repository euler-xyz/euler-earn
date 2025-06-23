// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC4626, IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {TestERC20} from "../../utils/mocks/TestERC20.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title DonationAttackHandler
/// @notice Handler test contract for a set of actions
contract DonationAttackHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    uint256 underlyingAmountDonatedToVault; // TODO do we really need this?

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice This function transfers any amount of underlying assets to any vault in the system simulating
    /// a big range of donation attacks
    function donateUnderlyingToVault(uint256 amount, uint8 i, uint8 j) external {
        TestERC20 _token = TestERC20(_getRandomAsset(i));

        address target = _getRandomVault(j);

        _token.mint(address(this), amount);

        _token.transfer(target, amount);
    }

    /// @notice This function transfers any amount of Markets shares to any of the EulerEarn contracts simulating
    /// a big range of donation attacks
    function donateSharesToEulerEarn(uint256 amount, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        address _token = address(_getRandomMarket(i));

        address target = _getRandomEulerEarnVault(j);

        (success, returnData) = actor.proxy(_token, abi.encodeCall(IERC20.transfer, (target, amount)));

        if (!success) {
            revert("DonationAttackHandler: donateSharesToEulerEarn failed");
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
