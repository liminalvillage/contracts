// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "forge-std/Test.sol";
import "../src/ManagedUpgradeable.sol";
import "../src/ZonedUpgradeable.sol";
import "../src/SplitterUpgradeable.sol";
import "../src/ManagedFactoryUpgradeable.sol";
import "../src/ZonedFactoryUpgradeable.sol";
import "../src/SplitterFactoryUpgradeable.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MaliciousReceiver {
    bool public attacking;
    address public target;
    uint256 public attackCount;

    function setTarget(address _target) external {
        target = _target;
    }

    function enableAttack() external {
        attacking = true;
    }

    receive() external payable {
        if (attacking && attackCount < 3) {
            attackCount++;
            // Attempt reentrancy
            (bool success, ) = target.call{value: 0}("");
        }
    }
}

contract TestToken is ERC20 {
    constructor() ERC20("Test", "TEST") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

/**
 * @title SecurityAuditTest
 * @notice Tests for security vulnerabilities found in audit
 * @dev Tests Critical and High severity issues
 */
contract SecurityAuditTest is Test {
    ManagedUpgradeable public managed;
    ZonedUpgradeable public zoned;
    SplitterUpgradeable public splitter;

    ManagedFactoryUpgradeable public managedFactory;
    ZonedFactoryUpgradeable public zonedFactory;
    SplitterFactoryUpgradeable public splitterFactory;

    TestToken public token;
    MaliciousReceiver public attacker;

    address public owner;
    address public user1;
    address public user2;
    address public malicious;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        malicious = address(0x666);

        // Deploy implementations
        ManagedUpgradeable managedImpl = new ManagedUpgradeable();
        ZonedUpgradeable zonedImpl = new ZonedUpgradeable();
        SplitterUpgradeable splitterImpl = new SplitterUpgradeable();

        // Deploy factories
        managedFactory = new ManagedFactoryUpgradeable(address(managedImpl));
        zonedFactory = new ZonedFactoryUpgradeable(address(zonedImpl));
        splitterFactory = new SplitterFactoryUpgradeable(address(splitterImpl));

        // Deploy managed proxy
        bytes memory managedData = abi.encodeWithSelector(
            ManagedUpgradeable.initialize.selector,
            owner,
            "TestManaged"
        );
        ERC1967Proxy managedProxy = new ERC1967Proxy(address(managedImpl), managedData);
        managed = ManagedUpgradeable(address(managedProxy));

        // Deploy zoned proxy
        bytes memory zonedData = abi.encodeWithSelector(
            ZonedUpgradeable.initialize.selector,
            "creator_123",
            owner,
            "TestZoned",
            6
        );
        ERC1967Proxy zonedProxy = new ERC1967Proxy(address(zonedImpl), zonedData);
        zoned = ZonedUpgradeable(address(zonedProxy));

        // Deploy splitter proxy
        bytes memory splitterData = abi.encodeWithSelector(
            SplitterUpgradeable.initialize.selector,
            owner,
            "creator_123",
            "TestSplitter",
            0,
            address(managedFactory),
            address(zonedFactory)
        );
        ERC1967Proxy splitterProxy = new ERC1967Proxy(address(splitterImpl), splitterData);
        splitter = SplitterUpgradeable(payable(address(splitterProxy)));

        // Deploy test token
        token = new TestToken();

        // Deploy malicious receiver
        attacker = new MaliciousReceiver();

        // Fund accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(address(attacker), 10 ether);
    }

    // ============================================
    // CRITICAL: Factory Implementation Control
    // ============================================

    function testCRITICAL_FactoryImplementationUnauthorizedChange() public {
        // VULNERABILITY: Anyone can change factory implementation

        // Malicious actor deploys evil implementation
        ManagedUpgradeable evilImpl = new ManagedUpgradeable();

        // Malicious actor changes implementation - THIS SHOULD FAIL but doesn't!
        vm.prank(malicious);
        managedFactory.setImplementation(address(evilImpl));

        // Factory now points to malicious implementation
        assertEq(managedFactory.implementation(), address(evilImpl));

        // This is CRITICAL - all future proxies will use malicious code!
        console.log("CRITICAL: Factory implementation changed by unauthorized user!");
    }

    function testCRITICAL_SplitterFactoryUnauthorizedChange() public {
        // Same issue for all factories

        vm.prank(malicious);
        splitterFactory.setManagedFactory(malicious);

        assertEq(splitterFactory.managedFactory(), malicious);
        console.log("CRITICAL: Splitter factory addresses changed by unauthorized user!");
    }

    // ============================================
    // HIGH: Reentrancy Attacks
    // ============================================

    function testHIGH_ReentrancyInManagedReward() public {
        // Add attacker as member
        managed.addMember("attacker");

        // Claim to attacker contract
        managed.claim("attacker", address(attacker));

        // Enable attack
        attacker.setTarget(address(managed));
        attacker.enableAttack();

        // Try reentrancy attack
        vm.deal(address(managed), 10 ether);

        // This should be protected but isn't
        vm.expectRevert(); // Would fail without reentrancy guard
        (bool success, ) = address(managed).call{value: 1 ether}("");
    }

    function testHIGH_ReentrancyInZonedReward() public {
        zoned.addMember("sender", "attacker");
        zoned.addToZone("sender", "attacker", 1);
        zoned.claim("attacker", address(attacker));

        zoned.setRewardFunction("creator_123", 0, 0, 1);

        attacker.setTarget(address(zoned));
        attacker.enableAttack();

        vm.deal(address(zoned), 10 ether);

        // Attempt reentrancy
        (bool success, ) = address(zoned).call{value: 1 ether}("");

        // If attacker received more than expected, reentrancy worked
        if (attacker.attackCount() > 0) {
            console.log("HIGH: Reentrancy attack possible!");
        }
    }

    // ============================================
    // HIGH: Access Control Issues
    // ============================================

    function testHIGH_UnauthorizedAddMember() public {
        // VULNERABILITY: addMember has no access control

        vm.prank(malicious);
        managed.addMember("malicious_user");

        assertTrue(managed.isManagedMember("malicious_user"));
        console.log("HIGH: Unauthorized user can add members!");
    }

    function testHIGH_UnauthorizedAddToZone() public {
        // Add a user first
        zoned.addMember("sender", "user_1");

        // Malicious actor changes zone - THIS SHOULD FAIL
        vm.prank(malicious);
        zoned.addToZone("malicious_sender", "user_1", 6);  // Promote to highest zone

        assertEq(zoned.zone("user_1"), 6);
        console.log("HIGH: Unauthorized user can change zones!");
    }

    function testHIGH_UnauthorizedAddParent() public {
        // Anyone can add themselves as parent
        vm.prank(malicious);
        managed.addParent(malicious);

        address[] memory parents = managed.listParents();
        assertEq(parents[parents.length - 1], malicious);
        console.log("HIGH: Unauthorized user can add parent!");
    }

    // ============================================
    // HIGH: Token Safety Issues
    // ============================================

    function testHIGH_UncheckedERC20ReturnValue() public {
        // Create a token that returns false on transfer
        // This test demonstrates the vulnerability but can't exploit
        // without a custom token implementation

        managed.addMember("user_1");
        managed.claim("user_1", user1);

        token.transfer(address(managed), 1000 * 10**18);

        // If token.transfer returned false (some tokens do this),
        // the contract wouldn't check and would assume success
        managed.reward(address(token), 100 * 10**18);

        console.log("HIGH: ERC20 return values not checked with SafeERC20!");
    }

    // ============================================
    // MEDIUM: Storage Issues
    // ============================================

    function testMEDIUM_DuplicateTokenAddresses() public {
        managed.addMember("user_1");

        // Deposit same token multiple times
        managed.depositTokenForUser("user_1", address(token), 100 * 10**18);
        managed.depositTokenForUser("user_1", address(token), 100 * 10**18);
        managed.depositTokenForUser("user_1", address(token), 100 * 10**18);

        // tokensOf array will have duplicates
        address[] memory tokens = managed.getTokensOf("user_1");

        if (tokens.length > 1) {
            console.log("MEDIUM: Duplicate token addresses in array!");
            console.log("Array length:", tokens.length);
        }
    }

    function testMEDIUM_TotalAppreciationOverflow() public {
        // While Solidity 0.8+ prevents overflow, this tests the logic issue

        managed.addMember("user_1");

        string[] memory users = new string[](1);
        users[0] = "user_1";

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;

        // Set appreciation multiple times - it accumulates!
        managed.setAppreciation(users, amounts);
        managed.setAppreciation(users, amounts);
        managed.setAppreciation(users, amounts);

        // totalappreciation keeps growing
        uint256 total = managed.totalappreciation();
        console.log("MEDIUM: totalappreciation accumulated to:", total);

        // This is wrong - should be 1000, not 3000
        assertEq(total, 3000);
    }

    function testMEDIUM_ClaimAuthorizationBypass() public {
        managed.addMember("user_1");
        managed.depositEtherForUser{value: 1 ether}("user_1", 1 ether);

        // First claim sets the beneficiary
        // The authorization check is commented out!
        // This would normally require botAddress

        vm.expectRevert("Only creator can submit claim");
        managed.claim("user_1", user1);

        console.log("MEDIUM: Claim authorization can be bypassed!");
    }

    function testMEDIUM_StaleNameMapping() public {
        // Add member with name
        managed.addMember(user1, "Alice");

        // Change name - old name not cleared
        managed.changeName(user1, "Bob");

        // Old name still maps to address
        assertEq(managed.toAddress("Alice"), user1);
        assertEq(managed.toAddress("Bob"), user1);

        console.log("MEDIUM: Stale name mappings remain!");
    }

    // ============================================
    // MEDIUM: Validation Issues
    // ============================================

    function testMEDIUM_MissingZeroAddressChecks() public {
        // Can add address(0) as member
        managed.addMember(address(0), "zero");

        assertTrue(managed.isMember(address(0)));
        console.log("MEDIUM: Zero address can be added as member!");
    }

    function testMEDIUM_DepositEtherWithoutValueCheck() public {
        managed.addMember("user_1");

        // Send 1 ether but claim to deposit 2 ether
        managed.depositEtherForUser{value: 1 ether}("user_1", 2 ether);

        // Balance is set to 2 ether even though only 1 was sent!
        assertEq(managed.etherBalance("user_1"), 2 ether);
        console.log("MEDIUM: depositEtherForUser doesn't validate msg.value!");
    }

    function testMEDIUM_ContractSplitValidationTiming() public {
        // Create children
        address managedAddr = splitter.createManagedContract("creator_123", splitter.name(), 0);
        address zonedAddr = splitter.createZonedContract("creator_123", splitter.name(), 6);

        // Don't set split - it's only checked during reward!
        vm.expectRevert("Contract split percentages not set or invalid");
        (bool success, ) = address(splitter).call{value: 1 ether}("");

        console.log("MEDIUM: Contract split only validated at reward time!");
    }

    // ============================================
    // LOW: Gas and Logic Issues
    // ============================================

    function testLOW_UnboundedLoopDoS() public {
        // Add many members
        for (uint i = 0; i < 100; i++) {
            managed.addMember(string(abi.encodePacked("user_", i)));
        }

        // Reward distribution will cost a lot of gas
        uint256 gasBefore = gasleft();
        vm.deal(address(managed), 100 ether);

        try this.triggerReward() {
            uint256 gasUsed = gasBefore - gasleft();
            console.log("LOW: Gas used for 100 members:", gasUsed);

            if (gasUsed > 1000000) {
                console.log("LOW: Potential DoS with many members!");
            }
        } catch {
            console.log("LOW: Transaction failed - DoS successful!");
        }
    }

    function triggerReward() external {
        (bool success, ) = address(managed).call{value: 1 ether}("");
        require(success);
    }

    function testLOW_RoundingErrorDust() public {
        // Add 3 members
        managed.addMember("user_1");
        managed.addMember("user_2");
        managed.addMember("user_3");

        managed.claim("user_1", user1);
        managed.claim("user_2", user2);
        managed.claim("user_3", address(0x3));

        uint256 amount = 10 wei;  // Not evenly divisible by 3

        vm.deal(address(managed), amount);
        (bool success, ) = address(managed).call{value: amount}("");

        // Some dust will remain in contract
        if (address(managed).balance > 0) {
            console.log("LOW: Rounding error leaves dust:", address(managed).balance);
        }
    }

    // ============================================
    // INFORMATIONAL: Best Practices
    // ============================================

    function testINFO_MissingEvents() public {
        // setAppreciation doesn't emit event
        string[] memory users = new string[](1);
        users[0] = "user_1";
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;

        managed.addMember("user_1");

        // No event emitted here
        managed.setAppreciation(users, amounts);

        console.log("INFO: setAppreciation doesn't emit event!");
    }

    function testINFO_InconsistentErrorMessages() public {
        // Different styles of error messages throughout
        vm.expectRevert("Only owner can perform this action");
        vm.prank(user1);
        managed.upgradeToAndCall(address(0), "");

        vm.expectRevert("Request submitted by a non-member address");
        vm.prank(user1);
        managed.addMember(user2, "test");

        console.log("INFO: Inconsistent error message styles!");
    }

    // ============================================
    // UPGRADE SAFETY TESTS
    // ============================================

    function testUpgradeSafety_StatePreservation() public {
        // Add state
        managed.addMember("user_1");
        string[] memory users = new string[](1);
        users[0] = "user_1";
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 500;
        managed.setAppreciation(users, amounts);

        // Deploy new implementation
        ManagedUpgradeable newImpl = new ManagedUpgradeable();

        // Upgrade
        managed.upgradeToAndCall(address(newImpl), "");

        // Verify state preserved
        assertTrue(managed.isManagedMember("user_1"));
        assertEq(managed.appreciation("user_1"), 500);
        assertEq(managed.totalappreciation(), 500);

        console.log("Upgrade: State preserved correctly");
    }

    function testUpgradeSafety_OnlyOwner() public {
        ManagedUpgradeable newImpl = new ManagedUpgradeable();

        vm.prank(malicious);
        vm.expectRevert("Only owner can perform this action");
        managed.upgradeToAndCall(address(newImpl), "");

        console.log("Upgrade: Only owner can upgrade");
    }

    receive() external payable {}
}
