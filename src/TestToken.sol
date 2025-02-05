// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
  
/**
* @title TestToken is a basic ERC20 Token
*/
contract TestToken is ERC20 {
    constructor (uint256 initialSupply) ERC20("Gold", "GLD") {
        _mint(msg.sender, initialSupply/2);
        _mint(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, initialSupply/2);
        // ^ Only for testing purposes
    }
}