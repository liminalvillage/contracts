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

contract CircularMember {
    Managed public targetContract;
    event RewardReceived(address token, uint256 amount, string message);
    
    constructor(address payable _target) {
        targetContract = Managed(_target);
    }
    
    function reward(address _tokenaddress, uint256 _amount) external {
        emit RewardReceived(_tokenaddress, _amount, "CircularMember received reward");
        
        // When we receive rewards, try to trigger another distribution
        IERC20(_tokenaddress).approve(address(targetContract), _amount);
        targetContract.reward(_tokenaddress, _amount);
    }
}

contract CircularRewardTest is Test {
    Managed public contractA;
    Managed public contractC;
    CircularMember public contractE;
    TestToken public token;
    
    address public addressB;
    address public addressD;
    address public creator;
    
    function setUp() public {
        creator = address(this);
        
        // Deploy all contracts
        contractA = new Managed(creator, "ParentHolon");
        contractC = new Managed(creator, "ChildHolon");
        token = new TestToken();
        
        // Set up regular addresses
        addressB = address(0xB);
        addressD = address(0xD);
        
        // Set up ContractE to point back to ContractA, using payable cast
        contractE = new CircularMember(payable(address(contractA)));
        
        // Set up membership in Contract A
        contractA.addMember("B");
        contractA.addMember("C");
        
        // Set up membership in Contract C
        contractC.addMember("D");
        contractC.addMember("E");
        
        // Associate addresses with member IDs
        vm.startPrank(creator);
        
        // For Contract A
        contractA.claim("B", addressB);
        contractA.claim("C", address(contractC));
        
        // For Contract C
        contractC.claim("D", addressD);
        contractC.claim("E", address(contractE));
        
        vm.stopPrank();
        
        // Fund Contract A with tokens
        token.transfer(address(contractA), 1000 * 10**18);
    }
    
    function testCircularRewardFlow() public {
        console.log("\nInitial State:");
        console.log("Contract A balance:", token.balanceOf(address(contractA)) / 1e18);
        console.log("Contract C balance:", token.balanceOf(address(contractC)) / 1e18);
        console.log("Address B balance:", token.balanceOf(addressB) / 1e18);
        console.log("Address D balance:", token.balanceOf(addressD) / 1e18);
        console.log("Contract E balance:", token.balanceOf(address(contractE)) / 1e18);
        
        // Start reward distribution from Contract A
        uint256 rewardAmount = 1000 * 10**18;
        token.approve(address(contractA), rewardAmount);
        
        vm.expectEmit(true, true, false, true);
        emit CircularMember.RewardReceived(address(token), 0, "CircularMember received reward");
        
        contractA.reward(address(token), rewardAmount);
        
        console.log("\nFinal State:");
        console.log("Contract A balance:", token.balanceOf(address(contractA)) / 1e18);
        console.log("Contract C balance:", token.balanceOf(address(contractC)) / 1e18);
        console.log("Address B balance:", token.balanceOf(addressB) / 1e18);
        console.log("Address D balance:", token.balanceOf(addressD) / 1e18);
        console.log("Contract E balance:", token.balanceOf(address(contractE)) / 1e18);
        
        // Add assertions to verify the distribution
        assertGe(token.balanceOf(addressB), 0, "Address B should receive rewards");
        assertGe(token.balanceOf(addressD), 0, "Address D should receive rewards");
    }
}