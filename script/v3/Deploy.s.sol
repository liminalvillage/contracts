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
import "openzeppelin-contracts/contracts/utils/Strings.sol";

contract Deploy is Script {
    using Strings for string;
    
    function run() external {
        // Start the broadcast using the deployer's private key
        uint256 deployerPrivateKeyHex = vm.envUint("PRIVATE_KEY");
        uint256 deployerPrivateKey = uint256(bytes32(abi.encodePacked(deployerPrivateKeyHex)));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("Deployer: ", deployerAddress);
        console2.log("deployerPrivateKey: ", deployerPrivateKey);

        // Deploy factories first
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("Deploying ManagedFactory...");
        ManagedFactory managedFactory = new ManagedFactory();
        console2.log("ManagedFactory deployed at:", address(managedFactory));

        console2.log("Deploying ZonedFactory...");
        ZonedFactory zonedFactory = new ZonedFactory();
        console2.log("ZonedFactory deployed at:", address(zonedFactory));

        console2.log("Deploying SplitterFactory...");
        SplitterFactory splitterFactory = new SplitterFactory();
        console2.log("SplitterFactory deployed at:", address(splitterFactory));

        console2.log("Deploying AppreciativeFactory...");
        AppreciativeFactory appreciativeFactory = new AppreciativeFactory();
        console2.log("AppreciativeFactory deployed at:", address(appreciativeFactory));
        
        vm.stopBroadcast();

        // Deploy main contracts
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("Deploying Holons...");
        Holons holons = new Holons();
        console2.log("Holons deployed at:", address(holons));

        console2.log("Deploying Managed...");
        Managed managed = new Managed(msg.sender, "Managed");
        console2.log("Managed deployed at:", address(managed));

        console2.log("Deploying Zoned...");
        Zoned zoned = new Zoned("creatorUserId", msg.sender,"5", 1);
        console2.log("Zoned deployed at:", address(zoned));

        console2.log("Deploying Splitter...");
        Splitter splitter = new Splitter(msg.sender, "creatorUserId", "Splitter", 1, address(managedFactory), address(zonedFactory));
        console2.log("Splitter deployed at:", address(splitter));

        console2.log("Deploying TestToken...");
        TestToken testToken = new TestToken(1_000_000 ether);
        console2.log("TestToken deployed at:", address(testToken));
        
        vm.stopBroadcast();

        // Set factories and flavors
        vm.startBroadcast(deployerPrivateKey);
        
        // Set factories in Holons
        holons.setFactories(address(managedFactory), address(zonedFactory));
        
        // Set flavors in Holons contract
        console2.log("Setting Splitter flavor...");
        holons.newFlavor("Splitter", address(splitterFactory));
        console2.log("Splitter flavor set to:", address(splitterFactory));

        console2.log("Setting Appreciative flavor...");
        holons.newFlavor("Appreciative", address(appreciativeFactory));
        console2.log("Appreciative flavor set to:", address(appreciativeFactory));

        console2.log("Setting Zoned flavor...");
        holons.newFlavor("Zoned", address(zonedFactory));
        console2.log("Zoned flavor set to:", address(zonedFactory));

        console2.log("Setting Managed flavor...");
        holons.newFlavor("Managed", address(managedFactory));
        console2.log("Managed flavor set to:", address(managedFactory));
        
        vm.stopBroadcast();

        // Test interactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Verify the child contracts are set correctly
        // Test creating a holon bundle
        console2.log("Creating a test holon bundle...");
        address bundleAddress = holons.newHolonBundle("testUser", "TestBundle", 5);
        console2.log("Bundle address:", bundleAddress);

        // Verify the mapping is updated
        address mappedAddress = holons.toAddress("TestBundle");
        console2.log("Address from Holons mapping:", mappedAddress);
        
        // Verify the child contracts are set correctly using the full names
        console2.log("Verifying child contracts in Splitter...");
        Splitter bundleSplitter = Splitter(payable(bundleAddress));
        
        bundleSplitter.createManagedContract("testUser", "TestBundle", 5);
        bundleSplitter.createZonedContract("testUser", "TestBundle", 5);
        
        address managedContract = bundleSplitter.contractsByType(string.concat("TestBundle", "_managed"));
        address zonedContract = bundleSplitter.contractsByType(string.concat("TestBundle", "_zoned"));

        console2.log("Managed contract address:", managedContract);
        console2.log("Zoned contract address:", zonedContract);

        vm.stopBroadcast();
    }
}