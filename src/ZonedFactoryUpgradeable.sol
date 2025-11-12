// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "./ZonedUpgradeable.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

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

contract ZonedFactoryUpgradeable is Ownable {

    address public implementation; // Address of the implementation contract
    mapping (address => address[]) private holons;
    mapping (string => address) public toAddress;

    event NewHolon (string name, address addr);
    event ImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);

    constructor(address _implementation) {
        require(_implementation != address(0), "Implementation cannot be zero address");
        implementation = _implementation;
        _transferOwnership(msg.sender);
    }

    /// @notice Update the implementation contract address
    /// @dev Only owner can update. Deploy upgrades after thorough testing
    function setImplementation(address _newImplementation) external onlyOwner {
        require(_newImplementation != address(0), "Implementation cannot be zero address");
        address oldImplementation = implementation;
        implementation = _newImplementation;
        emit ImplementationUpdated(oldImplementation, _newImplementation);
    }

    /// @dev Creates a new upgradeable Zoned holon via proxy
    /// @param creatorUserId The userId of the creator
    /// @param _name The name of the holon
    /// @param _parameter Number of zones
    /// @return Address of the new proxy
    function newHolon(string memory creatorUserId, string memory _name, uint _parameter) public returns (address)
    {
        // Encode the initializer function call
        bytes memory data = abi.encodeWithSelector(
            ZonedUpgradeable.initialize.selector,
            creatorUserId,
            msg.sender,
            _name,
            _parameter
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        address addr = address(proxy);

        holons[address(0)].push(addr); //add to the global holon list
        holons[msg.sender].push(addr); // add it to the local holon list

        toAddress[_name] = addr;

        emit NewHolon(_name, addr);

        return addr;
    }

    function createZoned(
        string memory _creatorUserId,
        string memory _name,
        uint _parameter
    ) public returns (address) {
        // Encode the initializer function call
        bytes memory data = abi.encodeWithSelector(
            ZonedUpgradeable.initialize.selector,
            _creatorUserId,
            msg.sender,
            _name,
            _parameter
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        address addr = address(proxy);

        // Add to holon lists
        holons[address(0)].push(addr);
        holons[msg.sender].push(addr);

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
