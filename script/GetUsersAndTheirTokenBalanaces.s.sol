// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Foundry imports
import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/Holons.sol";
// Your contract import
import "../src/Managed.sol";

contract GetUsersAndTheirTokenBalanaces is Script {
    function setUp() public {
        // Optionally configure things if needed before run()
    }

    function run() external {
        // This tells Foundry we are ready to send transactions

        // Derive deployer's address properly
        uint256 deployerPrivateKeyHex = vm.envUint("PRIVATE_KEY");
        uint256 deployerPrivateKey = uint256(bytes32(abi.encodePacked(deployerPrivateKeyHex)));
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast();

        // -----------------------------
        // 1. Instantiate the contract
        // -----------------------------
        // address holonsContractAddress = 0x295129609d6876f5ECC62052Ba6bc082139A982c;
        // require(holonsContractAddress != address(0), "Invalid Holons contract address");

        // Holons holons = Holons(holonsContractAddress);
        // address[] memory holonsCreatedByDeployer = holons.listHolonsOf(deployerAddress);
        // require(holonsCreatedByDeployer.length > 0, "No Holons created by deployer");

        // // Select the first Holon created by the deployer
        // address payable targetHolonAddress = holonsCreatedByDeployer[0];
        // console2.log("Target Holon address:", targetHolonAddress);

        // // Replace with the actual deployed address
        // Managed managed = Managed(targetHolonAddress);

        // Replace with the actual deployed address
        address payable managedContractAddress = payable(0xa6d2E0f6E25DC354b3b29A25fC2874D3F6bcdeC6);
        Managed managed = Managed(managedContractAddress);

        // -------------------------------------------------
        // 2. Retrieve number of users from the contract
        // -------------------------------------------------
        uint256 size = managed.getSize();
        console2.log("Total number of users in the contract:", size);

        // ---------------------------------------
        // 3. For each user, retrieve and log info
        // ---------------------------------------
        for (uint256 i = 0; i < size; i++) {
            // Foundry automatically generates a getter for `userIds`
            string memory userId = managed.userIds(i);
            console2.log("User ID:", userId);

            // ----------------------------------------------------
            // 4. Get the token addresses associated with this user
            // ----------------------------------------------------
            address[] memory userTokens = managed.getTokensOf(userId);

            if (userTokens.length == 0) {
                console2.log("  No tokens found for this user.");
            } else {
                for (uint256 j = 0; j < userTokens.length; j++) {
                    address tokenAddr = userTokens[j];
                    
                    // -------------------------------------------------
                    // 5. Query tokenBalance for each token
                    // -------------------------------------------------
                    uint256 balance = managed.tokenBalance(userId, tokenAddr);
                    
                    console2.log("  Token address:", tokenAddr);
                    console2.log("  Token balance:", balance);
                }
            }
        }

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
