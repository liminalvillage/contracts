pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/Splitter.sol";

contract CheckChildHolons is Script {
    function run() external view {
        address myContractAddr = vm.envAddress("MY_CONTRACT_ADDRESS");
        Splitter myContract = Splitter(payable(myContractAddr));


        string memory typeNameManaged = "TestBundle_managed";
        string memory typeNameZoned = "TestBundle_zoned";

        // string memory typeNameManaged = "chat_4687987074_managed";
        // string memory typeNameZoned = "chat_4687987074_zoned";

        address resolvedManaged = myContract.contractsByType(typeNameManaged);
        address resolvedZoned = myContract.contractsByType(typeNameZoned);

        console.log("Contract for", typeNameManaged, "is", resolvedManaged);
        console.log("Contract for", typeNameZoned, "is", resolvedZoned);
    }
}
