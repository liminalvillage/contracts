// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Appreciative.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract AppreciativeTest is Test {
    Appreciative public holon;
    MockToken public token;
    
    address public lead = address(1);
    address public member1 = address(2);
    address public member2 = address(3);
    address public member3 = address(4);
    address public nonMember = address(5);

    event MemberRewarded(
        address indexed holon,
        address indexed member,
        uint256 amount,
        bool isContract,
        string rewardType
    );

    event RewardDistributed(
        address indexed holon,
        uint256 amount,
        uint256 memberCount,
        string rewardType
    );

    function setUp() public {
        // Set the lead as tx.origin and msg.sender
        vm.startPrank(lead, lead); // This sets both msg.sender and tx.origin
        
        // Deploy contracts
        holon = new Appreciative(lead, "TestHolon");
        token = new MockToken();
        
        // Add lead as first member (lead is already owner due to tx.origin in constructor)
        holon.addMember(lead, "Lead");
        
        // Now add other members
        holon.addMember(member1, "Member1");
        holon.addMember(member2, "Member2");
        holon.addMember(member3, "Member3");
        
        vm.stopPrank();
    }

    // Test Member Management
    function testAddMember() public {
        vm.startPrank(lead, lead);
        address newMember = address(6);
        holon.addMember(newMember, "NewMember");
        
        assertTrue(holon.isMember(newMember));
        assertEq(holon.remainingappreciation(newMember), 100);
        vm.stopPrank();
    }

    // Test Appreciation Mechanics
    function testValidAppreciation() public {
        vm.startPrank(member1);
        holon.appreciate(member2, 50);
        
        assertEq(holon.remainingappreciation(member1), 50);
        assertEq(holon.appreciation(member2), 50);
        assertEq(holon.totalappreciation(), 50);
        vm.stopPrank();
    }

    function testFailAppreciateOverLimit() public {
        vm.startPrank(member1);
        holon.appreciate(member2, 101);
        vm.stopPrank();
    }

    function testFailSelfAppreciation() public {
        vm.startPrank(member1);
        holon.appreciate(member1, 50);
        vm.stopPrank();
    }

    function testFailAppreciateNonMember() public {
        vm.startPrank(member1);
        holon.appreciate(nonMember, 50);
        vm.stopPrank();
    }

    // Test Lead Functions
    function testResetAppreciation() public {
        // First give some appreciation
        vm.prank(member1);
        holon.appreciate(member2, 50);
        
        // Then reset it
        vm.startPrank(lead, lead);
        holon.resetAppreciation();
        
        assertEq(holon.remainingappreciation(member1), 100);
        assertEq(holon.appreciation(member2), 0);
        assertEq(holon.totalappreciation(), 0);
        vm.stopPrank();
    }

    function testFailNonLeadReset() public {
        vm.prank(member1);
        holon.resetAppreciation();
    }

    // Test Reward Distribution
    function testEthRewardWithoutAppreciation() public {
        uint256 initialBalance = 100 ether;
        vm.deal(address(holon), initialBalance);
        
        uint256 expectedReward = initialBalance / 4; // 4 members (including lead)
        
        vm.startPrank(lead, lead);
        holon.reward{value: initialBalance}(address(0), 0);
        
        assertEq(member1.balance, expectedReward);
        assertEq(member2.balance, expectedReward);
        assertEq(member3.balance, expectedReward);
        assertEq(lead.balance, expectedReward);
        vm.stopPrank();
    }

    function testEthRewardWithAppreciation() public {
        // Set up appreciation
        vm.prank(member1);
        holon.appreciate(member2, 60);
        
        uint256 initialBalance = 100 ether;
        vm.deal(address(holon), initialBalance);
        
        vm.startPrank(lead, lead);
        holon.reward{value: initialBalance}(address(0), initialBalance);
        
        // member2 should get 60% of the reward
        assertEq(member2.balance, (initialBalance * 60) / 100);
        vm.stopPrank();
    }

    function testERC20RewardWithAppreciation() public {
        // Give tokens to holon
        vm.startPrank(lead, lead);
        uint256 amount = 1000 * 10**18;
        token.transfer(address(holon), amount);
        
        // Set up appreciation
        vm.stopPrank();
        vm.prank(member1);
        holon.appreciate(member2, 60);
        
        // Distribute rewards
        vm.startPrank(lead, lead);
        holon.reward(address(token), amount);
        
        // member2 should get 60% of tokens
        assertEq(token.balanceOf(member2), (amount * 60) / 100);
        vm.stopPrank();
    }

    function testMultipleMembersAppreciation() public {
        vm.startPrank(member1);
        holon.appreciate(member2, 30);
        holon.appreciate(member3, 40);
        vm.stopPrank();

        vm.prank(member2);
        holon.appreciate(member3, 50);

        assertEq(holon.appreciation(member3), 90);
        assertEq(holon.totalappreciation(), 120);
    }

    // Test Events
    function testRewardEvents() public {
        uint256 amount = 100 ether;
        vm.deal(address(holon), amount);
        
        vm.startPrank(lead, lead);
        
        vm.expectEmit(true, true, false, true);
        emit MemberRewarded(address(holon), member1, amount/4, false, "ETH");
        
        vm.expectEmit(true, false, false, true);
        emit RewardDistributed(address(holon), amount, 4, "ETH");
        
        holon.reward{value: amount}(address(0), amount);
        vm.stopPrank();
    }
}