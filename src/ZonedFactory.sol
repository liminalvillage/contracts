// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "./Zoned.sol";
import "forge-std/console.sol";

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

contract ZonedFactory {
    
    mapping (address => address[]) private holons;
    mapping (string => address) public toAddress;   //NOTE: Remove on deploy

    event NewHolon (string name, address addr);
    event ZonedContractCreated(address indexed contractAddress, string indexed creatorUserId, string name, uint parameter);
 
    /// @dev Creates an new holon and adds it to the global and personal list
    /// @param _name The name of the holon.
    /// @return Address of the new holon

// V1
//    function newHolon(string memory _name, uint _parameter) public returns (address)
//     {
//         //This is required by tests to return the same address. NOTE: it enforces unique names for every holon created.
//         if (toAddress[_name] > address(0x0)) //An holon with the same name already exists
//            return toAddress[_name];

//         Zoned newholon = new Zoned(address(this), _name, _parameter); //create an holon
//         address addr = address(newholon);
//         holons[address(0)].push(addr); //add to the global holon list
//         holons[msg.sender].push(addr); // add it to the local holon list
//         if (msg.sender != tx.origin)
//             holons[tx.origin].push(addr); //add it to the personal holon list
        
//         toAddress[_name] = addr; //remove on deploy

    function newHolon(string memory creatorUserId, string memory _name, uint _parameter) public returns (address) {
        console.log("newHolon (Zoned): called with _name:", _name, "and _parameter:", _parameter);
        
        // Check if a holon with this name already exists.
        // //#TODO: Should people be able to replace holons in their chats?
        // if (toAddress[_name] > address(0x0)) //An holon with the same name already exists
        //    return toAddress[_name];
        
        console.log("newHolon (Zoned): Deploying new Zoned contract...");
        Zoned newholon = new Zoned(creatorUserId, msg.sender, _name, _parameter);
        address addr = address(newholon);
        console.log("newHolon (Zoned): New Zoned deployed at address:", uint256(uint160(addr)));
        
        console.log("newHolon (Zoned): Adding holon address to holons[address(0)]...");
        holons[address(0)].push(addr);
        
        console.log("newHolon (Zoned): Adding holon address to holons[msg.sender]...");
        holons[msg.sender].push(addr);
        
        if (msg.sender != tx.origin) {
            console.log("newHolon (Zoned): msg.sender is a contract. Also adding holon address to holons[tx.origin]...");
            holons[tx.origin].push(addr);
        }
        
        toAddress[_name] = addr;
        console.log("newHolon (Zoned): Stored holon address for _name:", _name, "in toAddress mapping.");
        
        emit NewHolon(_name, addr);
        console.log("newHolon (Zoned): Emitted NewHolon event for _name:", _name);
        
        return addr;
    }
    // function newHolon(string memory creatorUserId, string memory _name, uint _parameter) public returns (address) {
    //     Zoned newholon = new Zoned(creatorUserId, msg.sender, _name, _parameter);
    //     address addr = address(newholon);
        
    //     // Only implement core required storage
    //     holons[address(0)].push(addr);
    //     holons[msg.sender].push(addr);
    //     toAddress[_name] = addr;
        
    //     emit NewHolon(_name, addr);
    //     return addr;
    // }

    /// @dev Lists every holons ever created
    /// @return an array containing the address of every holon ever created.

    function createZoned(
        string memory _creatorUserId, 
        string memory _name, 
        uint _parameter
    ) public returns (address) {
        Zoned newholon = new Zoned(_creatorUserId, msg.sender, _name, _parameter);
        address addr = address(newholon);
        
        // Add to holon lists (if applicable)
        holons[address(0)].push(addr);
        holons[msg.sender].push(addr);
        
        // Store in factory's mapping
        toAddress[_name] = addr;
        
        emit NewHolon(_name, addr);
        emit ZonedContractCreated(addr, _creatorUserId, _name, _parameter);
        return addr;
    }

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
