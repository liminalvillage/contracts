// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/Splitter.sol";
import "../../src/ManagedFactory.sol";
import "../../src/ZonedFactory.sol";
import "../../src/TestToken.sol";
import "forge-std/console2.sol";

contract SplitterTest is Test {
    Splitter public splitter;
    ManagedFactory public managedFactory;
    ZonedFactory public zonedFactory;
    TestToken public testToken;
    
    // Test parameters
    address public owner;
    address public bot;
    string constant CREATOR_ID = "creator123";
    string constant SPLITTER_NAME = "TestSplitter";
    uint256 constant PARAMETER = 1;
    
    // Test amounts
    uint256 constant INITIAL_TOKEN_SUPPLY = 1000000 ether;
    uint256 constant TEST_AMOUNT = 100 ether;
    
    function setUp() public {
        // Setup accounts
        owner = address(0x90F79bf6EB2c4f870365E785982E1f101E93b906); // localhost
        bot = address(0x90F79bf6EB2c4f870365E785982E1f101E93b906); // localhost
        
        // Deploy factories
        managedFactory = new ManagedFactory();
        zonedFactory = new ZonedFactory();
        
        // Deploy test token
        testToken = new TestToken(INITIAL_TOKEN_SUPPLY);
        
        // Deploy Splitter
        splitter = new Splitter(
            owner,
            CREATOR_ID,
            SPLITTER_NAME,
            PARAMETER,
            address(managedFactory),
            address(zonedFactory)
        );
        
        // Create child contracts
        splitter.createManagedContract(CREATOR_ID, SPLITTER_NAME, PARAMETER);
        splitter.createZonedContract(CREATOR_ID, SPLITTER_NAME, PARAMETER);
    }

    function testSplitterRewardDistribution() public {
        // 1. Get child contract addresses
        address managedAddress = splitter.contractsByType(
            string.concat(SPLITTER_NAME, "_managed")
        );
        address zonedAddress = splitter.contractsByType(
            string.concat(SPLITTER_NAME, "_zoned")
        );
        
        // Verify child contracts were created
        assertTrue(managedAddress != address(0), "Managed contract not created");
        assertTrue(zonedAddress != address(0), "Zoned contract not created");

        // 2. Set split (40% internal, 60% external) using the correct function
        vm.prank(bot);
        splitter.setContractSplit(40, 60);
        
        // 3. Test ETH distribution
        vm.deal(address(this), TEST_AMOUNT);
        uint256 initialManagedBalance = managedAddress.balance;
        uint256 initialZonedBalance = zonedAddress.balance;
        
        
        splitter.reward{value: TEST_AMOUNT}(address(0), TEST_AMOUNT);
        
        // Verify ETH balances
        assertEq(
            managedAddress.balance - initialManagedBalance,
            (TEST_AMOUNT * 40) / 100,
            "Incorrect ETH amount sent to managed contract"
        );
        assertEq(
            zonedAddress.balance - initialZonedBalance,
            (TEST_AMOUNT * 60) / 100,
            "Incorrect ETH amount sent to zoned contract"
        );

        // 4. Test ERC20 distribution
        // Approve and transfer tokens to splitter
        testToken.approve(address(splitter), TEST_AMOUNT);
        testToken.transfer(address(splitter), TEST_AMOUNT);
        
        // Call reward for ERC20
        splitter.reward(address(testToken), TEST_AMOUNT);
        
        // Verify token balances
        assertEq(
            testToken.balanceOf(managedAddress),
            (TEST_AMOUNT * 40) / 100,
            "Incorrect token amount sent to managed contract"
        );
        assertEq(
            testToken.balanceOf(zonedAddress),
            (TEST_AMOUNT * 60) / 100,
            "Incorrect token amount sent to zoned contract"
        );
    }

    // Helper function to handle ETH transfers
    receive() external payable {}
} 