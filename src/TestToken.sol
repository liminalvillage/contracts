// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
  
/**
* @title TestToken is a basic ERC20 Token
*/
contract TestToken is ERC20 {
    constructor (uint256 initialSupply) ERC20("FLOW", "FLW") {
        _mint(msg.sender, initialSupply/2);
        // _mint(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, initialSupply/2);
        // ^ Only for testing purposes ( localhost )
        _mint(0x7663f42dBde575C845ef5C2Dc5cDE84805B4F8Ef, initialSupply/2);
        // ^ Only for testing purposes ( sepolia )
    }
}