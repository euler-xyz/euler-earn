// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Contracts
import {Invariants} from "../Invariants.t.sol";
import {Setup} from "../Setup.t.sol";

// Utils
import {Actor} from "../utils/Actor.sol";

contract ReplayTest1 is Invariants, Setup {
    // Generated from Echidna reproducers

    // Target contract instance (you may need to adjust this)
    ReplayTest1 Tester = this;

    modifier setup() override {
        _;
    }

	function setUp() public {
        // Deploy protocol contracts
        _setUp();

        /// @dev fixes the actor to the first user
        actor = actors[USER1];

        vm.warp(101007);
    }

	///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   		REPLAY TESTS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    
    
    function test_replay_1_withdrawEEV() public {
        _setUpActor(USER1);
        Tester.mint(1, 0, 1);
        Tester.submitCap(0, 1, 0);
        Tester.donateSharesToEulerEarn(1, 1, 0);
        Tester.mintEEV(783418, 0, 0);
        Tester.setSupplyQueue(0, 2);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_E(762493, 0);
        Tester.mintEEV(2057310, 0, 1);
        Tester.withdrawEEV(82629, 0, 3);
        
    }
    
    function test_replay_1_acceptCap() public {
        _setUpActor(USER3);
        _delay(404997);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_G(4370001, 18);
        _setUpActor(USER2);
        _delay(281317);
        _setUpActor(USER1);
        _delay(439556);
        Tester.changePrice(65535, false, 255);
        _delay(90465);
        Tester.touch(68);
        _delay(1210890);
        _setUpActor(USER2);
        _delay(439556);
        Tester.revokePendingMarketRemoval(255, 167);
        _delay(82672);
        Tester.factory();
        _setUpActor(USER1);
        _delay(127251);
        _setUpActor(USER2);
        _delay(111322);
        Tester.deposit(115792089237316195423570985008687907853269984665640564039457584007913129639935, 59, 255);
        _setUpActor(USER1);
        _delay(1855957);
        _delay(463587);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_B(1524785991, 255);
        _delay(950277);
        _delay(439556);
        Tester.setDebtSocialization(false, 154);
        _setUpActor(USER3);
        _delay(490448);
        _setUpActor(USER2);
        _delay(305572);
        Tester.mintEEV(4370001, 158, 147);
        _delay(82670);
        _delay(525476);
        Tester.setInterestFee(9159, 242);
        _setUpActor(USER1);
        _delay(404997);
        Tester.setSupplyQueue(255, 94);
        _setUpActor(USER3);
        _delay(1676028);
        _delay(463587);
        Tester.repayWithShares(1524785992, 255, 255);
        _delay(511822);
        Tester.revokePendingTimelock(228);
        _setUpActor(USER1);
        _delay(82671);
        Tester.setDebtSocialization(false, 255);
        _setUpActor(USER2);
        _delay(289103);
        Tester.revokePendingMarketRemoval(113, 180);
        _delay(82670);
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C(19);
        _setUpActor(USER1);
        _delay(96536);
        _setUpActor(USER2);
        _delay(156190);
        Tester.setDebtSocialization(false, 255);
        _setUpActor(USER3);
        _delay(758974);
        _setUpActor(USER1);
        _delay(31594);
        Tester.setDebtSocialization(true, 255);
        _setUpActor(USER2);
        _delay(610096);
        _setUpActor(USER1);
        _delay(50417);
        Tester.setSupplyQueue(232, 120);
        _setUpActor(USER3);
        _delay(490448);
        Tester.assert_ERC4626_REDEEM_INVARIANT_C(255);
        _setUpActor(USER1);
        _delay(344203);
        Tester.depositEEV(1524785992, 5, 255);
        _setUpActor(USER2);
        _delay(994693);
        _setUpActor(USER3);
        _delay(38059);
        Tester.repayWithShares(4369999, 9, 255);
        _setUpActor(USER1);
        _delay(949102);
        _setUpActor(USER3);
        _delay(305572);
        Tester.setPrice(921, 102);
        _setUpActor(USER2);
        _delay(347972);
        _setUpActor(USER3);
        _delay(255);
        Tester.mint(1524785992, 40, 254);
        _delay(50417);
        Tester.revokePendingCap(255, 5);
        _setUpActor(USER2);
        _delay(1262154);
        _setUpActor(USER1);
        _delay(271957);
        Tester.transferFee();
        _setUpActor(USER2);
        _delay(490448);
        Tester.factory();
        _delay(1147320);
        _delay(166184);
        Tester.assert_ERC4626_REDEEM_INVARIANT_C(47);
        _delay(24867);
        _setUpActor(USER1);
        _delay(19029);
        Tester.submitCap(0, 255, 254);
        _delay(404997);
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C(255);
        _setUpActor(USER3);
        _delay(117472);
        Tester.setFee(89802064172117028232547898609855424990968003084924064701420027603369609908217);
        _setUpActor(USER1);
        _delay(156190);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_C(1524785992, 118);
        _delay(45142);
        Tester.convertFees(251);
        _setUpActor(USER2);
        _delay(490448);
        Tester.changePrice(25102, true, 255);
        _setUpActor(USER3);
        _delay(1388239);
        _setUpActor(USER2);
        _delay(66543);
        Tester.revokePendingTimelock(21);
        _delay(490448);
        Tester.setPrice(1524785993, 5);
        _delay(602911);
        _setUpActor(USER1);
        _delay(127);
        Tester.touch(255);
        _setUpActor(USER2);
        _delay(136394);
        _setUpActor(USER3);
        _delay(554465);
        Tester.revokePendingCap(255, 255);
        _setUpActor(USER1);
        _delay(589279);
        _delay(554465);
        Tester.assert_ERC4626_MINT_INVARIANT_C(176);
        _delay(172101);
        _setUpActor(USER3);
        _delay(439556);
        Tester.revokePendingTimelock(255);
        _delay(303345);
        Tester.touch(107);
        _setUpActor(USER2);
        _delay(67960);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_C(1524785992, 188);
        _setUpActor(USER3);
        _delay(521446);
        _delay(209930);
        Tester.submitCap(0, 255, 217);
        _setUpActor(USER2);
        _delay(777182);
        _setUpActor(USER1);
        _delay(420078);
        Tester.assert_ERC4626_WITHDRAW_INVARIANT_C(96);
        _delay(249937);
        _delay(136393);
        Tester.revokePendingMarketRemoval(146, 255);
        _delay(198598);
        Tester.touch(76);
        _delay(1084286);
        _setUpActor(USER2);
        _delay(198598);
        Tester.transferFee();
        _delay(1958624);
        _setUpActor(USER3);
        _delay(50417);
        Tester.submitMarketRemoval(255, 29);
        _setUpActor(USER2);
        _delay(655924);
        _setUpActor(USER1);
        _delay(566039);
        Tester.assert_ERC4626_MINT_INVARIANT_C(176);
        _setUpActor(USER2);
        _delay(358061);
        _setUpActor(USER1);
        _delay(254414);
        Tester.setFee(4370000, 220);
        _setUpActor(USER2);
        _delay(225906);
        Tester.assert_ERC4626_MINT_INVARIANT_C(176);
        _delay(526194);
        _setUpActor(USER3);
        _delay(207289);
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C(125);
        _setUpActor(USER2);
        _delay(277232);
        Tester.revokePendingMarketRemoval(252, 255);
        _setUpActor(USER1);
        _delay(420078);
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C(255);
        _setUpActor(USER2);
        _delay(271957);
        _setUpActor(USER1);
        _delay(122564);
        Tester.convertFees(241);
        _setUpActor(USER2);
        _delay(275394);
        Tester.transferFee();
        _setUpActor(USER1);
        _delay(206186);
        Tester.setSupplyQueue(132, 255);
        _setUpActor(USER3);
        _delay(556907);
        _setUpActor(USER1);
        _delay(117472);
        Tester.transferFee();
        _setUpActor(USER3);
        _delay(206186);
        Tester.donateUnderlyingToVault(571, 253, 65);
        _setUpActor(USER1);
        _delay(82672);
        Tester.convertFees(255);
        _setUpActor(USER3);
        _delay(1595488);
        _setUpActor(USER2);
        _delay(65535);
        Tester.touch(182);
        _setUpActor(USER1);
        _delay(522178);
        Tester.setFee(61663027218829427706305015982531459232233737628983453529387487280194769728032);
        _delay(330188);
        _setUpActor(USER3);
        _delay(478623);
        Tester.convertFees(97);
        _setUpActor(USER2);
        _delay(511822);
        Tester.assert_ERC4626_REDEEM_INVARIANT_C(255);
        _setUpActor(USER3);
        _delay(357839);
        _setUpActor(USER2);
        _delay(511822);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_D(1524785993, 80);
        _setUpActor(USER3);
        _delay(405856);
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C(255);
        _setUpActor(USER1);
        _delay(434894);
        _setUpActor(USER3);
        _delay(547623);
        Tester.changePrice(14642, false, 37);
        _setUpActor(USER1);
        _delay(404997);
        Tester.updateWithdrawQueue([uint8(145), uint8(155), uint8(255), uint8(140)], 191, 38);
        _delay(16802);
        Tester.revokePendingCap(237, 253);
        _setUpActor(USER2);
        _delay(1042895);
        _setUpActor(USER3);
        _delay(112444);
        Tester.changePrice(65535, true, 65);
        _setUpActor(USER2);
        _delay(1666818);
        _setUpActor(USER3);
        _delay(136393);
        Tester.revokePendingCap(234, 39);
        _setUpActor(USER2);
        _delay(1742828);
        _setUpActor(USER3);
        _delay(67960);
        Tester.updateWithdrawQueue([uint8(201), uint8(134), uint8(118), uint8(255)], 113, 49);
        _delay(1383450);
        _setUpActor(USER1);
        _delay(16802);
        Tester.assert_ERC4626_REDEEM_INVARIANT_C(158);
        _delay(575374);
        _delay(407328);
        Tester.repayWithShares(4370000, 207, 128);
        _delay(116315);
        _setUpActor(USER3);
        _delay(292304);
        Tester.revokePendingTimelock(255);
        _delay(4177);
        Tester.changePrice(36003, true, 121);
        _setUpActor(USER2);
        _delay(16802);
        Tester.touch(126);
        _delay(482712);
        Tester.submitCap(1524785992, 255, 116);
        _setUpActor(USER3);
        _delay(1761710);
        _setUpActor(USER2);
        _delay(482712);
        Tester.assert_ERC4626_REDEEM_INVARIANT_C(246);
        _delay(2264545);
        _setUpActor(USER3);
        _delay(112444);
        Tester.setFee(4370000);
        _delay(277232);
        _setUpActor(USER1);
        _delay(439556);
        Tester.convertFees(193);
        _setUpActor(USER2);
        _delay(465883);
        _setUpActor(USER3);
        _delay(400981);
        Tester.transferFee();
        _setUpActor(USER2);
        _delay(947304);
        _setUpActor(USER3);
        _delay(67960);
        Tester.revokePendingMarketRemoval(255, 22);
        _delay(82671);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_C(4369999, 66);
        _setUpActor(USER2);
        _delay(338920);
        Tester.changePrice(65533, true, 255);
        _delay(33605);
        _delay(478623);
        Tester.setFee(3639400, 192);
        _setUpActor(USER3);
        _delay(819503);
        _setUpActor(USER1);
        _delay(207289);
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C(35);
        _setUpActor(USER2);
        _delay(67960);
        Tester.transferFee();
        _delay(478623);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_F(4370000, 0);
        _delay(1616167);
        _setUpActor(USER1);
        _delay(420078);
        Tester.depositEEV(0, 255, 129);
        _setUpActor(USER3);
        _delay(16802);
        Tester.revokePendingCap(218, 118);
        _setUpActor(USER2);
        _delay(528560);
        _setUpActor(USER1);
        _delay(254414);
        Tester.revokePendingTimelock(33);
        _setUpActor(USER2);
        _delay(400981);
        _delay(303345);
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C(115);
        _delay(473368);
        _setUpActor(USER1);
        _delay(82670);
        Tester.assert_ERC4626_WITHDRAW_INVARIANT_C(255);
        _setUpActor(USER3);
        _delay(400963);
        _setUpActor(USER1);
        _delay(401699);
        Tester.changePrice(65535, false, 126);
        _setUpActor(USER2);
        _delay(439556);
        Tester.transferFee();
        _setUpActor(USER1);
        _delay(73040);
        Tester.revokePendingTimelock(157);
        _setUpActor(USER2);
        _delay(387838);
        _setUpActor(USER3);
        _delay(444463);
        Tester.updateWithdrawQueue([uint8(201), uint8(118), uint8(134), uint8(255)], 113, 49);
        _delay(414736);
        Tester.revokePendingCap(105, 255);
        _setUpActor(USER1);
        _delay(127);
        Tester.assert_ERC4626_REDEEM_INVARIANT_C(18);
        _setUpActor(USER2);
        _delay(198598);
        _setUpActor(USER3);
        _delay(225906);
        Tester.repayWithShares(4370000, 176, 255);
        _setUpActor(USER2);
        _delay(112830);
        Tester.transferFee();
        _setUpActor(USER3);
        _delay(511822);
        Tester.acceptCap(255, 167);
        
    }
    

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Fast forward the time and set up an actor,
    /// @dev Use for ECHIDNA call-traces
    function _delay(uint256 _seconds) internal {
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up an actor
    function _setUpActor(address _origin) internal {
        actor = actors[_origin];
    }

    /// @notice Set up an actor and fast forward the time
    /// @dev Use for ECHIDNA call-traces
    function _setUpActorAndDelay(address _origin, uint256 _seconds) internal {
        actor = actors[_origin];
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up a specific block and actor
    function _setUpBlockAndActor(uint256 _block, address _user) internal {
        vm.roll(_block);
        actor = actors[_user];
    }

    /// @notice Set up a specific timestamp and actor
    function _setUpTimestampAndActor(uint256 _timestamp, address _user) internal {
        vm.warp(_timestamp);
        actor = actors[_user];
    }
} 