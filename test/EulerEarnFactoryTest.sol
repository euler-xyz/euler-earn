// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {EVCUtil} from "../lib/ethereum-vault-connector/src/utils/EVCUtil.sol";
import "./helpers/IntegrationTest.sol";


contract EulerEarnFactoryTest is IntegrationTest {
    function testFactoryAddressZero() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, (address(0))));
        new EulerEarnFactory(address(0), address(evc), address(perspective));

        vm.expectRevert(EVCUtil.EVC_InvalidAddress.selector);
        new EulerEarnFactory(admin, address(0), address(perspective));

        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new EulerEarnFactory(admin, address(evc), address(0));
    }

    function testCreateEulerEarn(
        address initialOwner,
        uint256 initialTimelock,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) public {
        vm.assume(address(initialOwner) != address(0));
        initialTimelock = _boundInitialTimelock(initialTimelock);

        bytes32 initCodeHash = hashInitCode(
            type(EulerEarn).creationCode,
            abi.encode(initialOwner, address(evc), initialTimelock, address(loanToken), name, symbol)
        );
        address expectedAddress = computeCreate2Address(salt, initCodeHash, address(eeFactory));

        vm.expectEmit(address(eeFactory));
        emit EventsLib.CreateEulerEarn(
            expectedAddress, address(this), initialOwner, initialTimelock, address(loanToken), name, symbol, salt
        );

        IEulerEarn eulerEarn =
            eeFactory.createEulerEarn(initialOwner, initialTimelock, address(loanToken), name, symbol, salt);

        assertEq(expectedAddress, address(eulerEarn), "computeCreate2Address");

        assertTrue(eeFactory.isVault(address(eulerEarn)), "isVault");

        assertEq(eulerEarn.owner(), initialOwner, "owner");
        assertEq(address(eulerEarn.EVC()), address(evc), "evc");
        assertEq(eulerEarn.timelock(), initialTimelock, "timelock");
        assertEq(eulerEarn.asset(), address(loanToken), "asset");
        assertEq(eulerEarn.name(), name, "name");
        assertEq(eulerEarn.symbol(), symbol, "symbol");
    }

}
