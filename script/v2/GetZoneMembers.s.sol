// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

// Interface for the target contract
interface IZoneContract {
    function getZoneMembers(uint256 _zone) external view returns (string[] memory);
}

// Interface for Holons contract if needed
interface IHolons {
    function listHolonsOf(address owner) external view returns (address[] memory);
}

contract GetAllZoneMembersScript is Script {
    uint256 public maxZoneToQuery = 5; // Default max zone to try
    
    function run() public {
        vm.startBroadcast();

        // Get private key from environment variable
        uint256 deployerPrivateKeyHex = vm.envUint("PRIVATE_KEY");
        uint256 deployerPrivateKey = uint256(bytes32(abi.encodePacked(deployerPrivateKeyHex)));
        console2.log("deployerPrivateKey: ", deployerPrivateKey);
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("deployerAddress: ", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);
        
        // Define the Holons contract address - you need to provide this
        address holonsContractAddress = vm.envAddress("HOLONS_CONTRACT_ADDRESS");
        IHolons holons = IHolons(holonsContractAddress);

        // Get holons created by deployer
        address[] memory holonsCreatedByDeployer = holons.listHolonsOf(deployerAddress);
        require(holonsCreatedByDeployer.length > 0, "No Holons created by deployer");

        // Select the first Holon created by the deployer
        address targetContractAddress = holonsCreatedByDeployer[0];
        console2.log("Target Holon address:", targetContractAddress);
        
        // Set up contract interface
        IZoneContract targetContract = IZoneContract(targetContractAddress);
        
        string memory logContent = string.concat(
            "Querying all zones up to: ", vm.toString(maxZoneToQuery), "\n",
            "Target contract: ", vm.toString(targetContractAddress), "\n\n"
        );
        
        // Prepare a JSON string for all zones
        string memory allZonesJson = "{";
        bool firstZone = true;
        
        // Iterate through all zones
        for (uint256 zoneId = 0; zoneId <= maxZoneToQuery; zoneId++) {
            try targetContract.getZoneMembers(zoneId) returns (string[] memory members) {
                if (members.length > 0) {
                    // Log zone info
                    logContent = string.concat(
                        logContent, 
                        "Zone ", vm.toString(zoneId), " has ", 
                        vm.toString(members.length), " members:\n"
                    );
                    
                    // Add to JSON
                    if (!firstZone) {
                        allZonesJson = string.concat(allZonesJson, ", ");
                    }
                    firstZone = false;
                    
                    allZonesJson = string.concat(allZonesJson, "\"", vm.toString(zoneId), "\": [");
                    
                    // Add each member
                    for (uint256 i = 0; i < members.length; i++) {
                        // Log member info
                        logContent = string.concat(
                            logContent,
                            "  Member ", vm.toString(i + 1), ": ", members[i], "\n"
                        );
                        
                        // Add to JSON
                        if (i > 0) {
                            allZonesJson = string.concat(allZonesJson, ", ");
                        }
                        allZonesJson = string.concat(allZonesJson, "\"", members[i], "\"");
                    }
                    
                    allZonesJson = string.concat(allZonesJson, "]");
                    
                    // Also write individual zone file
                    string memory zoneJson = "[";
                    for (uint256 i = 0; i < members.length; i++) {
                        if (i > 0) {
                            zoneJson = string.concat(zoneJson, ", ");
                        }
                        zoneJson = string.concat(zoneJson, "\"", members[i], "\"");
                    }
                    zoneJson = string.concat(zoneJson, "]");
                    
                    string memory outputFile = string.concat("zone_", vm.toString(zoneId), "_members.json");
                    vm.writeFile(outputFile, zoneJson);
                    
                    logContent = string.concat(
                        logContent,
                        "  Results written to ", outputFile, "\n\n"
                    );
                } else {
                    logContent = string.concat(
                        logContent,
                        "Zone ", vm.toString(zoneId), " is empty\n\n"
                    );
                }
            } catch {
                logContent = string.concat(
                    logContent,
                    "Error querying zone ", vm.toString(zoneId), " - might not exist\n\n"
                );
            }
        }
        
        // Close and write the all s JSON
        allZonesJson = string.concat(allZonesJson, "}");
        vm.writeFile("all_zones_members.json", allZonesJson);
        
        logContent = string.concat(
            logContent,
            "All zones data written to all_zones_members.json\n"
        );
        
        // Write the log file
        vm.writeFile("zone_query_log.txt", logContent);
        
        vm.stopBroadcast();
    }
}