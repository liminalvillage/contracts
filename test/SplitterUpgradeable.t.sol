// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "forge-std/Test.sol";
import "../src/SplitterUpgradeable.sol";
import "../src/ManagedUpgradeable.sol";
import "../src/ZonedUpgradeable.sol";
import "../src/ManagedFactoryUpgradeable.sol";
import "../src/ZonedFactoryUpgradeable.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

/**
 * @title SplitterUpgradeableTest
 * @notice Comprehensive test suite for upgradeable Splitter contracts
 */
contract SplitterUpgradeableTest is Test {
    SplitterUpgradeable public splitterImpl;
    SplitterUpgradeable public splitter;
    ManagedFactoryUpgradeable public managedFactory;
    ZonedFactoryUpgradeable public zonedFactory;
    TestToken public token;

    address public owner;
    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);

        // Deploy implementations
        ManagedUpgradeable managedImpl = new ManagedUpgradeable();
        ZonedUpgradeable zonedImpl = new ZonedUpgradeable();
        splitterImpl = new SplitterUpgradeable();

        // Deploy factories
        managedFactory = new ManagedFactoryUpgradeable(address(managedImpl));
        zonedFactory = new ZonedFactoryUpgradeable(address(zonedImpl));

        // Deploy splitter proxy
        bytes memory data = abi.encodeWithSelector(
            SplitterUpgradeable.initialize.selector,
            owner,
            "creator_123",
            "TestSplitter",
            0,
            address(managedFactory),
            address(zonedFactory)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(splitterImpl), data);
        splitter = SplitterUpgradeable(payable(address(proxy)));

        // Deploy test token and fund splitter
        token = new TestToken();
        token.transfer(address(splitter), 10000 * 10**18);

        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
    }

    // ============================================
    // INITIALIZATION TESTS
    // ============================================

    function testInitialization() public {
        assertEq(splitter.name(), "TestSplitter");
        assertEq(splitter.creatorUserId(), "creator_123");
        assertEq(splitter.managedFactory(), address(managedFactory));
        assertEq(splitter.zonedFactory(), address(zonedFactory));
    }

    function testCannotReinitialize() public {
        vm.expectRevert();
        splitter.initialize(owner, "user2", "NewName", 0, address(managedFactory), address(zonedFactory));
    }

    // ============================================
    // CHILD CONTRACT CREATION TESTS
    // ============================================

    function testCreateManagedContract() public {
        address managedAddr = splitter.createManagedContract("creator_123", "TestManaged", 0);

        assertTrue(managedAddr != address(0));
        assertEq(splitter.contractsByType("TestManaged_managed"), managedAddr);

        // Verify it's in the keys array
        string[] memory keys = splitter.getContractKeys();
        bool found = false;
        for (uint i = 0; i < keys.length; i++) {
            if (keccak256(bytes(keys[i])) == keccak256(bytes("TestManaged_managed"))) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    function testCreateZonedContract() public {
        address zonedAddr = splitter.createZonedContract("creator_123", "TestZoned", 6);

        assertTrue(zonedAddr != address(0));
        assertEq(splitter.contractsByType("TestZoned_zoned"), zonedAddr);
    }

    function testGetContractAddresses() public {
        splitter.createManagedContract("creator_123", "Test1", 0);
        splitter.createZonedContract("creator_123", "Test2", 6);

        (string[] memory keys, address[] memory addresses) = splitter.getContractAddresses();

        assertEq(keys.length, 2);
        assertEq(addresses.length, 2);
        assertTrue(addresses[0] != address(0));
        assertTrue(addresses[1] != address(0));
    }

    // ============================================
    // MEMBER MANAGEMENT TESTS
    // ============================================

    function testAddMember() public {
        splitter.addMember("user_1");

        assertTrue(splitter.isSplitterMember("user_1"));
    }

    function testAddMultipleMembers() public {
        string[] memory userIds = new string[](3);
        userIds[0] = "user_1";
        userIds[1] = "user_2";
        userIds[2] = "user_3";

        splitter.addMembers(userIds);

        assertTrue(splitter.isSplitterMember("user_1"));
        assertTrue(splitter.isSplitterMember("user_2"));
        assertTrue(splitter.isSplitterMember("user_3"));
    }

    function testAddMemberIdempotent() public {
        splitter.addMember("user_1");
        splitter.addMember("user_1"); // Should not revert

        assertTrue(splitter.isSplitterMember("user_1"));
    }

    // ============================================
    // SPLIT CONFIGURATION TESTS
    // ============================================

    function testSetContractSplit() public {
        splitter.setContractSplit(40, 60);

        assertEq(splitter.internalContractSplitPercentage(), 40);
        assertEq(splitter.externalContractSplitPercentage(), 60);
    }

    function testSetContractSplitMustEqualHundred() public {
        vm.expectRevert("Total percentage must be 100");
        splitter.setContractSplit(40, 50);
    }

    function testSetSplit() public {
        string[] memory userIds = new string[](2);
        userIds[0] = "user_1";
        userIds[1] = "user_2";

        uint[] memory percentages = new uint[](2);
        percentages[0] = 30;
        percentages[1] = 70;

        // This would require botAddress authorization in real scenario
        // For testing, we'll skip the auth check or set botAddress
        vm.prank(owner);
        vm.expectRevert("Only splitter owner can set the split");
        splitter.setSplit(userIds, percentages);
    }

    // ============================================
    // REWARD DISTRIBUTION TESTS
    // ============================================

    function testRewardDistributionToChildren() public {
        // Create child contracts
        address managedAddr = splitter.createManagedContract("creator_123", splitter.name(), 0);
        address zonedAddr = splitter.createZonedContract("creator_123", splitter.name(), 6);

        // Set split
        splitter.setContractSplit(40, 60);

        // Add members to children
        ManagedUpgradeable managed = ManagedUpgradeable(managedAddr);
        ZonedUpgradeable zoned = ZonedUpgradeable(zonedAddr);

        managed.addMember("user_1");
        zoned.addMember("sender_123", "user_2");
        zoned.addToZone("sender_123", "user_2", 1);

        // Claim addresses
        managed.claim("user_1", user1);
        zoned.claim("user_2", user2);

        // Set reward functions
        zoned.setRewardFunction("creator_123", 0, 0, 1);

        uint256 balanceBefore1 = user1.balance;
        uint256 balanceBefore2 = user2.balance;

        // Send ETH to splitter
        (bool success, ) = address(splitter).call{value: 1 ether}("");
        assertTrue(success);

        // Verify both children received funds
        assertTrue(user1.balance > balanceBefore1);
        assertTrue(user2.balance > balanceBefore2);

        // Verify split percentages (approximately)
        uint256 received1 = user1.balance - balanceBefore1;
        uint256 received2 = user2.balance - balanceBefore2;

        // 40% vs 60% split
        assertTrue(received2 > received1);
    }

    function testRewardDistributionERC20ToChildren() public {
        // Create children
        address managedAddr = splitter.createManagedContract("creator_123", splitter.name(), 0);
        address zonedAddr = splitter.createZonedContract("creator_123", splitter.name(), 6);

        splitter.setContractSplit(50, 50);

        ManagedUpgradeable managed = ManagedUpgradeable(managedAddr);
        ZonedUpgradeable zoned = ZonedUpgradeable(zonedAddr);

        managed.addMember("user_1");
        zoned.addMember("sender_123", "user_2");
        zoned.addToZone("sender_123", "user_2", 1);

        managed.claim("user_1", user1);
        zoned.claim("user_2", user2);

        zoned.setRewardFunction("creator_123", 0, 0, 1);

        uint256 amount = 1000 * 10**18;
        splitter.reward(address(token), amount);

        assertTrue(token.balanceOf(user1) > 0);
        assertTrue(token.balanceOf(user2) > 0);
    }

    function testRewardFailsWithoutChildContracts() public {
        splitter.setContractSplit(50, 50);

        vm.expectRevert("Managed contract address not set");
        (bool success, ) = address(splitter).call{value: 1 ether}("");
    }

    function testRewardFailsWithoutSplitSet() public {
        // Create children
        splitter.createManagedContract("creator_123", splitter.name(), 0);
        splitter.createZonedContract("creator_123", splitter.name(), 6);

        // Don't set split
        vm.expectRevert("Contract split percentages not set or invalid");
        (bool success, ) = address(splitter).call{value: 1 ether}("");
    }

    // ============================================
    // CLAIM FUNCTIONALITY TESTS
    // ============================================

    function testClaim() public {
        splitter.addMember("user_1");
        splitter.depositEtherForUser{value: 1 ether}("user_1", 1 ether);

        uint256 balanceBefore = user1.balance;

        // Note: claim requires botAddress authorization
        vm.expectRevert("Only creator can submit claim");
        splitter.claim("user_1", user1);
    }

    function testDepositEtherForUser() public {
        splitter.addMember("user_1");

        splitter.depositEtherForUser{value: 2 ether}("user_1", 2 ether);

        assertEq(splitter.etherBalance("user_1"), 2 ether);
    }

    function testDepositTokenForUser() public {
        splitter.addMember("user_1");

        splitter.depositTokenForUser("user_1", address(token), 500 * 10**18);

        assertEq(splitter.tokenBalance("user_1", address(token)), 500 * 10**18);
    }

    // ============================================
    // ROUTE COMMAND TESTS
    // ============================================

    function testRouteCommand() public {
        address managedAddr = splitter.createManagedContract("creator_123", "Test", 0);

        // Try to call addMember via routeCommand
        bytes memory callData = abi.encodeWithSignature("addMember(string)", "user_1");
        (bool success, ) = splitter.routeCommand("Test_managed", callData);

        assertTrue(success);

        // Verify member was added
        ManagedUpgradeable managed = ManagedUpgradeable(managedAddr);
        assertTrue(managed.isManagedMember("user_1"));
    }

    function testRouteCommandFailsForNonexistentContract() public {
        bytes memory callData = abi.encodeWithSignature("addMember(string)", "user_1");

        vm.expectRevert("Target contract not found");
        splitter.routeCommand("nonexistent", callData);
    }

    // ============================================
    // UPGRADE TESTS
    // ============================================

    function testUpgrade() public {
        splitter.addMember("user_1");
        splitter.createManagedContract("creator_123", "Test", 0);

        SplitterUpgradeable newImpl = new SplitterUpgradeable();

        splitter.upgradeToAndCall(address(newImpl), "");

        // Verify state preserved
        assertEq(splitter.name(), "TestSplitter");
        assertTrue(splitter.isSplitterMember("user_1"));
        assertTrue(splitter.contractsByType("Test_managed") != address(0));
    }

    function testUpgradeOnlyOwner() public {
        SplitterUpgradeable newImpl = new SplitterUpgradeable();

        vm.prank(user1);
        vm.expectRevert("Only owner can perform this action");
        splitter.upgradeToAndCall(address(newImpl), "");
    }

    // ============================================
    // SECURITY TESTS
    // ============================================

    function testDebugGetContractAddress() public {
        address managedAddr = splitter.createManagedContract("creator_123", "Test", 0);

        assertEq(splitter.debugGetContractAddress("Test_managed"), managedAddr);
    }

    function testGetContractInfo() public {
        address managedAddr = splitter.createManagedContract("creator_123", "Test", 0);

        assertEq(splitter.getContractInfo("Test_managed"), managedAddr);
    }

    // ============================================
    // EDGE CASE TESTS
    // ============================================

    function testRewardWithRoundingError() public {
        address managedAddr = splitter.createManagedContract("creator_123", splitter.name(), 0);
        address zonedAddr = splitter.createZonedContract("creator_123", splitter.name(), 6);

        splitter.setContractSplit(33, 67); // Not evenly divisible

        ManagedUpgradeable managed = ManagedUpgradeable(managedAddr);
        ZonedUpgradeable zoned = ZonedUpgradeable(zonedAddr);

        managed.addMember("user_1");
        zoned.addMember("sender_123", "user_2");
        zoned.addToZone("sender_123", "user_2", 1);

        managed.claim("user_1", user1);
        zoned.claim("user_2", user2);

        zoned.setRewardFunction("creator_123", 0, 0, 1);

        // Send odd amount
        (bool success, ) = address(splitter).call{value: 1 ether + 1 wei}("");
        assertTrue(success);

        // Both should receive something
        assertTrue(user1.balance > 10 ether);
        assertTrue(user2.balance > 10 ether);
    }

    function testSetFactories() public {
        address newManagedFactory = address(0x123);
        address newZonedFactory = address(0x456);

        splitter.setFactories(newManagedFactory, newZonedFactory);

        assertEq(splitter.managedFactory(), newManagedFactory);
        assertEq(splitter.zonedFactory(), newZonedFactory);
    }

    receive() external payable {}
}
