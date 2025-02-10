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

contract AppreciationOverflowTest is Test {
    Managed public managed;
    TestToken public token;
    address public creator;
    address public normalUser;
    address public maliciousUser;
    
    function setUp() public {
        creator = address(this);
        managed = new Managed(creator, "TestHolon");
        token = new TestToken();
        
        normalUser = address(0x1);
        maliciousUser = address(0x2);
        
        // Add both users as members
        managed.addMember("normal");
        managed.addMember("malicious");
        
        // Set up their claims
        vm.startPrank(creator);
        managed.claim("normal", normalUser);
        managed.claim("malicious", maliciousUser);
        vm.stopPrank();
        
        // Fund the contract
        token.transfer(address(managed), 1000 * 10**18);
    }
    
    function testAppreciationOverflow() public {
        // Let's try to set a very large appreciation value
        uint256 largeAppreciation = type(uint256).max - 100;
        
        console.log("Initial state:");
        console.log("Total appreciation:", managed.totalappreciation());
        
        // Set appreciation for malicious user
        managed.setUserAppreciation("malicious", largeAppreciation);
        console.log("After setting large appreciation:");
        console.log("Total appreciation:", managed.totalappreciation());
        
        // Set normal appreciation for other user
        managed.setUserAppreciation("normal", 100);
        console.log("After setting normal appreciation:");
        console.log("Total appreciation:", managed.totalappreciation());
        
        // Now try to distribute rewards
        console.log("\nAttempting reward distribution...");
        uint256 rewardAmount = 1000 * 10**18;
        token.approve(address(managed), rewardAmount);
        managed.reward(address(token), rewardAmount);
        
        // Check final distribution
        console.log("\nFinal balances:");
        console.log("Normal user:", token.balanceOf(normalUser) / 1e18);
        console.log("Malicious user:", token.balanceOf(maliciousUser) / 1e18);
        
        // In Solidity 0.8+, this should revert on overflow
        // But let's verify the distribution is still fair if it doesn't
        assertGt(token.balanceOf(normalUser), 0, "Normal user should receive some tokens");
    }
}