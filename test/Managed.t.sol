// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Managed.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TEST") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ManagedTest is Test {
    Managed public managed;
    TestToken public testToken;
    address public creator = address(this);

    function setUp() public {
        // Deploy the TestToken contract
        testToken = new TestToken();

        // Deploy the Managed contract
        managed = new Managed(creator, "Test Managed");

        // Mint tokens to the contract for testing
        testToken.mint(address(managed), 1e24); // 1,000 TEST tokens
    }

    function testRewardTokenBalanceUpdate() public {
        string memory userId = "user1";
        address tokenAddress = address(testToken);
        uint256 rewardAmount = 1e18; // 1 TEST token

        // Add a member
        managed.addMember(userId);

        // Reward the user
        managed.reward(tokenAddress, rewardAmount);

        // Verify the token balance was updated
        uint256 balance = managed.tokenBalance(userId, tokenAddress);
        assertEq(balance, rewardAmount, "Token balance was not updated correctly");
    }
}
