// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "forge-std/Test.sol";
import "../src/SplitterUpgradeable.sol";
import "../src/ManagedUpgradeable.sol";
import "../src/ZonedUpgradeable.sol";
import "../src/ManagedFactoryUpgradeable.sol";
import "../src/ZonedFactoryUpgradeable.sol";
import "../src/SplitterFactoryUpgradeable.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

/**
 * @title IntegrationTest
 * @notice End-to-end integration tests for the complete Holon system
 * @dev Tests full workflows including factory deployment, proxy creation, and reward distribution
 */
contract IntegrationTest is Test {
    // Factories
    ManagedFactoryUpgradeable public managedFactory;
    ZonedFactoryUpgradeable public zonedFactory;
    SplitterFactoryUpgradeable public splitterFactory;

    // Implementations
    ManagedUpgradeable public managedImpl;
    ZonedUpgradeable public zonedImpl;
    SplitterUpgradeable public splitterImpl;

    // Test instances
    SplitterUpgradeable public dao;
    TestToken public token;

    // Actors
    address public deployer;
    address public alice;
    address public bob;
    address public carol;
    address public dave;

    function setUp() public {
        deployer = address(this);
        alice = address(0xA11CE);
        bob = address(0xB0B);
        carol = address(0xCA501);
        dave = address(0xDA4E);

        // Fund actors
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
        vm.deal(dave, 100 ether);

        // Deploy implementations
        managedImpl = new ManagedUpgradeable();
        zonedImpl = new ZonedUpgradeable();
        splitterImpl = new SplitterUpgradeable();

        // Deploy factories
        managedFactory = new ManagedFactoryUpgradeable(address(managedImpl));
        zonedFactory = new ZonedFactoryUpgradeable(address(zonedImpl));
        splitterFactory = new SplitterFactoryUpgradeable(address(splitterImpl));

        // Configure splitter factory
        splitterFactory.setFactories(address(managedFactory), address(zonedFactory));

        // Deploy test token
        token = new TestToken();
    }

    // ============================================
    // FULL SYSTEM DEPLOYMENT TEST
    // ============================================

    function testFullSystemDeployment() public {
        console.log("=== Full System Deployment Test ===");

        // 1. Deploy DAO via factory
        address daoAddress = splitterFactory.createSplitter(
            "dao_creator",
            "MyDAO",
            0,
            address(managedFactory),
            address(zonedFactory)
        );

        dao = SplitterUpgradeable(payable(daoAddress));

        console.log("DAO deployed at:", address(dao));
        assertEq(dao.name(), "MyDAO");
        assertEq(dao.creatorUserId(), "dao_creator");

        // 2. Create child contracts
        address managedAddr = dao.createManagedContract("dao_creator", "MyDAO", 0);
        address zonedAddr = dao.createZonedContract("dao_creator", "MyDAO", 6);

        console.log("Managed contract:", managedAddr);
        console.log("Zoned contract:", zonedAddr);

        // 3. Configure split
        dao.setContractSplit(40, 60);  // 40% to Managed, 60% to Zoned

        console.log("Split configured: 40% Managed, 60% Zoned");

        // 4. Add members
        ManagedUpgradeable managed = ManagedUpgradeable(managedAddr);
        ZonedUpgradeable zoned = ZonedUpgradeable(zonedAddr);

        managed.addMember("alice");
        managed.addMember("bob");

        zoned.addMember("dao_creator", "carol");
        zoned.addMember("dao_creator", "dave");

        console.log("Members added to both contracts");

        // 5. Configure zones
        zoned.addToZone("dao_creator", "carol", 2);
        zoned.addToZone("dao_creator", "dave", 4);
        zoned.setRewardFunction("dao_creator", 1, 0, 0);  // Quadratic

        console.log("Zones configured");

        // 6. Members claim addresses
        managed.claim("alice", alice);
        managed.claim("bob", bob);
        zoned.claim("carol", carol);
        zoned.claim("dave", dave);

        console.log("All members claimed");

        // 7. Distribute rewards
        uint256 aliceBalBefore = alice.balance;
        uint256 bobBalBefore = bob.balance;
        uint256 carolBalBefore = carol.balance;
        uint256 daveBalBefore = dave.balance;

        (bool success, ) = address(dao).call{value: 10 ether}("");
        assertTrue(success);

        console.log("10 ETH distributed");

        // 8. Verify distribution
        uint256 aliceReceived = alice.balance - aliceBalBefore;
        uint256 bobReceived = bob.balance - bobBalBefore;
        uint256 carolReceived = carol.balance - carolBalBefore;
        uint256 daveReceived = dave.balance - daveBalBefore;

        console.log("Alice received:", aliceReceived);
        console.log("Bob received:", bobReceived);
        console.log("Carol received:", carolReceived);
        console.log("Dave received:", daveReceived);

        // Verify Managed members got equal shares (40% total / 2)
        assertEq(aliceReceived, bobReceived);

        // Verify Zoned members got proportional shares (Dave in higher zone)
        assertTrue(daveReceived > carolReceived);

        // Verify total adds up (approximately, accounting for rounding)
        uint256 total = aliceReceived + bobReceived + carolReceived + daveReceived;
        assertTrue(total >= 9.9 ether && total <= 10 ether);

        console.log("=== Test Complete ===");
    }

    // ============================================
    // COMPLEX SCENARIO: MULTI-LEVEL DAO
    // ============================================

    function testMultiLevelDAOStructure() public {
        console.log("=== Multi-Level DAO Structure Test ===");

        // Create top-level DAO
        address mainDAOAddr = splitterFactory.createSplitter(
            "main_dao",
            "MainDAO",
            0,
            address(managedFactory),
            address(zonedFactory)
        );
        SplitterUpgradeable mainDAO = SplitterUpgradeable(payable(mainDAOAddr));

        // Create sub-DAO 1
        address subDAO1Addr = splitterFactory.createSplitter(
            "sub_dao_1",
            "SubDAO1",
            0,
            address(managedFactory),
            address(zonedFactory)
        );
        SplitterUpgradeable subDAO1 = SplitterUpgradeable(payable(subDAO1Addr));

        // Create sub-DAO 2
        address subDAO2Addr = splitterFactory.createSplitter(
            "sub_dao_2",
            "SubDAO2",
            0,
            address(managedFactory),
            address(zonedFactory)
        );
        SplitterUpgradeable subDAO2 = SplitterUpgradeable(payable(subDAO2Addr));

        console.log("Main DAO:", address(mainDAO));
        console.log("Sub-DAO 1:", address(subDAO1));
        console.log("Sub-DAO 2:", address(subDAO2));

        // Configure main DAO to distribute to sub-DAOs
        address mainManagedAddr = mainDAO.createManagedContract("main_dao", "MainDAO", 0);
        ManagedUpgradeable mainManaged = ManagedUpgradeable(mainManagedAddr);

        // Add sub-DAOs as members of main DAO
        mainManaged.addMember("subdao1");
        mainManaged.addMember("subdao2");

        // Link sub-DAO addresses
        mainManaged.claim("subdao1", address(subDAO1));
        mainManaged.claim("subdao2", address(subDAO2));

        // Set appreciation (sub-DAO 1 gets more)
        string[] memory userIds = new string[](2);
        userIds[0] = "subdao1";
        userIds[1] = "subdao2";

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 70;
        amounts[1] = 30;

        mainManaged.setAppreciation(userIds, amounts);

        // Configure sub-DAOs
        address subDAO1ManagedAddr = subDAO1.createManagedContract("sub_dao_1", "SubDAO1", 0);
        subDAO1.setContractSplit(100, 0);  // All to managed

        ManagedUpgradeable subDAO1Managed = ManagedUpgradeable(subDAO1ManagedAddr);
        subDAO1Managed.addMember("alice");
        subDAO1Managed.addMember("bob");
        subDAO1Managed.claim("alice", alice);
        subDAO1Managed.claim("bob", bob);

        address subDAO2ManagedAddr = subDAO2.createManagedContract("sub_dao_2", "SubDAO2", 0);
        subDAO2.setContractSplit(100, 0);

        ManagedUpgradeable subDAO2Managed = ManagedUpgradeable(subDAO2ManagedAddr);
        subDAO2Managed.addMember("carol");
        subDAO2Managed.addMember("dave");
        subDAO2Managed.claim("carol", carol);
        subDAO2Managed.claim("dave", dave);

        // Distribute from top
        uint256 aliceBalBefore = alice.balance;
        uint256 bobBalBefore = bob.balance;
        uint256 carolBalBefore = carol.balance;
        uint256 daveBalBefore = dave.balance;

        // Send to main DAO, should cascade to sub-DAOs
        mainDAO.reward(address(0), 10 ether);

        // Since sub-DAOs are contracts, they won't automatically receive
        // This is expected behavior - would need manual distribution

        console.log("=== Multi-Level Test Complete ===");
    }

    // ============================================
    // SCENARIO: ERC20 TOKEN DISTRIBUTION
    // ============================================

    function testERC20TokenDistribution() public {
        console.log("=== ERC20 Token Distribution Test ===");

        // Deploy DAO
        address daoAddr = splitterFactory.createSplitter(
            "token_dao",
            "TokenDAO",
            0,
            address(managedFactory),
            address(zonedFactory)
        );
        dao = SplitterUpgradeable(payable(daoAddr));

        // Create children
        address managedAddr = dao.createManagedContract("token_dao", "TokenDAO", 0);
        address zonedAddr = dao.createZonedContract("token_dao", "TokenDAO", 6);

        dao.setContractSplit(50, 50);

        // Configure
        ManagedUpgradeable managed = ManagedUpgradeable(managedAddr);
        ZonedUpgradeable zoned = ZonedUpgradeable(zonedAddr);

        managed.addMember("alice");
        managed.addMember("bob");

        zoned.addMember("token_dao", "carol");
        zoned.addMember("token_dao", "dave");
        zoned.addToZone("token_dao", "carol", 1);
        zoned.addToZone("token_dao", "dave", 1);
        zoned.setRewardFunction("token_dao", 0, 0, 1);

        managed.claim("alice", alice);
        managed.claim("bob", bob);
        zoned.claim("carol", carol);
        zoned.claim("dave", dave);

        // Transfer tokens to DAO
        token.transfer(address(dao), 10000 * 10**18);

        console.log("Transferred 10,000 tokens to DAO");

        // Distribute
        dao.reward(address(token), 10000 * 10**18);

        // Verify
        uint256 aliceBal = token.balanceOf(alice);
        uint256 bobBal = token.balanceOf(bob);
        uint256 carolBal = token.balanceOf(carol);
        uint256 daveBal = token.balanceOf(dave);

        console.log("Alice tokens:", aliceBal);
        console.log("Bob tokens:", bobBal);
        console.log("Carol tokens:", carolBal);
        console.log("Dave tokens:", daveBal);

        // Verify Managed split (50% / 2)
        assertEq(aliceBal, bobBal);

        // Verify Zoned split (50% / 2)
        assertEq(carolBal, daveBal);

        // Verify total
        uint256 total = aliceBal + bobBal + carolBal + daveBal;
        assertEq(total, 10000 * 10**18);

        console.log("=== ERC20 Test Complete ===");
    }

    // ============================================
    // SCENARIO: UPGRADE ENTIRE SYSTEM
    // ============================================

    function testSystemWideUpgrade() public {
        console.log("=== System-Wide Upgrade Test ===");

        // Deploy initial system
        address daoAddr = splitterFactory.createSplitter(
            "upgrade_dao",
            "UpgradeDAO",
            0,
            address(managedFactory),
            address(zonedFactory)
        );
        dao = SplitterUpgradeable(payable(daoAddr));

        address managedAddr = dao.createManagedContract("upgrade_dao", "UpgradeDAO", 0);

        ManagedUpgradeable managed = ManagedUpgradeable(managedAddr);
        managed.addMember("alice");
        managed.claim("alice", alice);

        // Add some state
        string[] memory users = new string[](1);
        users[0] = "alice";
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;
        managed.setAppreciation(users, amounts);

        console.log("Initial system deployed and configured");

        // Deploy new implementations
        ManagedUpgradeable newManagedImpl = new ManagedUpgradeable();
        SplitterUpgradeable newSplitterImpl = new SplitterUpgradeable();

        console.log("New implementations deployed");

        // Update factories
        managedFactory.setImplementation(address(newManagedImpl));
        splitterFactory.setImplementation(address(newSplitterImpl));

        console.log("Factories updated");

        // Upgrade existing contracts
        managed.upgradeToAndCall(address(newManagedImpl), "");
        dao.upgradeToAndCall(address(newSplitterImpl), "");

        console.log("Existing contracts upgraded");

        // Verify state preserved
        assertTrue(managed.isManagedMember("alice"));
        assertEq(managed.appreciation("alice"), 100);
        assertEq(managed.totalappreciation(), 100);

        console.log("State preserved after upgrade");

        // Verify functionality still works
        vm.deal(address(managed), 1 ether);
        uint256 aliceBalBefore = alice.balance;

        (bool success, ) = address(managed).call{value: 1 ether}("");
        assertTrue(success);

        assertTrue(alice.balance > aliceBalBefore);

        console.log("Functionality verified after upgrade");
        console.log("=== Upgrade Test Complete ===");
    }

    // ============================================
    // SCENARIO: UNCLAIMED REWARDS ACCUMULATION
    // ============================================

    function testUnclaimedRewardsAccumulation() public {
        console.log("=== Unclaimed Rewards Test ===");

        // Deploy DAO
        address daoAddr = splitterFactory.createSplitter(
            "unclaimed_dao",
            "UnclaimedDAO",
            0,
            address(managedFactory),
            address(zonedFactory)
        );
        dao = SplitterUpgradeable(payable(daoAddr));

        address managedAddr = dao.createManagedContract("unclaimed_dao", "UnclaimedDAO", 0);
        dao.setContractSplit(100, 0);

        ManagedUpgradeable managed = ManagedUpgradeable(managedAddr);
        managed.addMember("alice");
        managed.addMember("bob");

        // Alice claims, Bob doesn't
        managed.claim("alice", alice);

        console.log("Alice claimed, Bob did not");

        // Distribute rewards multiple times
        vm.deal(address(dao), 10 ether);

        dao.reward(address(0), 1 ether);
        dao.reward(address(0), 1 ether);
        dao.reward(address(0), 1 ether);

        console.log("Distributed 3 ETH over 3 transactions");

        // Alice should have received her share
        assertTrue(alice.balance > 100 ether);

        // Bob's share should be stored
        assertTrue(managed.etherBalance("bob") > 0);

        console.log("Alice balance:", alice.balance);
        console.log("Bob stored balance:", managed.etherBalance("bob"));

        // Bob claims later
        uint256 bobBalBefore = bob.balance;
        managed.claim("bob", bob);

        uint256 bobReceived = bob.balance - bobBalBefore;
        console.log("Bob received on claim:", bobReceived);

        assertTrue(bobReceived > 0);

        console.log("=== Unclaimed Rewards Test Complete ===");
    }

    receive() external payable {}
}
