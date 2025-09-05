// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "./Managed.sol";

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

contract ManagedFactory {
    
    mapping (address => address[]) private holons;
    mapping (string => address) public toAddress;   //NOTE: Remove on deploy

    event NewHolon (string name, address addr);
    event ManagedContractCreated(address indexed contractAddress, string indexed creatorUserId, string name);
 
    /// @dev Creates an new holon and adds it to the global and personal list
    /// @param _name The name of the holon.
    /// @return Address of the new holon

   function newHolon(string memory creatorUserId, string memory _name, uint _parameter) public returns (address)
    {
        //This is required by tests to return the same address. NOTE: it enforces unique names for every holon created.
        
        // //#TODO: Should people be able to replace holons in their chats?
        // if (toAddress[_name] > address(0x0)) //An holon with the same name already exists
        //    return toAddress[_name];

        Managed newholon = new Managed(msg.sender, _name); //create an holon
        address addr = address(newholon);
        holons[address(0)].push(addr); //add to the global holon list
        holons[msg.sender].push(addr); // add it to the local holon list
        if (msg.sender != tx.origin)
            holons[tx.origin].push(addr); //add it to the personal holon list
        
        toAddress[_name] = addr; //remove on deploy

        emit NewHolon(_name, addr);

        return addr;
    }
    function createManaged(
        string memory _creatorUserId, 
        string memory _name
    ) public returns (address) {
        Managed newholon = new Managed(msg.sender, _name);
        address addr = address(newholon);
        
        // Add to holon lists (if applicable)
        holons[address(0)].push(addr);
        holons[msg.sender].push(addr);
        
        // Store in factory's mapping
        toAddress[_name] = addr;
        
        emit NewHolon(_name, addr);
        emit ManagedContractCreated(addr, _creatorUserId, _name);
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
