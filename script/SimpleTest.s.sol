// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/AppreciativeFactory.sol";

contract SimpleTest is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the factory
        AppreciativeFactory factory = new AppreciativeFactory();
        console.log("Factory deployed at:", address(factory));

        // Create a new flavor
        factory.newFlavor("Test Flavor", "A test flavor for subgraph testing");
        console.log("New flavor created");

        // Create a new holon
        factory.newHolon("Test Holon", "A test holon for subgraph testing");
        console.log("New holon created");

        vm.stopBroadcast();
    }
}
