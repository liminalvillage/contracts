// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "./ZonedFactory.sol";
// import "openzeppelin/contracts/access/Ownable.sol";

/*
    Copyright 2020, Roberto Valenti

    This program is free software: you can use it, redistribute it and/or modify
    it under the terms of the Peer Production License as published by
    the P2P Foundation.
    
    https://wiki.p2pfoundation.net/Peer_Production_License

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    Peer Production License for more details.
 */
import "./IHolonFactory.sol";
import "./Holon.sol";
import "./ManagedFactory.sol";
import "forge-std/console.sol";


contract Splitter is Holon {
    using Strings for string;
   
    //#TODO: Modularize this ( into Membrane ), as it will become the same for most of the contracts
    string[] public userIds; // list of userIds
    mapping(string => address) public userIdToAddress; // mapping for userIds to addresses
    mapping(string => bool) public hasClaimed; // mapping to track if userId has already claimed
    mapping(string => bool) public isSplitterMember; // mapping to track if userId has already claimed
    mapping(string => uint256) public etherBalance; // storage for Ether by userID
    mapping(string => mapping(address => uint256)) public tokenBalance; // storage for ERC20 by userID
    mapping(string => address[]) public tokensOf; // list of received tokens for a specific userID
    mapping(address => uint256) public totalDeposited; // total amount of tokens deposited in the contract
    mapping(string => uint) public percentages;
    //#TODO: Modularize this ( into Membrane ), as it will become the same for most of the contracts
    address public botAddress;
    // string public flavor;
    address public managedFactory;
    address public zonedFactory;
    string public creatorUserId;

    // have a way to find apporpriate contracts ( Managed or Zoned currently ) by their names - chat.id + "_managed"
    mapping(string => address) public contractsByType;

    // New contract-based split storage
    uint public internalContractSplitPercentage;
    uint public externalContractSplitPercentage;

    // Add these at the top of the contract with other state variables
    string[] private contractKeys;  // Array to store all contract keys
    mapping(string => bool) private isKeyAdded;  // To track if a key is already in the array

    event FundsForwarded(address, address, uint256);
    event ChildHolonCreated(address indexed childAddress, string indexed childType, string name);


constructor(
    address _owner,
    string memory _creatorUserId,
    string memory _name,
    uint _parameter,
    address _managedFactory,
    address _zonedFactory
) {
    console.log("Splitter.constructor: ENTRY");
    console.log("Splitter.constructor: Owner:", _owner);
    console.log("Splitter.constructor: Creator:", _creatorUserId);
    console.log("Splitter.constructor: Name:", _name);
    console.log("Splitter.constructor: Parameter:", _parameter);
    console.log("Splitter.constructor: ManagedFactory:", _managedFactory);
    console.log("Splitter.constructor: ZonedFactory:", _zonedFactory);
    
    owner = _owner;
    creatorUserId = _creatorUserId;
    name = _name;
    managedFactory = _managedFactory;
    zonedFactory = _zonedFactory;
    
    console.log("Splitter.constructor: SUCCESS");
}
    // Set factory addresses
    // #TODO: 
    function setFactories(address _managedFactory, address _zonedFactory) public {
        managedFactory = _managedFactory;
        zonedFactory = _zonedFactory;
    }
    // Function to create managed contract
    function createManagedContract(string memory _creatorUserId, string memory _name, uint _parameter) public returns (address) {
        require(managedFactory != address(0), "ManagedFactory not set");
        
        ManagedFactory factory = ManagedFactory(managedFactory);
        address managedAddress = factory.createManaged(_creatorUserId, _name);
        
        // Store in Splitter's mapping
        string memory key = string.concat(_name, "_managed");
        contractsByType[key] = managedAddress;
        
        // Add key to array if not already added
        if (!isKeyAdded[key]) {
            contractKeys.push(key);
            isKeyAdded[key] = true;
        }
        emit ChildHolonCreated(managedAddress, "MANAGED", name);
        return managedAddress;
    }

    // Function to create Zoned contract
    function createZonedContract(string memory _creatorUserId, string memory _name, uint _parameter) public returns (address) {
        require(zonedFactory != address(0), "ZonedFactory not set");
        
        ZonedFactory factory = ZonedFactory(zonedFactory);
        address zonedAddress = factory.createZoned(_creatorUserId, _name, _parameter);
        
        // Store in Splitter's mapping
        string memory key = string.concat(_name, "_zoned");
        contractsByType[key] = zonedAddress;
        
        // Add key to array if not already added
        if (!isKeyAdded[key]) {
            contractKeys.push(key);
            isKeyAdded[key] = true;
        }
        emit ChildHolonCreated(zonedAddress, "ZONED", name);
        return zonedAddress;
    }

    function createChildContracts(string memory _creatorUserId, string memory _baseName, uint _parameter) internal {
        address managed = createManagedContract(_creatorUserId, _baseName, _parameter);
        address zoned = createZonedContract(_creatorUserId, _baseName, _parameter);
        
        console.log("createChildContract, baseName: ", _baseName);
    }

    // Function for routing commands by contract name
    function routeCommand(string memory contractName, bytes memory data) public returns (bool, bytes memory) {
        address targetContract = contractsByType[contractName];
        require(targetContract != address(0), "Target contract not found");
        
        (bool success, bytes memory result) = targetContract.call(data);
        return (success, result);
    }

    // Only the creator can add members
    //#TODO: Modularize this ( into Membrane ), as it will become the same for most of the contracts
    function addMember(string memory _userId) external {
        // require(msg.sender == creator, "Only creator can add members");
        // require(msg.sender == botAddress, "Only creator can add members");
        if (isSplitterMember[_userId]) return; // Gently fail if user is already added
        isSplitterMember[_userId] = true;
        userIds.push(_userId);
    }

    // Add multiple members at once
    //#TODO: Modularize this ( into Membrane ), as it will become the same for most of the contracts
    function addMembers(string[] memory _userIds) external {
        // require(msg.sender == botAddress, "Only creator can add members");
        for (uint i = 0; i < _userIds.length; i++) {
            string memory userId = _userIds[i];
            if (isSplitterMember[userId]) continue; // Skip if user is already added
            isSplitterMember[userId] = true;
            userIds.push(userId);
        }
    }
    
    // Function to deposit Ether for a specific userID
    function depositEtherForUser(
        string memory _userId,
        uint256 amount
    ) external payable {
        etherBalance[_userId] += amount;
    }

    // Function to deposit ERC20 tokens for a specific userID
    function depositTokenForUser(
        string memory _userId,
        address _tokenAddress,
        uint256 _amount
    ) external {
        IERC20 token = IERC20(_tokenAddress);
        //require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        
        // Debugging purposes;
        uint256 beforeBalance = tokenBalance[_userId][_tokenAddress];
 
        tokenBalance[_userId][_tokenAddress] += _amount;
        tokensOf[_userId].push(_tokenAddress);
        totalDeposited[_tokenAddress] += _amount;
    }

    //claim both ether and tokens
    function claim(string memory _userId, address _beneficiary) external {
        require(!hasClaimed[_userId], "User has already claimed");
        if (userIdToAddress[_userId] == address(0)) {
            userIdToAddress[_userId] = _beneficiary; // Associate user ID with address on first claim
        } else {
            // require(userIdToAddress[_userId] == _beneficiary, "Unauthorized");
        }
        claimEther(_userId, _beneficiary);
        claimTokens(_userId, _beneficiary);
        hasClaimed[_userId] = true;
    }

    // Function for users to claim their Ether
    function claimEther(string memory _userId, address _beneficiary) internal {
        // require(msg.sender == creator, "Only creator can add members");
        require(msg.sender == botAddress, "Only creator can submit claim");
        uint256 amount = etherBalance[_userId];
        require(_beneficiary != address(0), "Invalid beneficiary address");

        if (amount > 0 ) {
            (bool sent, bytes memory data) = _beneficiary.call{value: amount}("");
            require(sent, "Claiming Ether failed");
        }
        etherBalance[_userId] = 0;
    }

    // Function for users to claim their ERC20 tokens
    function claimTokens(string memory _userId, address _beneficiary) internal {
        // require(msg.sender == creator, "Only creator can add members");
        require(msg.sender == botAddress, "Only creator can submit claim");
        // Loop through all tokens and transfer to user
        address[] memory tokens = tokensOf[_userId];
        for (uint i = 0; i < tokensOf[_userId].length; i++) {
            IERC20 token = IERC20(tokens[i]);
            uint256 amount = tokenBalance[_userId][tokens[i]];
            if (amount > 0) {
                tokenBalance[_userId][tokens[i]] = 0;
                totalDeposited[tokens[i]] -= amount;
                token.transfer(_beneficiary, amount);
            }
        }
    }
    // How will we refer to a members? not by id, definitely, we need to use @usernames. 
    // We have the username in gundb, but what are the consequences of this change?
    // Note: We decided to use userIds ( as in managed ) as main source of identification
    function setSplit(string[] memory _userIds, uint[] memory percentage) public {
        // require(owner == msg.sender, "Only splitter owner can set the split");
        require(owner == botAddress, "Only splitter owner can set the split");
        require(_userIds.length == percentage.length, "_userIds and percentages should be equal");
        uint totalPercentage = 0;
        for (uint i = 0; i < percentage.length; i++) {
            totalPercentage += percentage[i];
        }
        require(totalPercentage == 100, "Total percentage should be 100");
        for (uint i = 0; i < _userIds.length; i++) {
            percentages[_userIds[i]] = percentage[i];
        }

        // mapping(string => address) public contractsByType;
    }

    // function reward(address _tokenaddress, uint256 _tokenamount)
    //     public
    //     payable
    //     override
    // {
    //     bool etherreward;
    //     IERC20 token;
    //     address tokenAddrForChildCall; // Address to pass to child reward function

    //     if (msg.value  > 0 && _tokenaddress == address(0)) {
    //         _tokenamount = msg.value;
    //         etherreward = true;
    //         tokenAddrForChildCall = address(0); // Use address(0) for ETH
    //     }
    //      else {
    //         token = IERC20(_tokenaddress);
    //         require (token.balanceOf(address(this)) >= _tokenamount, "Not enough tokens in the contract");
    //         etherreward = false;
    //         tokenAddrForChildCall = _tokenaddress; // Use actual token address for ERC20
    //     }
        
    //     console.log("reward - Starting address lookup");
    //     string memory managedName = string.concat(name, "_managed");
    //     string memory zonedName = string.concat(name, "_zoned");
    //     address managedAddress = contractsByType[managedName];
    //     address zonedAddress = contractsByType[zonedName];
    //     console.log("  found managedAddress:", managedAddress);
    //     console.log("  found zonedAddress:", zonedAddress);
        
    //     require(managedAddress != address(0), "Managed contract address not set");
    //     require(zonedAddress != address(0), "Zoned contract address not set");

    //     require(internalContractSplitPercentage + externalContractSplitPercentage == 100, "Contract split percentages not set or invalid");

    //     uint256 managedAmount = (_tokenamount * internalContractSplitPercentage) / 100;
    //     uint256 zonedAmount = (_tokenamount * externalContractSplitPercentage) / 100;

    //     uint256 calculatedTotal = managedAmount + zonedAmount;
    //     if (calculatedTotal < _tokenamount) {
    //          managedAmount += (_tokenamount - calculatedTotal);
    //     }

    //     console.log("  Total Amount:", _tokenamount);
    //     console.log("  Managed Share:", managedAmount);
    //     console.log("  Zoned Share:", zonedAmount);

    //     bool success;
    //     bytes memory callData; // For low-level calls

    //     // --- Start: Forward Funds & Emit ---
    //     if (etherreward) {
    //         if (managedAmount > 0) {
    //             console.log("  Forwarding ETH to Managed:", managedAmount);
    //             (success, ) = payable(managedAddress).call{value: managedAmount}("");
    //             require(success, "ETH transfer to Managed failed");
    //             emit FundsForwarded(managedAddress, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, managedAmount); // ETH uses special address
    //         }
    //         if (zonedAmount > 0) {
    //              console.log("  Forwarding ETH to Zoned:", zonedAmount);
    //             (success, ) = payable(zonedAddress).call{value: zonedAmount}("");
    //             require(success, "ETH transfer to Zoned failed");
    //             emit FundsForwarded(zonedAddress, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, zonedAmount); // ETH uses special address
    //         }
    //     } else {
    //         if (managedAmount > 0) {
    //             console.log("  Forwarding ERC20 to Managed:", managedAmount);
    //             success = token.transfer(managedAddress, managedAmount);
    //             require(success, "ERC20 transfer to Managed failed");
    //             emit FundsForwarded(managedAddress, _tokenaddress, managedAmount);
    //         }
    //          if (zonedAmount > 0) {
    //             console.log("  Forwarding ERC20 to Zoned:", zonedAmount);
    //             success = token.transfer(zonedAddress, zonedAmount);
    //             require(success, "ERC20 transfer to Zoned failed");
    //             emit FundsForwarded(zonedAddress, _tokenaddress, zonedAmount);
    //         }
    //     }
    //     // --- End: Forward Funds & Emit ---


    //     // --- Start: Call Child Reward Functions & Emit ---
    //     if (managedAmount > 0) {
    //         if (!etherreward) {
    //             // Only call reward() for ERC20 tokens
    //             console.log("  Calling reward on Managed Contract with token amount:", managedAmount);
    //             callData = abi.encodeWithSignature("reward(address,uint256)", tokenAddrForChildCall, managedAmount);
    //             (success, ) = managedAddress.call(callData);
    //             require(success, "Call to Managed reward failed");
    //         }
    //         emit ChildRewardTriggered(managedAddress, tokenAddrForChildCall, managedAmount);
    //     }

    //     if (zonedAmount > 0) {
    //         if (!etherreward) {
    //             // Only call reward() for ERC20 tokens
    //             console.log("  Calling reward on Zoned Contract with token amount:", zonedAmount);
    //             callData = abi.encodeWithSignature("reward(address,uint256)", tokenAddrForChildCall, zonedAmount);
    //             (success, ) = zonedAddress.call(callData);
    //             require(success, "Call to Zoned reward failed");
    //         }
    //         emit ChildRewardTriggered(zonedAddress, tokenAddrForChildCall, zonedAmount);
    //     }
    //     // --- End: Call Child Reward Functions & Emit ---

    //     // Remove or comment out the old RewardDistributed event
    //     /*
    //     emit RewardDistributed(
    //         address(this),
    //         _tokenamount,
    //         userIds.length, // No longer relevant
    //         etherreward ? "ETH" : "ERC20"
    //     );
    //     */
    // }

    function reward(address _tokenaddress, uint256 _tokenamount)
        public
        payable
        override
    {
        bool etherreward;
        IERC20 token;
        address tokenAddrForChildCall; // Address to pass to child reward function

        if (msg.value  > 0 && _tokenaddress == address(0)) {
            _tokenamount = msg.value;
            etherreward = true;
            tokenAddrForChildCall = address(0); // Use address(0) for ETH
        }
        else {
            token = IERC20(_tokenaddress);
            require (token.balanceOf(address(this)) >= _tokenamount, "Not enough tokens in the contract");
            etherreward = false;
            tokenAddrForChildCall = _tokenaddress; // Use actual token address for ERC20
        }
        
        console.log("reward - Starting address lookup");
        string memory managedName = string.concat(name, "_managed");
        string memory zonedName = string.concat(name, "_zoned");
        address managedAddress = contractsByType[managedName];
        address zonedAddress = contractsByType[zonedName];
        console.log("  found managedAddress:", managedAddress);
        console.log("  found zonedAddress:", zonedAddress);
        
        require(managedAddress != address(0), "Managed contract address not set");
        require(zonedAddress != address(0), "Zoned contract address not set");

        require(internalContractSplitPercentage + externalContractSplitPercentage == 100, "Contract split percentages not set or invalid");

        uint256 managedAmount = (_tokenamount * internalContractSplitPercentage) / 100;
        uint256 zonedAmount = (_tokenamount * externalContractSplitPercentage) / 100;

        uint256 calculatedTotal = managedAmount + zonedAmount;
        if (calculatedTotal < _tokenamount) {
            managedAmount += (_tokenamount - calculatedTotal);
        }

        console.log("  Total Amount:", _tokenamount);
        console.log("  Managed Share:", managedAmount);
        console.log("  Zoned Share:", zonedAmount);

        bool success;
        bytes memory callData; // For low-level calls

        // --- Transfer Funds and Call reward() for Managed Contract ---
        if (managedAmount > 0) {
            if (etherreward) {
                console.log("  Forwarding ETH to Managed and calling reward():", managedAmount);
                callData = abi.encodeWithSignature("reward(address,uint256)", tokenAddrForChildCall, managedAmount);
                (success, ) = payable(managedAddress).call{value: managedAmount}(callData);
                require(success, "ETH transfer and reward call to Managed failed");
                emit FundsForwarded(managedAddress, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, managedAmount);
            } else {
                console.log("  Forwarding ERC20 to Managed:", managedAmount);
                success = token.transfer(managedAddress, managedAmount);
                require(success, "ERC20 transfer to Managed failed");
                emit FundsForwarded(managedAddress, _tokenaddress, managedAmount);
                
                console.log("  Calling reward on Managed Contract:", managedAmount);
                callData = abi.encodeWithSignature("reward(address,uint256)", tokenAddrForChildCall, managedAmount);
                (success, ) = managedAddress.call(callData);
                require(success, "Call to Managed reward failed");
            }
            // emit ChildRewardTriggered(managedAddress, tokenAddrForChildCall, managedAmount);
        }

        // --- Transfer Funds and Call reward() for Zoned Contract ---
        if (zonedAmount > 0) {
            if (etherreward) {
                console.log("  Forwarding ETH to Zoned and calling reward():", zonedAmount);
                callData = abi.encodeWithSignature("reward(address,uint256)", tokenAddrForChildCall, zonedAmount);
                (success, ) = payable(zonedAddress).call{value: zonedAmount}(callData);
                require(success, "ETH transfer and reward call to Zoned failed");
                emit FundsForwarded(zonedAddress, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, zonedAmount);
            } else {
                console.log("  Forwarding ERC20 to Zoned:", zonedAmount);
                success = token.transfer(zonedAddress, zonedAmount);
                require(success, "ERC20 transfer to Zoned failed");
                emit FundsForwarded(zonedAddress, _tokenaddress, zonedAmount);
                
                console.log("  Calling reward on Zoned Contract:", zonedAmount);
                callData = abi.encodeWithSignature("reward(address,uint256)", tokenAddrForChildCall, zonedAmount);
                (success, ) = zonedAddress.call(callData);
                require(success, "Call to Zoned reward failed");
            }
        }
    }
   
    // Also add a debug function to view mappings
    function debugGetContractAddress(string memory contractKey) public view returns (address) {
        return contractsByType[contractKey];
    }

    function setContractSplit(uint _internalPercentage, uint _externalPercentage) public {
        // Authorization: Ensure only the authorized bot address can set the split
        // require(owner == botAddress, "Only splitter owner can set the contract split"); // Using the same authorization as setSplit

        // Validation: Check if the percentages sum up to 100
        require(_internalPercentage + _externalPercentage == 100, "Total percentage must be 100");

        // Storage: Assign the validated percentages to the dedicated state variables
        internalContractSplitPercentage = _internalPercentage;
        externalContractSplitPercentage = _externalPercentage;
    }

    // Add these new functions to list contracts
    function getContractKeys() public view returns (string[] memory) {
        return contractKeys;
    }

    function getContractAddresses() public view returns (string[] memory, address[] memory) {
        string[] memory keys = new string[](contractKeys.length);
        address[] memory addresses = new address[](contractKeys.length);
        
        for (uint i = 0; i < contractKeys.length; i++) {
            keys[i] = contractKeys[i];
            addresses[i] = contractsByType[contractKeys[i]];
        }
        
        return (keys, addresses);
    }

    // Add a function to get contract info by key
    function getContractInfo(string memory key) public view returns (address) {
        return contractsByType[key];
    }

    receive() external payable override {
        reward(address(0), msg.value);
    }

    fallback() external payable override{
        reward(address(0), msg.value);
    }
}
