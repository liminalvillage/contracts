// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "./Splitter.sol";

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

contract SplitterFactory {

    address public managedFactory;
    address public zonedFactory;
    
    mapping (address => address[]) private holons;
    mapping (string => address) public toAddress;   //NOTE: Remove on deploy

    event NewHolon (string name, address addr);

    // Setter for both factories at once
    // #TODO: Set modifiers
    function setFactories(address _managedFactory, address _zonedFactory) public {
        require(_managedFactory != address(0), "ManagedFactory cannot be zero address");
        require(_zonedFactory != address(0), "ZonedFactory cannot be zero address");
        
        managedFactory = _managedFactory;
        zonedFactory = _zonedFactory;
        
    }

    // Individual setters if needed
    // #TODO: Set modifiers
    function setManagedFactory(address _managedFactory) public {
        require(_managedFactory != address(0), "ManagedFactory cannot be zero address");
        managedFactory = _managedFactory;
    }
    // #TODO: Set modifiers
    function setZonedFactory(address _zonedFactory) public {
        require(_zonedFactory != address(0), "ZonedFactory cannot be zero address");
        zonedFactory = _zonedFactory;
    }

    function newHolon(string memory _creatorUserId, string memory _name, uint _parameter, address _managedFactory, address _zonedFactory) public returns (address) {
        console.log("SplitterFactory.newHolon: ENTRY");
        console.log("SplitterFactory.newHolon: Creating splitter for name:", _name);
        console.log("SplitterFactory.newHolon: Creator:", _creatorUserId);
        console.log("SplitterFactory.newHolon: Using ManagedFactory:", _managedFactory);
        console.log("SplitterFactory.newHolon: Using ZonedFactory:", _zonedFactory);
        console.log("SplitterFactory.newHolon: msg.sender =", msg.sender);
        console.log("SplitterFactory.newHolon: tx.origin =", tx.origin);

        // Create the Splitter contract
        Splitter newholon = new Splitter(msg.sender, _creatorUserId, _name, _parameter, _managedFactory, _zonedFactory);
        address addr = address(newholon);
        
        console.log("SplitterFactory.newHolon: Splitter created at:", addr);
        
        // Maintain existing functionality - add to holon lists
        holons[address(0)].push(addr); // Add to the global holon list
        holons[msg.sender].push(addr); // Add to the local holon list
        if (msg.sender != tx.origin) {
            holons[tx.origin].push(addr); // Add to the personal holon list
            console.log("SplitterFactory.newHolon: Added to tx.origin list");
        }
        
        // Store address in mapping (this updates Holons.sol's mapping when called via delegatecall)
        toAddress[_name] = addr;
        console.log("SplitterFactory.newHolon: Set toAddress[", _name, "] =", addr);
        
        emit NewHolon(_name, addr);
        
        console.log("SplitterFactory.newHolon: SUCCESS - returning address:", addr);
        return addr;
    }
    function createSplitter(
        string memory _creatorUserId, 
        string memory _name, 
        uint _parameter,
        address _managedFactory,
        address _zonedFactory
    ) public returns (address) {
        console.log("SplitterFactory.createSplitter: Creating splitter for name:", _name);
        
        Splitter newholon = new Splitter(
            msg.sender, 
            _creatorUserId, 
            _name, 
            _parameter, 
            _managedFactory, 
            _zonedFactory
        );
        address addr = address(newholon);
        
        // Add to holon lists
        holons[address(0)].push(addr);
        holons[msg.sender].push(addr);
        if (msg.sender != tx.origin) {
            holons[tx.origin].push(addr);
        }
        
        // Store in factory's mapping
        toAddress[_name] = addr;
        
        emit NewHolon(_name, addr);
        return addr;
    }

    /// @dev Lists every holons ever created
    /// @return an array containing the address of every holon ever created.

    function listHolons() external view returns (address[] memory ){
        return holons[address(0)];
    }

    /// @dev Lists every holons created by a given address
    /// @param _address address;
    /// @return an array containing the address of every holon ever created.

    function listHolonsOf(address _address) external view returns (address[] memory){
        return holons[_address];
    }

}
