// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/Holons.sol"; // Adjust the path based on your directory structure
import "../src/TestToken.sol";

contract SendTestTokenToHolon is Script {
    function run() external {

        // Derive deployer's address properly
        uint256 deployerPrivateKeyHex = vm.envUint("PRIVATE_KEY");
        uint256 deployerPrivateKey = uint256(bytes32(abi.encodePacked(deployerPrivateKeyHex)));
        console2.log("deployerPrivateKey: ", deployerPrivateKey);
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("deployerAddress: ", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Address of the deployed Holons contract
        address holonsContractAddress = 0x23228469b3439d81DC64e3523068976201bA08C3;
        require(holonsContractAddress != address(0), "Invalid Holons contract address");

        // Address of the deployed TestToken contract
        address testTokenAddress = 0x2ca60d89144D4cdf85dA87af4FE12aBF9265F28C; // Replace with actual address
        require(testTokenAddress != address(0), "Invalid TestToken contract address");

        // Initialize the Holons contract
        Holons holons = Holons(holonsContractAddress);
        console2.log("Holons contract address:", holonsContractAddress);

        // Initialize the TestToken contract
        TestToken testToken = TestToken(testTokenAddress);
        console2.log("TestToken contract address:", testTokenAddress);

        // Validate deployment by listing Holons
        address[] memory holonsCreatedByDeployer = holons.listHolonsOf(deployerAddress);
        require(holonsCreatedByDeployer.length > 0, "No Holons created by deployer");

        // Select the first Holon created by the deployer
        address targetHolonAddress = holonsCreatedByDeployer[0];
        console2.log("Target Holon address:", targetHolonAddress);

        // // Transfer tokens to the Holon
        uint256 transferAmount = 1_000 ether; // Amount to transfer
        console2.log("Attempting to transfer", transferAmount / 1 ether, "tokens to Holon...");

        bool success = testToken.transfer(targetHolonAddress, transferAmount);
        require(success, "Token transfer to Holon failed");
        console2.log("Successfully transferred", transferAmount / 1 ether, "tokens to Holon at:", targetHolonAddress);

        // Check token balance in the Holon
        uint256 holonBalance = testToken.balanceOf(targetHolonAddress);
        console2.log("Holon token balance after transfer:", holonBalance / 1 ether);

        vm.stopBroadcast();
    }
}
