// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../../src/TestToken.sol";
import "forge-std/console2.sol";

contract CheckTokenBalance is Script {
    function run() external view {
        // Load the address to check from environment or hardcode
        address targetAddress = 0xc98fe3E9bA496dF012bcC19eeE92De3f0fd17A39;

        // Deployed ERC20 token address
        address tokenAddress = 0x4b15ef62139852D91184D39EB85324D763cf35C9;

        // Attach to the token
        TestToken token = TestToken(tokenAddress);

        // Fetch balance
        uint256 balance = token.balanceOf(targetAddress);

        console2.log("Token balance of address:");
        console2.log(targetAddress);
        console2.log("is:");
        console2.log(balance / 1 ether);

    }
}