// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import {SplitterFactory} from "../../src/SplitterFactory.sol";
import {AppreciativeFactory} from "../../src/AppreciativeFactory.sol";
import {ZonedFactory} from "../../src/ZonedFactory.sol";
import {ManagedFactory} from "../../src/ManagedFactory.sol";
import {Holons} from "../../src/Holons.sol";
import {TestToken} from "../../src/TestToken.sol";

contract DeployMinimal is Script {
    function run() external {
        // Start the broadcast using the deployer's private key
        uint256 deployerPrivateKeyHex = vm.envUint("PRIVATE_KEY");
        uint256 deployerPrivateKey = uint256(bytes32(abi.encodePacked(deployerPrivateKeyHex)));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("Deployer: ", deployerAddress);

        // Deploy only the essential contracts
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("Deploying Holons...");
        Holons holons = new Holons();
        console2.log("Holons deployed at:", address(holons));

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

        console2.log("Deploying TestToken...");
        TestToken testToken = new TestToken(1_000_000 ether);
        console2.log("TestToken deployed at:", address(testToken));
        
        vm.stopBroadcast();

        // Set factories and flavors in separate transaction
        vm.startBroadcast(deployerPrivateKey);
        
        // Set factories in Holons
        holons.setFactories(address(managedFactory), address(zonedFactory));
        
        // Set flavors in Holons contract
        holons.newFlavor("Splitter", address(splitterFactory));
        holons.newFlavor("Appreciative", address(appreciativeFactory));
        holons.newFlavor("Zoned", address(zonedFactory));
        holons.newFlavor("Managed", address(managedFactory));
        
        vm.stopBroadcast();
    }
} 