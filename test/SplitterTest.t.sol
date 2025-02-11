// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Splitter.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract SplitterTest is Test {
    Splitter public splitter;
    MockERC20 public token;
    
    address public owner;
    address public member1;
    address public member2;
    address public member3;

    // Store member names for verification
    string constant MEMBER1_NAME = "Alice";
    string constant MEMBER2_NAME = "Bob";
    string constant MEMBER3_NAME = "Charlie";
    
    event MemberRewarded(
        address indexed holon,
        address indexed member,
        uint256 amount,
        bool isContract,
        string rewardType
    );
    
    event RewardDistributed(
        address indexed holon,
        uint256 totalAmount,
        uint256 memberCount,
        string rewardType
    );

    event AddedMember(address indexed member, string name);

    function setUp() public {
        // Setup addresses
        owner = address(this);
        member1 = makeAddr("member1");
        member2 = makeAddr("member2");
        member3 = makeAddr("member3");
        
        // Deploy contracts
        vm.prank(owner);
        splitter = new Splitter(owner, "TestSplitter", 0);
        token = new MockERC20();
        
        // Add members one by one with their names
        // First member needs to be added by owner
        vm.startPrank(owner);
        splitter.addMember(member1, MEMBER1_NAME);
        vm.stopPrank();

        // Subsequent members can be added by existing members
        vm.startPrank(member1);
        splitter.addMember(member2, MEMBER2_NAME);
        splitter.addMember(member3, MEMBER3_NAME);
        vm.stopPrank();
        
        // Fund splitter with ETH
        vm.deal(address(splitter), 100 ether);
    }

    function testConstructor() public {
        // owner is not publicly accessible, but we can verify the name and flavor
        assertEq(splitter.name(), "TestSplitter");
        assertEq(splitter.flavor(), "Splitter");
    }

    function testMemberAddition() public {
        // Test that members were added correctly
        assertTrue(splitter.isMember(member1));
        assertTrue(splitter.isMember(member2));
        assertTrue(splitter.isMember(member3));

        // Test member names were stored correctly
        assertEq(splitter.toName(member1), MEMBER1_NAME);
        assertEq(splitter.toName(member2), MEMBER2_NAME);
        assertEq(splitter.toName(member3), MEMBER3_NAME);

        // Test address mapping
        assertEq(splitter.toAddress(MEMBER1_NAME), member1);
        assertEq(splitter.toAddress(MEMBER2_NAME), member2);
        assertEq(splitter.toAddress(MEMBER3_NAME), member3);
    }

    function testAddMemberFailsWithDuplicateAddress() public {
        vm.startPrank(member1);
        vm.expectRevert("Member already added");
        splitter.addMember(member1, "NewName");
        vm.stopPrank();
    }

    function testAddMemberFailsWithDuplicateName() public {
        vm.startPrank(member1);
        address newMember = makeAddr("newMember");
        vm.expectRevert("Name is already taken");
        splitter.addMember(newMember, MEMBER1_NAME);
        vm.stopPrank();
    }

    function testAddMemberFailsWithNonMemberCaller() public {
        address nonMember = makeAddr("nonMember");
        vm.startPrank(nonMember);
        vm.expectRevert("Request submitted by a non-member address");
        splitter.addMember(nonMember, "NonMember");
        vm.stopPrank();
    }

    function testSetSplit() public {
        vm.startPrank(owner);
        address[] memory members = new address[](3);
        members[0] = member1;
        members[1] = member2;
        members[2] = member3;
        
        uint[] memory percentages = new uint[](3);
        percentages[0] = 50;
        percentages[1] = 30;
        percentages[2] = 20;
        
        splitter.setSplit(members, percentages);
        
        assertEq(splitter.percentages(member1), 50);
        assertEq(splitter.percentages(member2), 30);
        assertEq(splitter.percentages(member3), 20);
        vm.stopPrank();
    }
    function testSetSplitFailsWithNonOwner() public {
        // Try to set split as non-owner (member1)
        vm.startPrank(member1);
        
        address[] memory members = new address[](3);
        members[0] = member1;
        members[1] = member2;
        members[2] = member3;
        
        uint[] memory percentages = new uint[](3);
        percentages[0] = 50;
        percentages[1] = 30;
        percentages[2] = 20;
        
        vm.expectRevert("Only splitter owner can set the split");
        splitter.setSplit(members, percentages);
        vm.stopPrank();
    }

    function testSetSplitFailsWithInvalidPercentages() public {
        vm.startPrank(owner);
        address[] memory members = new address[](3);
        members[0] = member1;
        members[1] = member2;
        members[2] = member3;
        
        uint[] memory percentages = new uint[](3);
        percentages[0] = 50;
        percentages[1] = 30;
        percentages[2] = 30; // Total 110%
        
        vm.expectRevert("Total percentage should be 100");
        splitter.setSplit(members, percentages);
        vm.stopPrank();
    }

    function testSetSplitFailsWithInvalidMembers() public {
        vm.startPrank(owner);
        address[] memory members = new address[](2); // Wrong length
        members[0] = member1;
        members[1] = member2;
        
        uint[] memory percentages = new uint[](2);
        percentages[0] = 60;
        percentages[1] = 40;
        
        vm.expectRevert("Members array should be equal to the full list of members");
        splitter.setSplit(members, percentages);
        vm.stopPrank();
    }

    function testRewardWithEth() public {
        vm.startPrank(owner);
        // Set up split percentages
        address[] memory members = new address[](3);
        members[0] = member1;
        members[1] = member2;
        members[2] = member3;
        
        uint[] memory percentages = new uint[](3);
        percentages[0] = 50;
        percentages[1] = 30;
        percentages[2] = 20;
        
        splitter.setSplit(members, percentages);
        vm.stopPrank();
        
        // Record initial balances
        uint256 initialBalance1 = member1.balance;
        uint256 initialBalance2 = member2.balance;
        uint256 initialBalance3 = member3.balance;
        
        // Distribute 1 ETH
        uint256 rewardAmount = 1 ether;
        
        // Expect events for each member reward
        vm.expectEmit(true, true, false, true);
        emit MemberRewarded(
            address(splitter),
            member1,
            rewardAmount * 50 / 100,
            false,
            "ETH"
        );
        
        vm.expectEmit(true, true, false, true);
        emit MemberRewarded(
            address(splitter),
            member2,
            rewardAmount * 30 / 100,
            false,
            "ETH"
        );
        
        vm.expectEmit(true, true, false, true);
        emit MemberRewarded(
            address(splitter),
            member3,
            rewardAmount * 20 / 100,
            false,
            "ETH"
        );
        
        // Expect the summary event
        vm.expectEmit(true, false, false, true);
        emit RewardDistributed(
            address(splitter),
            rewardAmount,
            3,
            "ETH"
        );
        
        splitter.reward{value: rewardAmount}(address(0), 0);
        
        // Check final balances
        assertEq(member1.balance - initialBalance1, rewardAmount * 50 / 100);
        assertEq(member2.balance - initialBalance2, rewardAmount * 30 / 100);
        assertEq(member3.balance - initialBalance3, rewardAmount * 20 / 100);
    }

    function testRewardWithERC20() public {
        vm.startPrank(owner);
        // Set up split percentages
        address[] memory members = new address[](3);
        members[0] = member1;
        members[1] = member2;
        members[2] = member3;
        
        uint[] memory percentages = new uint[](3);
        percentages[0] = 50;
        percentages[1] = 30;
        percentages[2] = 20;
        
        splitter.setSplit(members, percentages);
        vm.stopPrank();
        
        // Transfer tokens to splitter
        uint256 rewardAmount = 100 * 10**18;
        token.transfer(address(splitter), rewardAmount);
        
        // Expect events for each member reward
        vm.expectEmit(true, true, false, true);
        emit MemberRewarded(
            address(splitter),
            member1,
            rewardAmount * 50 / 100,
            false,
            "ERC20"
        );
        
        vm.expectEmit(true, true, false, true);
        emit MemberRewarded(
            address(splitter),
            member2,
            rewardAmount * 30 / 100,
            false,
            "ERC20"
        );
        
        vm.expectEmit(true, true, false, true);
        emit MemberRewarded(
            address(splitter),
            member3,
            rewardAmount * 20 / 100,
            false,
            "ERC20"
        );
        
        // Expect the summary event
        vm.expectEmit(true, false, false, true);
        emit RewardDistributed(
            address(splitter),
            rewardAmount,
            3,
            "ERC20"
        );
        
        splitter.reward(address(token), rewardAmount);
        
        // Check token balances
        assertEq(token.balanceOf(member1), rewardAmount * 50 / 100);
        assertEq(token.balanceOf(member2), rewardAmount * 30 / 100);
        assertEq(token.balanceOf(member3), rewardAmount * 20 / 100);
    }


    function testRewardFailsWithInsufficientERC20Balance() public {
        vm.startPrank(owner);
        // Set up split percentages
        address[] memory members = new address[](3);
        members[0] = member1;
        members[1] = member2;
        members[2] = member3;
        
        uint[] memory percentages = new uint[](3);
        percentages[0] = 50;
        percentages[1] = 30;
        percentages[2] = 20;
        
        splitter.setSplit(members, percentages);
        vm.stopPrank();
        
        uint256 rewardAmount = 100 * 10**18;
        // Don't transfer any tokens to splitter
        
        vm.expectRevert("Not enough tokens in the contract");
        splitter.reward(address(token), rewardAmount);
    }
    

    receive() external payable {}
}