// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "forge-std/Script.sol";
import "../../src/TestToken.sol"; // Ensure this is the correct path to your token
import "forge-std/console2.sol";

contract SendTestTokenToAddress is Script {
    function run() external {
        // Load private key from .env
        uint256 deployerPrivateKeyHex = vm.envUint("PRIVATE_KEY");
        uint256 deployerPrivateKey = uint256(bytes32(abi.encodePacked(deployerPrivateKeyHex)));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("Deployer address:", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

        // --- CONFIGURATION ---

        // Your deployed token address
        address testTokenAddress = 0x4b15ef62139852D91184D39EB85324D763cf35C9;

        // The hardcoded recipient address (e.g., Holon or other smart contract address)
        address recipientAddress = 0x3F2b1451574200d25318bfFD2C7c68a10bAA4256;

        // Amount to send (adjust decimals based on your token)
        uint256 transferAmount = 1 ether; // assuming 18 decimals

        // --- ACTION ---

        TestToken testToken = TestToken(testTokenAddress);

        console2.log("Sending", transferAmount / 1 ether, "tokens to:", recipientAddress);
        bool success = testToken.transfer(recipientAddress, transferAmount);
        require(success, "Token transfer failed");

        uint256 finalBalance = testToken.balanceOf(recipientAddress);
        console2.log("Recipient balance after transfer:", finalBalance / 1 ether);

        vm.stopBroadcast();
    }
}
