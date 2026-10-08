// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../src/Bundle.sol";
import "../../src/EvoVoucher.sol";

/// The oil as a token: who mints it, how a Bundle divides it, how it is
/// redeemed.
contract EvoVoucherTest is Test {
    uint256 constant STEEPNESS = 5e17;
    uint256 constant NZONES = 2;

    address attester = makeAddr("attester");
    address stranger = makeAddr("stranger");
    address picker = makeAddr("picker");

    EvoVoucher evo;
    Bundle mother; // the collective: location 25 %, pickers 75 %
    Bundle pickers; // the pickers' own Bundle: one picker, all interior

    event Minted(address indexed to, uint256 litres, string memo);
    event Redeemed(address indexed holder, uint256 litres, string memo);

    function setUp() public {
        evo = new EvoVoucher(attester);

        vm.prank(attester);
        mother = new Bundle(attester, "mother", "Olive collective", STEEPNESS, NZONES);
        vm.prank(attester);
        pickers = new Bundle(attester, "pickers", "Pickers", STEEPNESS, NZONES);

        string[] memory seats = new string[](2);
        seats[0] = "location";
        seats[1] = "pickers";
        uint256[] memory shares = new uint256[](2);
        shares[0] = 2500;
        shares[1] = 7500;
        string[] memory none = new string[](0);
        uint256[] memory noRings = new uint256[](0);
        vm.prank(attester);
        mother.syncAll(10000, 0, STEEPNESS, NZONES, seats, shares, none, noRings);

        string[] memory one = new string[](1);
        one[0] = "picker";
        uint256[] memory all = new uint256[](1);
        all[0] = 10000;
        vm.startPrank(attester);
        pickers.syncAll(10000, 0, STEEPNESS, NZONES, one, all, none, noRings);
        pickers.claim("picker", picker);
        mother.claim("pickers", address(pickers));
        vm.stopPrank();
    }

    function test_mint_onlyTheAttester() public {
        vm.prank(stranger);
        vm.expectRevert();
        evo.mint(stranger, 1 ether, "nope");

        vm.expectEmit(true, false, false, true);
        emit Minted(attester, 200 ether, "first pressing");
        vm.prank(attester);
        evo.mint(attester, 200 ether, "first pressing");
        assertEq(evo.balanceOf(attester), 200 ether);
        assertEq(evo.decimals(), 18);
    }

    function test_reward_cascadesLitresThroughTheSplit() public {
        vm.startPrank(attester);
        evo.mint(attester, 100 ether, "lot");
        evo.transfer(address(mother), 100 ether);
        mother.reward(address(evo), 100 ether);
        vm.stopPrank();

        // the location is unbound: its 25 L are held for it in the mother
        assertEq(mother.tokenBalance("location", address(evo)), 25 ether);
        // the pickers' Bundle took its 75 L and passed them to the picker
        assertEq(evo.balanceOf(address(pickers)), 0);
        assertEq(evo.balanceOf(picker), 75 ether);
    }

    function test_redeem_burnsWhatWasHandedOver() public {
        vm.prank(attester);
        evo.mint(picker, 12 ether, "lot");

        vm.expectEmit(true, false, false, true);
        emit Redeemed(picker, 5 ether, "collected at the mill");
        vm.prank(picker);
        evo.redeem(5 ether, "collected at the mill");
        assertEq(evo.balanceOf(picker), 7 ether);
        assertEq(evo.totalSupply(), 7 ether);
    }
}
