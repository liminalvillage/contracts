// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Zoned.sol";
import "../src/IHolonFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

contract ZonedTest is Test {
    Zoned public zoned;
    MockERC20 public mockToken;
    address public creator;
    address public member1;
    address public member2;
    address public member3;
    address public coreMember;
    
    function setUp() public {
        // Setup addresses with different private keys
        creator = vm.addr(1);
        member1 = vm.addr(2);
        member2 = vm.addr(3);
        member3 = vm.addr(4);
        coreMember = vm.addr(5);
        
        // Deal ETH to addresses
        vm.deal(creator, 100 ether);
        vm.deal(member1, 1 ether);
        vm.deal(member2, 1 ether);
        vm.deal(member3, 1 ether);
        vm.deal(coreMember, 1 ether);
        
        // Deploy Zoned contract as creator (setting both msg.sender and tx.origin)
        vm.prank(creator, creator);
        zoned = new Zoned(creator, "TestHolon", 6);

        // Add core member to zone 6
        vm.prank(creator, creator);
        zoned.addToZone(coreMember, 6);

        // Deploy and setup mock token
        vm.prank(creator);
        mockToken = new MockERC20();
    }

    function testInitialState() public {
        assertEq(zoned.name(), "TestHolon");
        assertEq(zoned.creator(), creator);
        assertEq(zoned.flavor(), "Zoned");
        assertEq(zoned.nzones(), 6);
        assertEq(zoned.zone(creator), 6); // Creator should be in the highest zone
    }

    function testAddToZone() public {
        vm.prank(creator, creator);
        zoned.addToZone(member1, 3);
        
        assertEq(zoned.zone(member1), 3);
        assertTrue(isMemberInZone(member1, 3), "Member should be in zone 3");
    }

    function testRewardFunctionCalculation() public {
        // Use core member to modify reward function
        vm.startPrank(coreMember, coreMember);
        
        // Check initial values
        assertEq(zoned.a(), 0);
        assertEq(zoned.b(), 0);
        assertEq(zoned.c(), 1);
        
        // Set new reward function as core member
        zoned.setRewardFunction(1, 2, 3);
        
        // Verify the new values
        assertEq(zoned.a(), 1);
        assertEq(zoned.b(), 2);
        assertEq(zoned.c(), 3);
        
        vm.stopPrank();
    }

    function testEtherReward() public {
        vm.startPrank(creator, creator);
        
        // Add members to different zones
        zoned.addToZone(member1, 1);
        zoned.addToZone(member2, 2);
        zoned.addToZone(member3, 3);
        
        uint256 initialBalance1 = member1.balance;
        uint256 initialBalance2 = member2.balance;
        uint256 initialBalance3 = member3.balance;
        
        // Send reward
        zoned.reward{value: 1 ether}(address(0), 1 ether);
        
        vm.stopPrank();
        
        assertTrue(member1.balance > initialBalance1);
        assertTrue(member2.balance > initialBalance2);
        assertTrue(member3.balance > initialBalance3);
    }

    function testERC20Reward() public {
        vm.startPrank(creator, creator);
        
        // Add members to different zones
        zoned.addToZone(member1, 1);
        zoned.addToZone(member2, 2);
        zoned.addToZone(member3, 3);
        
        // Transfer tokens to contract
        uint256 rewardAmount = 1000 * 10**18;
        mockToken.transfer(address(zoned), rewardAmount);
        
        uint256 initialBalance1 = mockToken.balanceOf(member1);
        uint256 initialBalance2 = mockToken.balanceOf(member2);
        uint256 initialBalance3 = mockToken.balanceOf(member3);
        
        // Distribute rewards
        zoned.reward(address(mockToken), rewardAmount);
        
        vm.stopPrank();
        
        assertTrue(mockToken.balanceOf(member1) > initialBalance1);
        assertTrue(mockToken.balanceOf(member2) > initialBalance2);
        assertTrue(mockToken.balanceOf(member3) > initialBalance3);
    }

    function testFailAddToHigherZone() public {
        // First, add member1 to zone 2 as creator
        vm.startPrank(creator, creator);
        zoned.addToZone(member1, 2);
        vm.stopPrank();
        
        // Now try to add member2 to zone 3 as member1 (should fail)
        vm.prank(member1, member1);  // Set both msg.sender and tx.origin
        
        // This should revert with "members in lower zones cannot promote to higher zones"
        vm.expectRevert("members in lower zones cannot promote to higher zones");
        zoned.addToZone(member2, 3);
    }

    function testZoneMembershipChange() public {
        vm.startPrank(creator, creator);
        
        zoned.addToZone(member1, 2);
        assertEq(zoned.zone(member1), 2);
        
        zoned.addToZone(member1, 3);
        assertEq(zoned.zone(member1), 3);
        
        assertFalse(isMemberInZone(member1, 2), "Member should not be in zone 2");
        assertTrue(isMemberInZone(member1, 3), "Member should be in zone 3");
        
        vm.stopPrank();
    }

    function isMemberInZone(address member, uint256 zoneNumber) internal view returns (bool) {
        try this.callZoneMembers(payable(address(zoned)), zoneNumber, 0) returns (address firstMember) {
            if (firstMember == member) return true;
            
            uint256 i = 1;
            while (true) {
                try this.callZoneMembers(payable(address(zoned)), zoneNumber, i) returns (address nextMember) {
                    if (nextMember == member) return true;
                    i++;
                } catch {
                    break;
                }
            }
        } catch {
            // No members in this zone
            return false;
        }
        return false;
    }

    function callZoneMembers(address payable zonedContract, uint256 zoneNumber, uint256 index) external view returns (address) {
        return Zoned(zonedContract).zonemembers(zoneNumber, index);
    }

    receive() external payable {}
}