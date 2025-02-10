// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Managed.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test", "TST") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract PostCapAppreciationOverflowTest is Test {
    Managed public managed;
    TestToken public token;
    address public creator;
    address public normalUser;
    address public maliciousUser;

    function setUp() public {
        creator = address(this);
        managed = new Managed(creator, "TestHolon");
        token = new TestToken();

        normalUser = address(0x1);
        maliciousUser = address(0x2);

        // Add both users as members
        managed.addMember("normal");
        managed.addMember("malicious");

        // Set up their claims
        vm.startPrank(creator);
        managed.claim("normal", normalUser);
        managed.claim("malicious", maliciousUser);
        vm.stopPrank();

        // Fund the contract with tokens (for reward testing)
        token.transfer(address(managed), 1000 * 10**18);
    }

    /// @notice Test that setting appreciation within the cap works correctly.
    function testIndividualAppreciationWithinCap() public {
        // Use a value well below the cap (e.g., 100)
        managed.setUserAppreciation("normal", 100);
        // Use the maximum allowed value for the malicious user.
        uint256 cap = managed.maxAppreciation(); // assumed to be 1e30
        managed.setUserAppreciation("malicious", cap);

        // Check that the stored values are correct.
        assertEq(managed.appreciation("normal"), 100);
        assertEq(managed.appreciation("malicious"), cap);

        // The total appreciation should equal the sum of the two.
        uint256 expectedTotal = 100 + cap;
        assertEq(managed.totalappreciation(), expectedTotal);
    }

    /// @notice Test that attempting to set an appreciation above the cap reverts.
    function testIndividualAppreciationAboveCapReverts() public {
        uint256 cap = managed.maxAppreciation(); // assumed to be 1e30

        // Expect the transaction to revert with an error message that contains "Appreciation value too high"
        vm.expectRevert(abi.encodePacked("Appreciation value too high"));
        managed.setUserAppreciation("normal", cap + 1);
    }

    /// @notice Test the batch function for setting appreciation values with the cap enforced.
    function testBatchAppreciationCap() public {
        string[] memory users = new string[](2);
        uint256[] memory amounts = new uint256[](2);

        users[0] = "normal";
        users[1] = "malicious";

        uint256 cap = managed.maxAppreciation(); // assumed to be 1e30

        // Both values are within the cap.
        amounts[0] = 100;
        amounts[1] = cap;
        managed.setAppreciation(users, amounts);

        uint256 expectedTotal = 100 + cap;
        assertEq(managed.totalappreciation(), expectedTotal);

        // Now try to use a value above the cap in the batch.
        amounts[1] = cap + 1;
        vm.expectRevert(abi.encodePacked("Appreciation value too high"));
        managed.setAppreciation(users, amounts);
    }
}
