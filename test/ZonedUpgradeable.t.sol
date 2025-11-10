// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "forge-std/Test.sol";
import "../src/ZonedUpgradeable.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

/**
 * @title ZonedUpgradeableTest
 * @notice Comprehensive test suite for upgradeable Zoned contracts
 */
contract ZonedUpgradeableTest is Test {
    ZonedUpgradeable public implementation;
    ZonedUpgradeable public proxy;
    TestToken public token;

    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public attacker;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);
        attacker = address(0x999);

        // Deploy implementation
        implementation = new ZonedUpgradeable();

        // Encode initialization data
        bytes memory data = abi.encodeWithSelector(
            ZonedUpgradeable.initialize.selector,
            "creator_123",
            owner,
            "TestZonedDAO",
            6  // 6 zones
        );

        // Deploy proxy
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            address(implementation),
            data
        );

        proxy = ZonedUpgradeable(address(proxyContract));

        // Deploy test token
        token = new TestToken();
        token.transfer(address(proxy), 1000 * 10**18);

        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
    }

    // ============================================
    // INITIALIZATION TESTS
    // ============================================

    function testInitialization() public {
        assertEq(proxy.name(), "TestZonedDAO");
        assertEq(proxy.creator(), owner);
        assertEq(proxy.flavor(), "Zoned");
        assertEq(proxy.nzones(), 6);
        assertTrue(proxy.isZonedMember("creator_123"));
    }

    function testCannotReinitialize() public {
        vm.expectRevert();
        proxy.initialize("user_456", owner, "NewName", 5);
    }

    // ============================================
    // MEMBER MANAGEMENT TESTS
    // ============================================

    function testAddMember() public {
        proxy.addMember("sender_123", "user_1");
        assertEq(proxy.getSize(), 2); // creator + new user
        assertTrue(proxy.isZonedMember("user_1"));
        assertEq(proxy.zone("user_1"), 0); // Added to zone 0
    }

    function testAddMultipleMembers() public {
        string[] memory userIds = new string[](3);
        userIds[0] = "user_1";
        userIds[1] = "user_2";
        userIds[2] = "user_3";

        proxy.addMembers("sender_123", userIds);

        assertEq(proxy.getSize(), 4); // creator + 3 users
        assertTrue(proxy.isZonedMember("user_1"));
        assertTrue(proxy.isZonedMember("user_2"));
        assertTrue(proxy.isZonedMember("user_3"));
    }

    function testAddMemberIdempotent() public {
        proxy.addMember("sender_123", "user_1");
        uint256 sizeBefore = proxy.getSize();

        // Add same member again - should be idempotent
        proxy.addMember("sender_123", "user_1");

        assertEq(proxy.getSize(), sizeBefore);
    }

    function testAddFederationMember() public {
        vm.prank(owner);
        proxy.addFederationMember("federation_1");

        assertTrue(proxy.isZonedMember("federation_1"));
        assertEq(proxy.zone("federation_1"), 0);
    }

    // ============================================
    // ZONE MANAGEMENT TESTS
    // ============================================

    function testAddToZone() public {
        proxy.addMember("sender_123", "user_1");

        proxy.addToZone("sender_123", "user_1", 3);

        assertEq(proxy.zone("user_1"), 3);

        // Verify user is in zone 3 members
        string[] memory zone3Members = proxy.getZoneMembers(3);
        assertEq(zone3Members.length, 1);
        assertEq(zone3Members[0], "user_1");
    }

    function testAddToZoneMovesFromPreviousZone() public {
        proxy.addMember("sender_123", "user_1");
        proxy.addToZone("sender_123", "user_1", 2);

        // Verify in zone 2
        string[] memory zone2Members = proxy.getZoneMembers(2);
        assertEq(zone2Members.length, 1);

        // Move to zone 4
        proxy.addToZone("sender_123", "user_1", 4);

        // Verify removed from zone 2
        zone2Members = proxy.getZoneMembers(2);
        assertEq(zone2Members.length, 0);

        // Verify in zone 4
        string[] memory zone4Members = proxy.getZoneMembers(4);
        assertEq(zone4Members.length, 1);
        assertEq(zone4Members[0], "user_1");
    }

    function testRemoveFromZone() public {
        proxy.addMember("sender_123", "user_1");
        proxy.addToZone("sender_123", "user_1", 3);

        proxy.removeFromZone("sender_123", "user_1");

        assertFalse(proxy.isZonedMember("user_1"));
        assertEq(proxy.zone("user_1"), 0);

        string[] memory zone3Members = proxy.getZoneMembers(3);
        assertEq(zone3Members.length, 0);
    }

    // ============================================
    // REWARD FUNCTION TESTS
    // ============================================

    function testSetRewardFunction() public {
        proxy.setRewardFunction("creator_123", 1, 2, 3);

        assertEq(proxy.a(), 1);
        assertEq(proxy.b(), 2);
        assertEq(proxy.c(), 3);

        // Verify rewards array is populated
        uint256[] memory rewards = proxy.calculateRewards();
        assertTrue(rewards.length > 0);
    }

    function testCalculateRewards() public {
        proxy.setRewardFunction("creator_123", 0, 0, 1);

        uint256[] memory rewards = proxy.calculateRewards();

        // With a=0, b=0, c=1, all zones get equal weight
        // After normalization, each should get proportional share
        assertTrue(rewards.length == 6);
    }

    function testCalculateRewardsQuadratic() public {
        proxy.setRewardFunction("creator_123", 1, 0, 0);

        uint256[] memory rewards = proxy.calculateRewards();

        // Zone 0: 0*0 = 0
        // Zone 1: 1*1 = 1
        // Zone 2: 2*2 = 4
        // Zone 3: 3*3 = 9
        // etc.

        // Higher zones should have higher rewards
        assertTrue(rewards[3] > rewards[2]);
        assertTrue(rewards[2] > rewards[1]);
    }

    // ============================================
    // ETH REWARD DISTRIBUTION TESTS
    // ============================================

    function testRewardDistributionETH() public {
        // Add members to different zones
        proxy.addMember("sender_123", "user_1");
        proxy.addMember("sender_123", "user_2");
        proxy.addMember("sender_123", "user_3");

        proxy.addToZone("sender_123", "user_1", 1);
        proxy.addToZone("sender_123", "user_2", 2);
        proxy.addToZone("sender_123", "user_3", 3);

        // Users claim addresses
        proxy.claim("user_1", user1);
        proxy.claim("user_2", user2);
        proxy.claim("user_3", user3);

        // Set reward function (equal distribution for simplicity)
        proxy.setRewardFunction("creator_123", 0, 0, 1);

        // Send ETH and trigger reward
        uint256 amount = 3 ether;
        (bool success, ) = address(proxy).call{value: amount}("");
        assertTrue(success);

        // All should have received some ETH
        assertTrue(user1.balance > 10 ether);
        assertTrue(user2.balance > 10 ether);
        assertTrue(user3.balance > 10 ether);
    }

    function testRewardDistributionETHQuadratic() public {
        // Add members to different zones
        proxy.addMember("sender_123", "user_1");
        proxy.addMember("sender_123", "user_2");

        proxy.addToZone("sender_123", "user_1", 1);
        proxy.addToZone("sender_123", "user_2", 3);  // Higher zone

        proxy.claim("user_1", user1);
        proxy.claim("user_2", user2);

        // Set quadratic reward function
        proxy.setRewardFunction("creator_123", 1, 0, 0);

        uint256 balanceBefore1 = user1.balance;
        uint256 balanceBefore2 = user2.balance;

        // Distribute
        (bool success, ) = address(proxy).call{value: 1 ether}("");
        assertTrue(success);

        uint256 received1 = user1.balance - balanceBefore1;
        uint256 received2 = user2.balance - balanceBefore2;

        // User in zone 3 should receive more than user in zone 1
        assertTrue(received2 > received1);
    }

    // ============================================
    // ERC20 REWARD DISTRIBUTION TESTS
    // ============================================

    function testRewardDistributionERC20() public {
        proxy.addMember("sender_123", "user_1");
        proxy.addMember("sender_123", "user_2");

        proxy.addToZone("sender_123", "user_1", 1);
        proxy.addToZone("sender_123", "user_2", 2);

        proxy.claim("user_1", user1);
        proxy.claim("user_2", user2);

        proxy.setRewardFunction("creator_123", 0, 0, 1);

        uint256 amount = 1000 * 10**18;
        proxy.reward(address(token), amount);

        assertTrue(token.balanceOf(user1) > 0);
        assertTrue(token.balanceOf(user2) > 0);
    }

    // ============================================
    // CLAIM FUNCTIONALITY TESTS
    // ============================================

    function testClaim() public {
        proxy.addMember("sender_123", "user_1");

        // Deposit some ETH for user
        proxy.depositEtherForUser{value: 1 ether}("user_1", 1 ether);

        uint256 balanceBefore = user1.balance;

        // Claim
        proxy.claim("user_1", user1);

        assertEq(user1.balance, balanceBefore + 1 ether);
        assertTrue(proxy.hasClaimed("user_1"));
        assertEq(proxy.userIdToAddress("user_1"), user1);
    }

    function testCannotClaimTwice() public {
        proxy.addMember("sender_123", "user_1");
        proxy.depositEtherForUser{value: 1 ether}("user_1", 1 ether);

        proxy.claim("user_1", user1);

        vm.expectRevert("User has already claimed");
        proxy.claim("user_1", user1);
    }

    function testClaimTokens() public {
        proxy.addMember("sender_123", "user_1");

        // Deposit tokens for user
        token.transfer(address(proxy), 1000 * 10**18);
        proxy.depositTokenForUser("user_1", address(token), 1000 * 10**18);

        // Claim
        proxy.claim("user_1", user1);

        assertEq(token.balanceOf(user1), 1000 * 10**18);
    }

    // ============================================
    // UNCLAIMED REWARDS TESTS
    // ============================================

    function testRewardUnclaimedUser() public {
        proxy.addMember("sender_123", "user_1");
        proxy.addToZone("sender_123", "user_1", 1);

        // Don't claim - reward should be stored
        proxy.setRewardFunction("creator_123", 0, 0, 1);

        (bool success, ) = address(proxy).call{value: 1 ether}("");
        assertTrue(success);

        // ETH should be stored in contract
        assertTrue(proxy.etherBalance("user_1") > 0);

        // Now claim
        uint256 balanceBefore = user1.balance;
        proxy.claim("user_1", user1);
        assertTrue(user1.balance > balanceBefore);
    }

    // ============================================
    // UPGRADE TESTS
    // ============================================

    function testUpgrade() public {
        proxy.addMember("sender_123", "user_1");
        proxy.addToZone("sender_123", "user_1", 3);

        // Deploy new implementation
        ZonedUpgradeable newImplementation = new ZonedUpgradeable();

        // Perform upgrade
        proxy.upgradeToAndCall(address(newImplementation), "");

        // Verify state preserved
        assertEq(proxy.name(), "TestZonedDAO");
        assertTrue(proxy.isZonedMember("user_1"));
        assertEq(proxy.zone("user_1"), 3);
    }

    function testUpgradeOnlyOwner() public {
        ZonedUpgradeable newImplementation = new ZonedUpgradeable();

        vm.prank(attacker);
        vm.expectRevert("Only owner can perform this action");
        proxy.upgradeToAndCall(address(newImplementation), "");
    }

    // ============================================
    // SECURITY TESTS
    // ============================================

    function testCannotAddNonexistentMemberToZone() public {
        vm.expectRevert("only zone members can have their zones changed");
        proxy.addToZone("sender_123", "nonexistent_user", 3);
    }

    function testDepositEtherForUser() public {
        proxy.addMember("sender_123", "user_1");

        proxy.depositEtherForUser{value: 5 ether}("user_1", 5 ether);

        assertEq(proxy.etherBalance("user_1"), 5 ether);
    }

    function testDepositTokenForUser() public {
        proxy.addMember("sender_123", "user_1");

        proxy.depositTokenForUser("user_1", address(token), 100 * 10**18);

        assertEq(proxy.tokenBalance("user_1", address(token)), 100 * 10**18);
    }

    // ============================================
    // EDGE CASE TESTS
    // ============================================

    function testRewardWithZeroMembers() public {
        // Remove creator from zones (they start in no zone anyway)
        vm.expectRevert();
        (bool success, ) = address(proxy).call{value: 1 ether}("");
    }

    function testRewardWithSingleMember() public {
        proxy.addMember("sender_123", "user_1");
        proxy.addToZone("sender_123", "user_1", 1);
        proxy.claim("user_1", user1);

        proxy.setRewardFunction("creator_123", 0, 0, 1);

        uint256 balanceBefore = user1.balance;
        (bool success, ) = address(proxy).call{value: 1 ether}("");
        assertTrue(success);

        // Single member should get all rewards
        assertTrue(user1.balance > balanceBefore);
    }

    function testRewardRounding() public {
        proxy.addMember("sender_123", "user_1");
        proxy.addMember("sender_123", "user_2");
        proxy.addMember("sender_123", "user_3");

        proxy.addToZone("sender_123", "user_1", 1);
        proxy.addToZone("sender_123", "user_2", 1);
        proxy.addToZone("sender_123", "user_3", 1);

        proxy.claim("user_1", user1);
        proxy.claim("user_2", user2);
        proxy.claim("user_3", user3);

        proxy.setRewardFunction("creator_123", 0, 0, 1);

        // Send amount not evenly divisible
        (bool success, ) = address(proxy).call{value: 1 ether + 1 wei}("");
        assertTrue(success);

        // Check that all received something (rounding might cause dust loss)
        assertTrue(user1.balance > 10 ether);
        assertTrue(user2.balance > 10 ether);
        assertTrue(user3.balance > 10 ether);
    }

    receive() external payable {}
}
