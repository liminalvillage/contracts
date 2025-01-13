// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

contract CheckEthBalance is Script {
    // Hardcoded variables for the account to check
    address constant ACCOUNT = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // Replace with the account address

    function run() external {
        //////////////////////////////////////////////////////////
        // 1. Optionally start the broadcast
        //    - For read-only calls, this isn't needed
        //////////////////////////////////////////////////////////
        // vm.startBroadcast();

        // 2. Get the Ether balance of the specified account
        uint256 rawBalance = ACCOUNT.balance;

        // 3. Print the raw balance and formatted balance
        console2.log("Account Address:", ACCOUNT);
        console2.log("Raw Balance (wei):", rawBalance);

        // Convert the balance to Ether (human-readable format)
        uint256 formattedBalance = rawBalance / 1 ether;
        console2.log("Formatted Balance (ETH):", formattedBalance);

        // vm.stopBroadcast();
    }
}
