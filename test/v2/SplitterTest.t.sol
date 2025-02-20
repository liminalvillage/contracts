// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/Splitter.sol";
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
    
    address public creator;
    address public beneficiary1;
    address public beneficiary2;
    address public beneficiary3;

    string constant USERID1 = "user1";
    string constant USERID2 = "user2";
    string constant USERID3 = "user3";
    
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

    function setUp() public {
        // Setup addresses
        creator = address(this);
        beneficiary1 = makeAddr("beneficiary1");
        beneficiary2 = makeAddr("beneficiary2");
        beneficiary3 = makeAddr("beneficiary3");
        
        // Deploy contracts
        splitter = new Splitter(creator, "TestSplitter", 0);
        token = new MockERC20();
        
        // Add members
        splitter.addMember(USERID1);
        splitter.addMember(USERID2);
        splitter.addMember(USERID3);

        // Fund splitter with ETH
        vm.deal(address(splitter), 100 ether);
    }

    function testConstructor() public {
        assertEq(splitter.name(), "TestSplitter");
        assertEq(splitter.flavor(), "Splitter");
        assertEq(splitter.creator(), creator);
    }

    function testMemberAddition() public {
        // Test single member addition
        string memory newUserId = "user4";
        splitter.addMember(newUserId);
        assertTrue(splitter.isSplitterMember(newUserId));
        
        // Test multiple member addition
        string[] memory newUserIds = new string[](2);
        newUserIds[0] = "user5";
        newUserIds[1] = "user6";
        splitter.addMembers(newUserIds);
        assertTrue(splitter.isSplitterMember(newUserIds[0]));
        assertTrue(splitter.isSplitterMember(newUserIds[1]));
    }

    function testAddMemberFailsWithNonCreator() public {
        vm.startPrank(beneficiary1);
        vm.expectRevert("Only creator can add members");
        splitter.addMember("newUser");
        vm.stopPrank();
    }

    function testSetSplit() public {
        string[] memory userIds = new string[](3);
        userIds[0] = USERID1;
        userIds[1] = USERID2;
        userIds[2] = USERID3;
        
        uint[] memory splits = new uint[](3);
        splits[0] = 50;
        splits[1] = 30;
        splits[2] = 20;
        
        splitter.setSplit(userIds, splits);
        
        assertEq(splitter.percentages(USERID1), 50);
        assertEq(splitter.percentages(USERID2), 30);
        assertEq(splitter.percentages(USERID3), 20);
    }

    function testDepositAndClaimEther() public {
        uint256 depositAmount = 1 ether;
        
        // Test deposit
        splitter.depositEtherForUser{value: depositAmount}(USERID1, depositAmount);
        assertEq(splitter.etherBalance(USERID1), depositAmount);
        
        // Test claim
        uint256 initialBalance = beneficiary1.balance;
        vm.prank(creator);
        splitter.claim(USERID1, beneficiary1);
        
        assertEq(beneficiary1.balance - initialBalance, depositAmount);
        assertEq(splitter.etherBalance(USERID1), 0);
        assertTrue(splitter.hasClaimed(USERID1));
    }

    function testDepositAndClaimTokens() public {
        uint256 depositAmount = 100 * 10**18;
        
        // Approve and deposit tokens
        token.approve(address(splitter), depositAmount);
        splitter.depositTokenForUser(USERID1, address(token), depositAmount);
        
        assertEq(splitter.tokenBalance(USERID1, address(token)), depositAmount);
        
        // Test claim
        vm.prank(creator);
        splitter.claim(USERID1, beneficiary1);
        
        assertEq(token.balanceOf(beneficiary1), depositAmount);
        assertEq(splitter.tokenBalance(USERID1, address(token)), 0);
        assertTrue(splitter.hasClaimed(USERID1));
    }

    function testRewardWithEtherSplit() public {
        // Set up split
        string[] memory userIds = new string[](3);
        userIds[0] = USERID1;
        userIds[1] = USERID2;
        userIds[2] = USERID3;
        
        uint[] memory splits = new uint[](3);
        splits[0] = 50;
        splits[1] = 30;
        splits[2] = 20;
        
        splitter.setSplit(userIds, splits);
        
        // Set up claiming addresses
        vm.startPrank(creator);
        splitter.claim(USERID1, beneficiary1);
        splitter.claim(USERID2, beneficiary2);
        splitter.claim(USERID3, beneficiary3);
        vm.stopPrank();
        
        // Send reward
        uint256 rewardAmount = 1 ether;
        
        vm.expectEmit(true, true, false, true);
        emit RewardDistributed(
            address(splitter),
            rewardAmount,
            3,
            "ETH"
        );
        
        splitter.reward{value: rewardAmount}(address(0), 0);
        
        // Verify splits
        assertEq(beneficiary1.balance, rewardAmount * 50 / 100);
        assertEq(beneficiary2.balance, rewardAmount * 30 / 100);
        assertEq(beneficiary3.balance, rewardAmount * 20 / 100);
    }

    function testRewardWithTokenSplit() public {
        // Set up split
        string[] memory userIds = new string[](3);
        userIds[0] = USERID1;
        userIds[1] = USERID2;
        userIds[2] = USERID3;
        
        uint[] memory splits = new uint[](3);
        splits[0] = 50;
        splits[1] = 30;
        splits[2] = 20;
        
        splitter.setSplit(userIds, splits);
        
        // Set up claiming addresses
        vm.startPrank(creator);
        splitter.claim(USERID1, beneficiary1);
        splitter.claim(USERID2, beneficiary2);
        splitter.claim(USERID3, beneficiary3);
        vm.stopPrank();
        
        // Send tokens to splitter
        uint256 rewardAmount = 100 * 10**18;
        token.transfer(address(splitter), rewardAmount);
        
        vm.expectEmit(true, true, false, true);
        emit RewardDistributed(
            address(splitter),
            rewardAmount,
            3,
            "ERC20"
        );
        
        splitter.reward(address(token), rewardAmount);
        
        // Verify splits
        assertEq(token.balanceOf(beneficiary1), rewardAmount * 50 / 100);
        assertEq(token.balanceOf(beneficiary2), rewardAmount * 30 / 100);
        assertEq(token.balanceOf(beneficiary3), rewardAmount * 20 / 100);
    }

    receive() external payable {}
}