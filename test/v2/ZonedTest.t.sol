// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/Zoned.sol";
import "../../src/IHolonFactory.sol";
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
        creator = vm.addr(1);
        member1 = vm.addr(2);
        member2 = vm.addr(3);
        member3 = vm.addr(4);
        coreMember = vm.addr(5);
        
        vm.deal(creator, 100 ether);
        vm.deal(member1, 1 ether);
        vm.deal(member2, 1 ether);
        vm.deal(member3, 1 ether);
        vm.deal(coreMember, 1 ether);
        
        vm.prank(creator);
        zoned = new Zoned("deployer_id", creator, "TestHolon", 6);
        
        vm.prank(creator);
        mockToken = new MockERC20();
    }

    function testMembraneFunctions() public {
        vm.startPrank(creator);
        
        // Test single member addition
        zoned.addMember("test_creator", "user1");
        assertTrue(zoned.isZonedMember("user1"));
        assertEq(zoned.zone("user1"), 0); // Should be added to zone 0
        
        // Test multiple members addition
        string[] memory users = new string[](2);
        users[0] = "user2";
        users[1] = "user3";
        zoned.addMembers("deployer_id", users);
        
        assertTrue(zoned.isZonedMember("user2"));
        assertTrue(zoned.isZonedMember("user3"));
        assertEq(zoned.zone("user2"), 0);
        assertEq(zoned.zone("user3"), 0);
        
        vm.stopPrank();
    }

    function testTokenDepositsAndClaims() public {
        vm.startPrank(creator);
        
        // Add a member
        zoned.addMember("test_creator", "user1");
        
        // Test Ether deposit
        zoned.depositEtherForUser{value: 1 ether}("user1", 1 ether);
        assertEq(zoned.etherBalance("user1"), 1 ether);
        
        // Test ERC20 deposit
        uint256 tokenAmount = 1000 * 10**18;
        mockToken.approve(address(zoned), tokenAmount);
        zoned.depositTokenForUser("user1", address(mockToken), tokenAmount);
        assertEq(zoned.tokenBalance("user1", address(mockToken)), tokenAmount);
        
        // Test claiming
        address beneficiary = address(0x123);
        vm.deal(beneficiary, 0); // Ensure beneficiary starts with 0 ETH
        
        uint256 initialEthBalance = beneficiary.balance;
        uint256 initialTokenBalance = mockToken.balanceOf(beneficiary);
        
        zoned.claim("user1", beneficiary);
        
        assertEq(beneficiary.balance - initialEthBalance, 1 ether);
        assertEq(mockToken.balanceOf(beneficiary) - initialTokenBalance, tokenAmount);
        assertTrue(zoned.hasClaimed("user1"));
        
        vm.stopPrank();
    }

    function testRewardFunctionParameters() public {
        vm.startPrank(creator);
        
        // Test setting different reward function parameters
        zoned.setRewardFunction("deployer_id", 1, 1, 1);
        uint256[] memory rewards = zoned.calculateRewards();
        
        // Verify rewards array length
        assertEq(rewards.length, 7); // 0 to 6 zones
        
        // Test that rewards increase with zone number (since a > 0)
        for (uint i = 1; i < rewards.length - 1; i++) {
            assertTrue(rewards[i] < rewards[i + 1]);
        }
        
        // Test total percentage adds up to 10000 (100%)
        uint256 total = 0;
        for (uint i = 0; i < rewards.length; i++) {
            total += rewards[i];
        }
        assertEq(total, 10000);
        
        vm.stopPrank();
    }

    function testZoneMigration() public {
        vm.startPrank(creator);
        
        // Add member to zone 2
        zoned.addMember("test_creator","user1");
        zoned.addToZone("test_creator","user1", 2);
        assertEq(zoned.zone("user1"), 2);
        
        // Get initial zone 2 members count
        uint256 initialZone2Count = getZoneMembersCount(2);
        
        // Move to zone 3
        zoned.addToZone("test_creator","user1", 3);
        
        // Verify zone change
        assertEq(zoned.zone("user1"), 3);
        assertEq(getZoneMembersCount(2), initialZone2Count - 1);
        assertEq(getZoneMembersCount(3), 1);
        
        vm.stopPrank();
    }

    function testFailureScenarios() public {
        // Test unauthorized member addition
        vm.prank(member1);
        vm.expectRevert("Only creator can add members");
        zoned.addMember("test_creator","user1");
        
        // Test unauthorized zone change
        vm.prank(member1);
        vm.expectRevert("only creator can change the zones currently!");
        zoned.addToZone("test_creator","user1", 1);
        
        // Test unauthorized reward function change
        vm.prank(member1);
        vm.expectRevert("only creator can change members can change the reward function");
        zoned.setRewardFunction("deployer_id", 1, 1, 1);
    }

    // Helper function to count members in a zone
    function getZoneMembersCount(uint256 _zone) internal view returns (uint256) {
        uint256 count = 0;
        try this.callZoneMembers(payable(address(zoned)), _zone, 0) returns (string memory) {
            count++;
            uint256 i = 1;
            while (true) {
                try this.callZoneMembers(payable(address(zoned)), _zone, i) returns (string memory) {
                    count++;
                    i++;
                } catch {
                    break;
                }
            }
        } catch {}
        return count;
    }

    function callZoneMembers(address payable zonedContract, uint256 zoneNumber, uint256 index) external view returns (string memory) {
        return Zoned(zonedContract).zonemembers(zoneNumber, index);
    }

    receive() external payable {}
}