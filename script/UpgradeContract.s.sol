// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/ManagedUpgradeable.sol";
import "../src/ZonedUpgradeable.sol";
import "../src/SplitterUpgradeable.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";

/**
 * @title UpgradeContract
 * @notice Script to upgrade UUPS proxy contracts to new implementations
 * @dev This script demonstrates how to:
 *      1. Deploy a new implementation contract
 *      2. Upgrade an existing proxy to point to the new implementation
 *      3. Verify the upgrade was successful
 *
 * Usage:
 *   forge script script/UpgradeContract.s.sol:UpgradeContract --rpc-url <RPC_URL> --broadcast
 *
 * Environment Variables Required:
 *   PRIVATE_KEY - Private key of the contract owner (has upgrade rights)
 *   PROXY_ADDRESS - Address of the proxy contract to upgrade
 *   CONTRACT_TYPE - Type of contract (managed, zoned, or splitter)
 */
contract UpgradeContract is Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get the proxy address to upgrade
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        string memory contractType = vm.envString("CONTRACT_TYPE");

        console.log("=================================");
        console.log("Upgrading UUPS Proxy Contract");
        console.log("=================================");
        console.log("Upgrader:", deployer);
        console.log("Proxy Address:", proxyAddress);
        console.log("Contract Type:", contractType);
        console.log("");

        // Get current implementation before upgrade
        bytes32 implementationSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        address oldImplementation = address(uint160(uint256(vm.load(proxyAddress, implementationSlot))));
        console.log("Current Implementation:", oldImplementation);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation based on contract type
        address newImplementation;

        if (keccak256(abi.encodePacked(contractType)) == keccak256(abi.encodePacked("managed"))) {
            console.log("Deploying new ManagedUpgradeable implementation...");
            ManagedUpgradeable newImpl = new ManagedUpgradeable();
            newImplementation = address(newImpl);

        } else if (keccak256(abi.encodePacked(contractType)) == keccak256(abi.encodePacked("zoned"))) {
            console.log("Deploying new ZonedUpgradeable implementation...");
            ZonedUpgradeable newImpl = new ZonedUpgradeable();
            newImplementation = address(newImpl);

        } else if (keccak256(abi.encodePacked(contractType)) == keccak256(abi.encodePacked("splitter"))) {
            console.log("Deploying new SplitterUpgradeable implementation...");
            SplitterUpgradeable newImpl = new SplitterUpgradeable();
            newImplementation = address(newImpl);

        } else {
            revert("Invalid contract type. Use: managed, zoned, or splitter");
        }

        console.log("New Implementation deployed at:", newImplementation);
        console.log("");

        // Perform the upgrade
        console.log("Performing upgrade...");

        // Call upgradeToAndCall on the proxy (using the UUPS pattern)
        // Since we're not adding initialization logic, we pass empty bytes
        (bool success, ) = proxyAddress.call(
            abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImplementation, "")
        );

        require(success, "Upgrade failed");

        vm.stopBroadcast();

        // Verify the upgrade
        address currentImplementation = address(uint160(uint256(vm.load(proxyAddress, implementationSlot))));

        console.log("=================================");
        console.log("Upgrade Complete!");
        console.log("=================================");
        console.log("Proxy Address:", proxyAddress);
        console.log("Old Implementation:", oldImplementation);
        console.log("New Implementation:", newImplementation);
        console.log("Current Implementation:", currentImplementation);
        console.log("");

        if (currentImplementation == newImplementation) {
            console.log("SUCCESS: Upgrade verified!");
        } else {
            console.log("WARNING: Upgrade verification failed!");
        }
        console.log("=================================");
    }
}
