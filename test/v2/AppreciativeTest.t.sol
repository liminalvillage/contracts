// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/Appreciative.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract AppreciativeTest is Test {
    Appreciative public holon;
    MockToken public token;
    
    address public creator = address(1);
    address public beneficiary1 = address(2);
    address public beneficiary2 = address(3);
    address public beneficiary3 = address(4);

    string public user1 = "user1";
    string public user2 = "user2";
    string public user3 = "user3";

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
        vm.startPrank(creator);
        
        // Deploy contracts
        holon = new Appreciative(creator, "TestHolon");
        token = new MockToken();
        
        // Add members
        holon.addMember(user1);
        holon.addMember(user2);
        holon.addMember(user3);
        
        vm.stopPrank();
    }

    // Test Member Management
    function testAddMember() public {
        vm.startPrank(creator);
        string memory newUser = "newUser";
        holon.addMember(newUser);
        
        assertTrue(holon.isAppreciativeMember(newUser));
        assertEq(holon.remainingappreciation(newUser), 100);
        vm.stopPrank();
    }

    function testAddMultipleMembers() public {
        vm.startPrank(creator);
        string[] memory newUsers = new string[](2);
        newUsers[0] = "newUser1";
        newUsers[1] = "newUser2";
        
        holon.addMembers(newUsers);
        
        assertTrue(holon.isAppreciativeMember(newUsers[0]));
        assertTrue(holon.isAppreciativeMember(newUsers[1]));
        vm.stopPrank();
    }

    function testFailNonCreatorAddMember() public {
        vm.prank(address(5));
        holon.addMember("failUser");
    }

    // Test Appreciation System
    function testValidAppreciation() public {
        vm.prank(creator);
        holon.appreciate(user2, 50);
        
        assertEq(holon.appreciation(user2), 50);
        assertEq(holon.totalappreciation(), 50);
    }

    function testFailAppreciateOverLimit() public {
        vm.prank(creator);
        holon.appreciate(user2, 101);
    }

    function testFailAppreciateNonMember() public {
        vm.prank(creator);
        holon.appreciate("nonMember", 50);
    }

    // Test Deposit and Claim System
    function testDepositAndClaimEther() public {
        uint256 depositAmount = 1 ether;
        
        vm.deal(address(this), depositAmount);
        
        // Deposit ETH
        vm.prank(creator);
        holon.depositEtherForUser{value: depositAmount}(user1, depositAmount);
        assertEq(holon.etherBalance(user1), depositAmount);
        
        // Claim ETH
        vm.startPrank(creator);
        uint256 previousBalance = beneficiary1.balance;
        holon.claim(user1, beneficiary1);
        
        assertEq(beneficiary1.balance - previousBalance, depositAmount);
        assertEq(holon.etherBalance(user1), 0);
        assertTrue(holon.hasClaimed(user1));
        vm.stopPrank();
    }

    function testDepositAndClaimToken() public {
        uint256 depositAmount = 100 * 10**18;
        
        vm.startPrank(creator);
        token.approve(address(holon), depositAmount);
        
        // Deposit tokens
        holon.depositTokenForUser(user1, address(token), depositAmount);
        assertEq(holon.tokenBalance(user1, address(token)), depositAmount);
        
        // Claim tokens
        uint256 previousBalance = token.balanceOf(beneficiary1);
        holon.claim(user1, beneficiary1);
        
        assertEq(token.balanceOf(beneficiary1) - previousBalance, depositAmount);
        assertEq(holon.tokenBalance(user1, address(token)), 0);
        assertTrue(holon.hasClaimed(user1));
        vm.stopPrank();
    }

    function testFailDoubleClaim() public {
        vm.startPrank(creator);
        holon.claim(user1, beneficiary1);
        holon.claim(user1, beneficiary1);
        vm.stopPrank();
    }

    // Test Reward Distribution
    function testRewardDistributionWithAppreciation() public {
        uint256 rewardAmount = 100 ether;
        vm.deal(address(holon), rewardAmount);
        
        // Set up appreciation
        vm.startPrank(creator);
        holon.appreciate(user2, 60); // user2 gets 60% appreciation
        
        // Distribute rewards
        holon.reward(address(0), rewardAmount);
        
        // Check rewards were stored correctly
        uint256 expectedReward = (rewardAmount * 60) / 100; // 60% of rewards
        assertEq(holon.etherBalance(user2), expectedReward);
        
        // Claim rewards
        holon.claim(user2, beneficiary2);
        assertEq(beneficiary2.balance, expectedReward);
        vm.stopPrank();
    }

    function testRewardDistributionWithoutAppreciation() public {
        uint256 rewardAmount = 100 ether;
        vm.deal(address(holon), rewardAmount);
        
        vm.startPrank(creator);
        holon.reward(address(0), rewardAmount);
        
        // Should split equally among members
        uint256 expectedReward = rewardAmount / 3; // 3 members
        assertEq(holon.etherBalance(user1), expectedReward);
        assertEq(holon.etherBalance(user2), expectedReward);
        assertEq(holon.etherBalance(user3), expectedReward);
        vm.stopPrank();
    }

    // Test Events
    function testRewardEvents() public {
        uint256 amount = 100 ether;
        vm.deal(address(holon), amount);
        
        vm.startPrank(creator);
        
        // Set up claim first
        holon.claim(user1, beneficiary1);
        
        vm.expectEmit(true, true, false, true);
        emit MemberRewarded(
            address(holon),
            beneficiary1,
            amount/3, // Equal split among 3 members
            false,
            "ETH"
        );
        
        vm.expectEmit(true, false, false, true);
        emit RewardDistributed(
            address(holon),
            amount,
            3,
            "ETH"
        );
        
        holon.reward(address(0), amount);
        vm.stopPrank();
    }

    receive() external payable {}
}