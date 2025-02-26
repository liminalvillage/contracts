// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {Holons} from "../../src/Holons.sol";
import {ZonedFactory} from "../../src/ZonedFactory.sol";
import {Zoned} from "../../src/Zoned.sol";

contract ZoneCreationTest is Test {
    Holons holons;
    ZonedFactory zonedFactory;
    
    address deployer = address(this);
    string constant CREATOR_ID = "test_user_123";
    string constant HOLON_NAME = "test_holon_456";
    uint constant ZONES_PARAM = 5;

    function setUp() public {
        // Deploy the contracts
        console2.log("Deploying Holons contract...");
        holons = new Holons();
        
        console2.log("Deploying ZonedFactory contract...");
        zonedFactory = new ZonedFactory();
        
        // Register the Zoned flavor
        console2.log("Registering Zoned flavor...");
        holons.newFlavor("Zoned", address(zonedFactory));
        
        console2.log("Zoned flavor registered to:", address(zonedFactory));
    }
    
    function testDirectFactoryCreation() public {
        console2.log("========== Testing direct creation through ZonedFactory ==========");
        
        // Create Zoned directly through factory
        console2.log("Creating Zoned directly through factory...");
        // Fix: Changed to address payable
        address payable zonedAddr;
        try zonedFactory.newHolon(CREATOR_ID, HOLON_NAME, ZONES_PARAM) returns (address addr) {
            // Fix: Cast to payable
            zonedAddr = payable(addr);
            console2.log("Success! Zoned created directly at:", zonedAddr);
            assertTrue(zonedAddr != address(0), "Zoned address should not be zero");
        } catch Error(string memory reason) {
            console2.log("Error creating Zoned directly:", reason);
            fail();
        } catch {
            console2.log("Unknown error in direct creation");
            fail();
        }
        
        // Verify Zoned properties
        if (zonedAddr != address(0)) {
            Zoned zoned = Zoned(zonedAddr);
            console2.log("Zoned properties:");
            console2.log("  Name:", zoned.name());
            console2.log("  Creator:", zoned.creator());
            console2.log("  Flavor:", zoned.flavor());
            console2.log("  Nzones:", zoned.nzones());
        }
    }
    
    function testHolonsCreation() public {
        console2.log("========== Testing creation through Holons contract ==========");
        
        // Create Zoned through Holons
        console2.log("Creating Zoned through Holons...");
        // Fix: Changed to address payable
        address payable zonedAddr;
        try holons.newHolon("Zoned", CREATOR_ID, HOLON_NAME, ZONES_PARAM) returns (address addr) {
            // Fix: Cast to payable
            zonedAddr = payable(addr);
            console2.log("Success! Zoned created through Holons at:", zonedAddr);
            assertTrue(zonedAddr != address(0), "Zoned address should not be zero");
        } catch Error(string memory reason) {
            console2.log("Error creating Zoned through Holons:", reason);
            console2.log("Holons creation failed: ", reason);
            fail();
        } catch {
            console2.log("Unknown error in Holons creation");
            fail();
        }
        
        // Verify through Holons mapping
        address storedAddr = holons.toAddress(HOLON_NAME);
        console2.log("Address from toAddress mapping:", storedAddr);
        assertEq(address(zonedAddr), storedAddr, "Address mismatch in toAddress mapping");
        
        // Verify Zoned properties
        if (zonedAddr != address(0)) {
            Zoned zoned = Zoned(zonedAddr);
            console2.log("Zoned properties:");
            console2.log("  Name:", zoned.name());
            console2.log("  Creator:", zoned.creator());
            console2.log("  Flavor:", zoned.flavor());
            console2.log("  Nzones:", zoned.nzones());
        }
    }
    
    // Add this to verify delegatecall behavior explicitly
    function testDelegateCallInterface() public {
        console2.log("========== Testing delegatecall interface ==========");
        
        // Check function signatures
        bytes4 factorySigHash = bytes4(keccak256("newHolon(string,string,uint256)"));
        bytes4 holonsSigHash = bytes4(keccak256("newHolon(string,string,string,uint256)"));
        
        console2.log("ZonedFactory newHolon signature:", vm.toString(factorySigHash));
        console2.log("Holons newHolon signature:", vm.toString(holonsSigHash));
        
        // Prepare delegatecall data
        bytes memory callData = abi.encodeWithSignature(
            "newHolon(string,string,uint256)", 
            CREATOR_ID, HOLON_NAME, ZONES_PARAM
        );
        
        console2.log("Delegatecall data length:", callData.length);
        
        // Attempt direct delegatecall 
        (bool success, bytes memory result) = address(zonedFactory).delegatecall(callData);
        
        console2.log("Delegatecall result:", success);
        if (success) {
            address addr = abi.decode(result, (address));
            console2.log("Returned address:", addr);
        } else {
            console2.log("Delegatecall failed");
        }
    }
}