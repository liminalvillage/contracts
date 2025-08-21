// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract CheckTokenBalance is Script {
    // Hardcoded variables for the token and account to check
    address constant TOKEN_ADDRESS = 0xf11DA4F41899c5E6437cE32061F27C4580A6586F; // Replace with your token address
    address constant ACCOUNT = 0x1270BAF82a4e177B144E99BbEF12516c69a11218;     // Replace with the account address

    function run() external {
        //////////////////////////////////////////////////////////
        // 1. Optionally start the broadcast
        //    - For read-only calls, this isn't needed
        //////////////////////////////////////////////////////////
        // vm.startBroadcast();

        // 2. Create an interface instance of the ERC-20 token
        IERC20 token = IERC20(TOKEN_ADDRESS);

        // 3. Get the token balance of the specified account
        uint256 rawBalance = token.balanceOf(ACCOUNT);

        // 4. Optionally get the decimals of the token for formatting
        uint8 decimals = token.decimals();

        // 5. Print the raw balance and formatted balance
        console2.log("Token Address:", TOKEN_ADDRESS);
        console2.log("Account Address:", ACCOUNT);
        console2.log("Raw Balance (wei-like):", rawBalance);

        // If the token has decimals, display a human-readable format:
        uint256 formattedBalance = rawBalance / (10 ** decimals);
        console2.log("Formatted Balance (human-readable):", formattedBalance);

        // vm.stopBroadcast();
    }
}