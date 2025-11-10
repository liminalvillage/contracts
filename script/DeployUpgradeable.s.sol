// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/ManagedUpgradeable.sol";
import "../src/ZonedUpgradeable.sol";
import "../src/SplitterUpgradeable.sol";
import "../src/ManagedFactoryUpgradeable.sol";
import "../src/ZonedFactoryUpgradeable.sol";
import "../src/SplitterFactoryUpgradeable.sol";

/**
 * @title DeployUpgradeable
 * @notice Deployment script for upgradeable Holon contracts using UUPS proxy pattern
 * @dev This script deploys:
 *      1. Implementation contracts (logic)
 *      2. Factory contracts (which deploy proxies)
 *      3. Example proxy instances for testing
 *
 * Usage:
 *   forge script script/DeployUpgradeable.s.sol:DeployUpgradeable --rpc-url <RPC_URL> --broadcast
 */
contract DeployUpgradeable is Script {

    // Implementation addresses (logic contracts)
    address public managedImplementation;
    address public zonedImplementation;
    address public splitterImplementation;

    // Factory addresses
    address public managedFactory;
    address public zonedFactory;
    address public splitterFactory;

    // Example proxy instances
    address public managedProxy;
    address public zonedProxy;
    address public splitterProxy;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=================================");
        console.log("Deploying Upgradeable Holon Contracts");
        console.log("=================================");
        console.log("Deployer:", deployer);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // ==========================================
        // STEP 1: Deploy Implementation Contracts
        // ==========================================
        console.log("Step 1: Deploying Implementation Contracts...");

        managedImplementation = address(new ManagedUpgradeable());
        console.log("  ManagedUpgradeable implementation:", managedImplementation);

        zonedImplementation = address(new ZonedUpgradeable());
        console.log("  ZonedUpgradeable implementation:", zonedImplementation);

        splitterImplementation = address(new SplitterUpgradeable());
        console.log("  SplitterUpgradeable implementation:", splitterImplementation);
        console.log("");

        // ==========================================
        // STEP 2: Deploy Factory Contracts
        // ==========================================
        console.log("Step 2: Deploying Factory Contracts...");

        ManagedFactoryUpgradeable managedFactoryContract = new ManagedFactoryUpgradeable(managedImplementation);
        managedFactory = address(managedFactoryContract);
        console.log("  ManagedFactoryUpgradeable:", managedFactory);

        ZonedFactoryUpgradeable zonedFactoryContract = new ZonedFactoryUpgradeable(zonedImplementation);
        zonedFactory = address(zonedFactoryContract);
        console.log("  ZonedFactoryUpgradeable:", zonedFactory);

        SplitterFactoryUpgradeable splitterFactoryContract = new SplitterFactoryUpgradeable(splitterImplementation);
        splitterFactory = address(splitterFactoryContract);
        console.log("  SplitterFactoryUpgradeable:", splitterFactory);

        // Set factory references in SplitterFactory
        splitterFactoryContract.setFactories(managedFactory, zonedFactory);
        console.log("  Set factories in SplitterFactory");
        console.log("");

        // ==========================================
        // STEP 3: Deploy Example Proxy Instances
        // ==========================================
        console.log("Step 3: Deploying Example Proxy Instances...");

        // Deploy example Managed proxy
        managedProxy = managedFactoryContract.createManaged(
            "creator_123",
            "ExampleManaged"
        );
        console.log("  Example ManagedUpgradeable proxy:", managedProxy);

        // Deploy example Zoned proxy with 6 zones
        zonedProxy = zonedFactoryContract.createZoned(
            "creator_123",
            "ExampleZoned",
            6
        );
        console.log("  Example ZonedUpgradeable proxy:", zonedProxy);

        // Deploy example Splitter proxy
        splitterProxy = splitterFactoryContract.createSplitter(
            "creator_123",
            "ExampleSplitter",
            0,
            managedFactory,
            zonedFactory
        );
        console.log("  Example SplitterUpgradeable proxy:", splitterProxy);
        console.log("");

        vm.stopBroadcast();

        // ==========================================
        // STEP 4: Summary
        // ==========================================
        console.log("=================================");
        console.log("Deployment Complete!");
        console.log("=================================");
        console.log("");
        console.log("IMPLEMENTATION CONTRACTS (Logic):");
        console.log("  ManagedUpgradeable:", managedImplementation);
        console.log("  ZonedUpgradeable:", zonedImplementation);
        console.log("  SplitterUpgradeable:", splitterImplementation);
        console.log("");
        console.log("FACTORY CONTRACTS:");
        console.log("  ManagedFactoryUpgradeable:", managedFactory);
        console.log("  ZonedFactoryUpgradeable:", zonedFactory);
        console.log("  SplitterFactoryUpgradeable:", splitterFactory);
        console.log("");
        console.log("EXAMPLE PROXY INSTANCES:");
        console.log("  ManagedUpgradeable proxy:", managedProxy);
        console.log("  ZonedUpgradeable proxy:", zonedProxy);
        console.log("  SplitterUpgradeable proxy:", splitterProxy);
        console.log("");
        console.log("IMPORTANT NOTES:");
        console.log("  - All proxies use UUPS pattern");
        console.log("  - Only contract owner can upgrade");
        console.log("  - Data is stored in proxy, logic in implementation");
        console.log("  - To upgrade: deploy new implementation, call upgradeTo()");
        console.log("=================================");
    }
}
