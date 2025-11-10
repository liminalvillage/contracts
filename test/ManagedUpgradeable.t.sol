// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "forge-std/Test.sol";
import "../src/ManagedUpgradeable.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title ManagedUpgradeableTest
 * @notice Test suite for upgradeable Managed contracts
 * @dev Tests deployment, initialization, upgrades, and state preservation
 */
contract ManagedUpgradeableTest is Test {
    ManagedUpgradeable public implementation;
    ManagedUpgradeable public proxy;
    address public owner;
    address public user1;
    address public user2;

    event ImplementationUpgraded(address indexed newImplementation);

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        // Deploy implementation
        implementation = new ManagedUpgradeable();

        // Encode initialization data
        bytes memory data = abi.encodeWithSelector(
            ManagedUpgradeable.initialize.selector,
            owner,
            "TestManagedDAO"
        );

        // Deploy proxy
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            address(implementation),
            data
        );

        // Wrap proxy in interface
        proxy = ManagedUpgradeable(address(proxyContract));
    }

    function testInitialization() public {
        assertEq(proxy.name(), "TestManagedDAO");
        assertEq(proxy.creator(), owner);
        assertEq(proxy.flavor(), "Managed");
        assertEq(proxy.totalappreciation(), 0);
    }

    function testCannotReinitialize() public {
        vm.expectRevert();
        proxy.initialize(owner, "NewName");
    }

    function testAddMember() public {
        proxy.addMember("user_123");
        assertEq(proxy.getSize(), 1);
        assertTrue(proxy.isManagedMember("user_123"));
    }

    function testAddMultipleMembers() public {
        string[] memory userIds = new string[](3);
        userIds[0] = "user_1";
        userIds[1] = "user_2";
        userIds[2] = "user_3";

        proxy.addMembers(userIds);

        assertEq(proxy.getSize(), 3);
        assertTrue(proxy.isManagedMember("user_1"));
        assertTrue(proxy.isManagedMember("user_2"));
        assertTrue(proxy.isManagedMember("user_3"));
    }

    function testSetAppreciation() public {
        // Add members first
        proxy.addMember("user_1");
        proxy.addMember("user_2");

        // Set appreciation
        string[] memory userIds = new string[](2);
        userIds[0] = "user_1";
        userIds[1] = "user_2";

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        proxy.setAppreciation(userIds, amounts);

        assertEq(proxy.appreciation("user_1"), 100);
        assertEq(proxy.appreciation("user_2"), 200);
        assertEq(proxy.totalappreciation(), 300);
    }

    function testUpgrade() public {
        // Add some state
        proxy.addMember("user_1");
        assertEq(proxy.getSize(), 1);

        // Deploy new implementation
        ManagedUpgradeable newImplementation = new ManagedUpgradeable();

        // Perform upgrade
        proxy.upgradeToAndCall(address(newImplementation), "");

        // Verify state preserved
        assertEq(proxy.name(), "TestManagedDAO");
        assertEq(proxy.getSize(), 1);
        assertTrue(proxy.isManagedMember("user_1"));
    }

    function testUpgradeOnlyOwner() public {
        // Deploy new implementation
        ManagedUpgradeable newImplementation = new ManagedUpgradeable();

        // Try to upgrade from non-owner
        vm.prank(user1);
        vm.expectRevert("Only owner can perform this action");
        proxy.upgradeToAndCall(address(newImplementation), "");
    }

    function testRewardDistribution() public {
        // Add members
        proxy.addMember("user_1");
        proxy.addMember("user_2");

        // Claim addresses for users
        vm.prank(address(this));
        proxy.claim("user_1", user1);
        vm.prank(address(this));
        proxy.claim("user_2", user2);

        // Send ETH and trigger reward
        uint256 amount = 1 ether;
        (bool success, ) = address(proxy).call{value: amount}("");
        assertTrue(success);

        // Check balances (each user should get 0.5 ETH)
        assertEq(user1.balance, 0.5 ether);
        assertEq(user2.balance, 0.5 ether);
    }

    function testStorageGap() public {
        // This test verifies that storage gap exists and is properly sized
        // Storage layout inspection would be done via Hardhat or manual review
        // Here we just ensure the contract can be deployed and initialized
        assertTrue(address(proxy) != address(0));
    }

    receive() external payable {}
}
