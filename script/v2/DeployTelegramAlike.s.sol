// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import {SplitterFactory} from "../../src/SplitterFactory.sol";
import {AppreciativeFactory} from "../../src/AppreciativeFactory.sol";
import {ZonedFactory} from "../../src/ZonedFactory.sol";
import {ManagedFactory} from "../../src/ManagedFactory.sol";
import {Managed} from "../../src/Managed.sol";
import {Holons} from "../../src/Holons.sol";
import {Zoned} from "../../src/Zoned.sol";
import {Splitter} from "../../src/Splitter.sol";
import {TestToken} from "../../src/TestToken.sol";

contract DeployTelegramAlike is Script {
    // Deployment container to store all addresses
    struct DeploymentContainer {
        // Main registry
        Holons holons;
        
        // Factories
        ManagedFactory managedFlavor;
        AppreciativeFactory appreciativeFlavor;
        SplitterFactory splitterFlavor;
        ZonedFactory zonedFlavor;
        
        // Deployed instances
        address managedInstance;
        address appreciativeInstance;
        address splitterInstance;
        address zonedInstance;
        
        // Test token
        TestToken testToken;
    }
    
    DeploymentContainer public dc;

    function run() external {
        // Start the broadcast using the deployer's private key
        uint256 deployerPrivateKeyHex = vm.envUint("PRIVATE_KEY");
        uint256 deployerPrivateKey = uint256(bytes32(abi.encodePacked(deployerPrivateKeyHex)));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("Deployer: ", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

        // STEP 1: Deploy all factories and the Holons registry
        deployFactoriesAndRegistry();
        
        // STEP 2: Register all flavors with the Holons registry
        registerFlavors();
        
        // STEP 3: Create instances of each holon type through the registry
        createHolonInstances();

        vm.stopBroadcast();
        
        // Print all deployment addresses for reference
        printDeploymentAddresses();
    }
    
    function deployFactoriesAndRegistry() internal {
        // Deploy Holons registry first
        console2.log("Deploying Holons registry...");
        dc.holons = new Holons();
        console2.log("Holons registry deployed at:", address(dc.holons));
        
        // Deploy all factories
        console2.log("Deploying ManagedFactory...");
        dc.managedFlavor = new ManagedFactory();
        console2.log("ManagedFactory deployed at:", address(dc.managedFlavor));
        
        console2.log("Deploying AppreciativeFactory...");
        dc.appreciativeFlavor = new AppreciativeFactory();
        console2.log("AppreciativeFactory deployed at:", address(dc.appreciativeFlavor));
        
        console2.log("Deploying SplitterFactory...");
        dc.splitterFlavor = new SplitterFactory();
        console2.log("SplitterFactory deployed at:", address(dc.splitterFlavor));
        
        console2.log("Deploying ZonedFactory...");
        dc.zonedFlavor = new ZonedFactory();
        console2.log("ZonedFactory deployed at:", address(dc.zonedFlavor));
        
        // Deploy TestToken
        console2.log("Deploying TestToken...");
        dc.testToken = new TestToken(1_000_000 ether);
        console2.log("TestToken deployed at:", address(dc.testToken));
    }
    
    function registerFlavors() internal {
        console2.log("Registering flavors with Holons registry...");
        
        // Register all flavors with proper case as in your example
        dc.holons.newFlavor("managed", address(dc.managedFlavor));
        dc.holons.newFlavor("appreciative", address(dc.appreciativeFlavor));
        dc.holons.newFlavor("splitter", address(dc.splitterFlavor));
        dc.holons.newFlavor("zoned", address(dc.zonedFlavor));
        
        console2.log("All flavors registered successfully");
    }
    
    function createHolonInstances() internal {
        console2.log("Creating holon instances through Holons registry...");
        
        // Create a Managed holon instance
        console2.log("Creating Managed holon...");
        dc.managedInstance = dc.holons.newHolon("managed", "deployer_id", "ManagedHolon1", 1000);
        console2.log("Managed holon created at:", dc.managedInstance);
        
        // Create an Appreciative holon instance
        console2.log("Creating Appreciative holon...");
        dc.appreciativeInstance = dc.holons.newHolon("appreciative", "deployer_id", "AppreciativeHolon1", 500);
        console2.log("Appreciative holon created at:", dc.appreciativeInstance);
        
        // Create a Splitter holon instance
        console2.log("Creating Splitter holon...");
        dc.splitterInstance = dc.holons.newHolon("splitter", "deployer_id", "SplitterHolon1", 100);
        console2.log("Splitter holon created at:", dc.splitterInstance);
        
        // Create a Zoned holon instance
        console2.log("Creating Zoned holon...");
        dc.zonedInstance = dc.holons.newHolon("zoned", "deployer_id", "ZonedHolon1", 2);
        console2.log("Zoned holon created at:", dc.zonedInstance);
    }
    
    function printDeploymentAddresses() internal view {
        console2.log("\n--- DEPLOYMENT SUMMARY ---");
        console2.log("Holons Registry:      ", address(dc.holons));
        console2.log("\nFactories:");
        console2.log("ManagedFactory:      ", address(dc.managedFlavor));
        console2.log("AppreciativeFactory: ", address(dc.appreciativeFlavor));
        console2.log("SplitterFactory:     ", address(dc.splitterFlavor));
        console2.log("ZonedFactory:        ", address(dc.zonedFlavor));
        console2.log("\nHolon Instances:");
        console2.log("Managed Instance:    ", dc.managedInstance);
        console2.log("Appreciative Instance:", dc.appreciativeInstance);
        console2.log("Splitter Instance:   ", dc.splitterInstance);
        console2.log("Zoned Instance:      ", dc.zonedInstance);
        console2.log("\nOther Contracts:");
        console2.log("TestToken:           ", address(dc.testToken));
        console2.log("-----------------------\n");
    }
}