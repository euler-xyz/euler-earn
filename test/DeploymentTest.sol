// // SPDX-License-Identifier: GPL-2.0-or-later
// pragma solidity ^0.8.26;

// import "./helpers/IntegrationTest.sol";

// contract DeploymentTest is IntegrationTest {
//     function testSetName(string memory name) public {
//         vm.prank(OWNER);
//         vault.setName(name);

//         assertEq(vault.name(), name);
//     }

//     function testSetNameEvent(string memory name) public {
//         vm.expectEmit();
//         emit EventsLib.SetName(name);
//         vm.prank(OWNER);
//         vault.setName(name);
//     }

//     function testSetNameNotOwner(string memory name) public {
//         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
//         vault.setName(name);
//     }

//     function testSetSymbol(string memory symbol) public {
//         vm.prank(OWNER);
//         vault.setSymbol(symbol);

//         assertEq(vault.symbol(), symbol);
//     }

//     function testSetSymbolEvent(string memory symbol) public {
//         vm.expectEmit();
//         emit EventsLib.SetSymbol(symbol);
//         vm.prank(OWNER);
//         vault.setSymbol(symbol);
//     }

//     function testSetSymbolNotOwner(string memory name) public {
//         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
//         vault.setSymbol(name);
//     }

//     function testDeployEulerEarnAddresssZero() public {
//         vm.expectRevert(ErrorsLib.ZeroAddress.selector);
//         createEulerEarn(OWNER, address(0), 1 days, address(loanToken), "EulerEarn Vault", "MMV");
//     }

//     function testDeployEulerEarnNotToken(address notToken) public {
//         vm.assume(address(notToken) != address(loanToken));
//         vm.assume(address(notToken) != address(collateralToken));
//         vm.assume(address(notToken) != address(vault));

//         vm.expectRevert();
//         createEulerEarn(OWNER, address(morpho), 1 days, notToken, "EulerEarn Vault", "MMV");
//     }

//     function testDeployEulerEarn(
//         address owner,
//         address morpho,
//         uint256 initialTimelock,
//         string memory name,
//         string memory symbol
//     ) public {
//         assumeNotZeroAddress(owner);
//         assumeNotZeroAddress(morpho);
//         initialTimelock = _boundInitialTimelock(initialTimelock);

//         IEulerEarn newVault = createEulerEarn(owner, morpho, initialTimelock, address(loanToken), name, symbol);

//         assertEq(newVault.owner(), owner, "owner");
//         assertEq(address(newVault.MORPHO()), morpho, "morpho");
//         assertEq(newVault.timelock(), initialTimelock, "timelock");
//         assertEq(newVault.asset(), address(loanToken), "asset");
//         assertEq(newVault.name(), name, "name");
//         assertEq(newVault.symbol(), symbol, "symbol");
//         assertEq(loanToken.allowance(address(newVault), address(morpho)), type(uint256).max, "loanToken allowance");
//     }
// }
