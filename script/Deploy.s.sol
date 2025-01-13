// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import {SplitterFactory} from "../src/SplitterFactory.sol";
import {AppreciativeFactory} from "../src/AppreciativeFactory.sol";
import {ZonedFactory} from "../src/ZonedFactory.sol";
import {ManagedFactory} from "../src/ManagedFactory.sol";
import {Managed} from "../src/Managed.sol";
import {Holons} from "../src/Holons.sol";
import {Zoned} from "../src/Zoned.sol";
import {Splitter} from "../src/Splitter.sol";
import {TestToken} from "../src/TestToken.sol";

contract Deploy is Script {
    function run() external {
        // Start the broadcast using the deployer's private key
        uint256 deployerPrivateKeyHex = vm.envUint("PRIVATE_KEY");
        uint256 deployerPrivateKey = uint256(bytes32(abi.encodePacked(deployerPrivateKeyHex)));
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("Deployer: ", deployerAddress);
        console2.log("deployerPrivateKey: ", deployerPrivateKey);


        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        console2.log("Deploying SplitterFactory...");
        SplitterFactory splitterFactory = new SplitterFactory();
        console2.log("SplitterFactory deployed at:", address(splitterFactory));

        console2.log("Deploying AppreciativeFactory...");
        AppreciativeFactory appreciativeFactory = new AppreciativeFactory();
        console2.log("AppreciativeFactory deployed at:", address(appreciativeFactory));

        console2.log("Deploying ZonedFactory...");
        ZonedFactory zonedFactory = new ZonedFactory();
        console2.log("ZonedFactory deployed at:", address(zonedFactory));

        console2.log("Deploying ManagedFactory...");
        ManagedFactory managedFactory = new ManagedFactory();
        console2.log("ManagedFactory deployed at:", address(managedFactory));

        console2.log("Deploying Managed...");
        Managed managed = new Managed(msg.sender, "Managed");
        console2.log("Managed deployed at:", address(managed));

        console2.log("Deploying Holons...");
        Holons holons = new Holons();
        console2.log("Holons deployed at:", address(holons));

        console2.log("Deploying Zoned...");
        Zoned zoned = new Zoned(msg.sender,"5", 1);
        console2.log("Zoned deployed at:", address(zoned));

        console2.log("Deploying Splitter...");
        Splitter splitter = new Splitter(msg.sender, "Splitter", 1);
        console2.log("Splitter deployed at:", address(splitter));

        console2.log("Deploying TestToken...");
        TestToken testToken = new TestToken(1_000_000 ether);
        console2.log("TestToken deployed at:", address(testToken));
        
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
    }
}

