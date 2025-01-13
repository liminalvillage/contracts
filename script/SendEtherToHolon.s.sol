// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/Holons.sol"; // Adjust the path based on your directory structure

contract SendEtherToHolon is Script {
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

        // Initialize the Holons contract
        Holons holons = Holons(holonsContractAddress);
        console2.log("Holons contract address:", holonsContractAddress);

        // Validate deployment by listing Holons
        address[] memory holonsCreatedByDeployer = holons.listHolonsOf(deployerAddress);
        require(holonsCreatedByDeployer.length > 0, "No Holons created by deployer");

        // Select the first Holon created by the deployer
        address targetHolonAddress = holonsCreatedByDeployer[0];
        console2.log("Target Holon address:", targetHolonAddress);

        // Amount of Ether to transfer
        uint256 transferAmount = 1 ether; // Adjust the amount as needed
        console2.log("Attempting to transfer", transferAmount / 1 ether, "ETH to Holon...");

        // Send Ether to the Holon
        (bool success, ) = targetHolonAddress.call{value: transferAmount}("");
        require(success, "Ether transfer to Holon failed");
        console2.log("Successfully transferred", transferAmount / 1 ether, "ETH to Holon at:", targetHolonAddress);

        vm.stopBroadcast();
    }

    // Allow the contract to receive Ether
    receive() external payable {}
}
