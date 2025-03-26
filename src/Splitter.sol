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
        
        // Direct call instead of delegatecall
        ManagedFactory factory = ManagedFactory(managedFactory);
        address managedAddress = factory.createManaged(_creatorUserId, _name);
        
        // Store in Splitter's mapping
        contractsByType[string.concat(_name, "_managed")] = managedAddress;
        
        return managedAddress;
    }

    // Function to create Zoned contract
    function createZonedContract(string memory _creatorUserId, string memory _name, uint _parameter) public returns (address) {
        require(zonedFactory != address(0), "ZonedFactory not set");
        
        // Direct call instead of delegatecall
        ZonedFactory factory = ZonedFactory(zonedFactory);
        address zonedAddress = factory.createZoned(_creatorUserId, _name, _parameter);
        
        // Store in Splitter's mapping
        contractsByType[string.concat(_name, "_zoned")] = zonedAddress;
        
        return zonedAddress;
    }

    function createChildContracts(string memory _creatorUserId, string memory _baseName, uint _parameter) internal {
        address managed = createManagedContract(_creatorUserId, string.concat(_baseName, "_managed"), _parameter);
        address zoned = createZonedContract(_creatorUserId, string.concat(_baseName, "_zoned"), _parameter);
        
        // Store in mapping using full names with base name prefix
        contractsByType[string.concat(_baseName, "_managed")] = managed;
        contractsByType[string.concat(_baseName, "_zoned")] = zoned;
        
        // Emit an event with the addresses
        // emit ChildContractsCreated(managed, zoned);
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
        require(msg.sender == botAddress, "Only creator can add members");
        if (isSplitterMember[_userId]) return; // Gently fail if user is already added
        isSplitterMember[_userId] = true;
        userIds.push(_userId);
    }

    // Add multiple members at once
    //#TODO: Modularize this ( into Membrane ), as it will become the same for most of the contracts
    function addMembers(string[] memory _userIds) external {
        require(msg.sender == botAddress, "Only creator can add members");
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
    }

    function reward(address _tokenaddress, uint256 _tokenamount)
        public
        payable
        override
    {
        bool etherreward;
        IERC20 token;

        if (msg.value  > 0 && _tokenaddress == address(0)) {
            _tokenamount = msg.value;
            etherreward = true;
        }
         else {
            //Load ERC20 token information
            token = IERC20(_tokenaddress);
            require (token.balanceOf(address(this)) >= _tokenamount, "Not enough tokens in the contract");
        }
        
        uint256  amount;

        for (uint256 i = 0; i < userIds.length; i++) {
           
                amount = (percentages[userIds[i]] * _tokenamount) / 100; //multiply given appreciation with unit reward

            if (amount > 0 ){
                address recipient = userIdToAddress[userIds[i]];
                bool isContract = recipient.code.length > 0; // Check if the recipient is a contract
                if (etherreward){
                    if (hasClaimed[userIds[i]]) {
                        (bool success, ) = payable(recipient).call{value: amount}("");
                        require(success, "Transfer failed");
                        emit MemberRewarded(
                            address(this),
                            recipient,
                            amount,
                            isContract,
                            "ETH"
                        );
                    }
                    else {
                        this.depositEtherForUser(userIds[i], amount);

                        emit MemberRewarded(
                            address(this),
                            address(0),
                            amount,
                            isContract,
                            "STORED_ETH"
                        );
                    }
                }
                else {
                    if (hasClaimed[userIds[i]]) {
                        token.transfer(recipient, amount);
                        (bool success, ) = recipient.call(
                            abi.encodeWithSignature(
                                "reward(address,uint256)",
                                _tokenaddress,
                                amount
                            )
                        );
                        require(success, "Unable to call the reward function");

                        emit MemberRewarded(
                            address(this),
                            recipient,
                            amount,
                            isContract,
                            "ERC20"
                        );
                    } else {
                        this.depositTokenForUser(userIds[i], _tokenaddress, amount);

                        emit MemberRewarded(
                            address(this),
                            address(0),
                            amount,
                            isContract,
                            "STORED_ERC20"
                        );
                    }
                }
            }
        }
        // Emit a summary event after processing all members
        emit RewardDistributed(
            address(this),
            _tokenamount,
            userIds.length,
            etherreward ? "ETH" : "ERC20"
        );
    }
   

}
