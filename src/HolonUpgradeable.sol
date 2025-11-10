// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

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

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./IHolonFactory.sol";
import "./MembraneUpgradeable.sol";

abstract contract HolonUpgradeable is Initializable, MembraneUpgradeable, UUPSUpgradeable {

     //======================== Public holon variables
    string public name;                      //The name of the holon
    string public version;                   //Version of the holon contract
    string public flavor;                    //Type of the holon
    address public creator;                  //Link to the holonic parent

    //======================== Events
    event RewardDistributed(
        address indexed contractAddress,
        uint256 amount,
        uint256 totalMembers,
        string rewardType
    );

    event MemberRewarded(
        address indexed from,
        address indexed to,
        uint256 amount,
        bool isContract,
        string rewardType
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function __Holon_init(address _owner) internal onlyInitializing {
        __Membrane_init(_owner);
        __UUPSUpgradeable_init();
        __Holon_init_unchained();
    }

    function __Holon_init_unchained() internal onlyInitializing {
        // Additional initialization if needed
    }

    /// @notice Function to authorize upgrades (required by UUPSUpgradeable)
    /// @dev Only the owner can upgrade the contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Modifier to restrict access to owner only
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    //=============================================================
    //                      Holon Creation, Fork and Merge Functions
    //=============================================================
    // these function will be used by the holon lead to mantain the holon members
    function newHolon(string calldata _flavor, string calldata _name, uint _parameter) external returns (address){
        IHolonFactory factory = IHolonFactory(creator);
        return factory.newHolon(_flavor, _name, _parameter);
    }

    receive()
        external
        payable
        virtual
    {
        reward(address(0),msg.value);
    }

    fallback()
        external
        payable
        virtual
    {
        reward(address(0),msg.value);
    }


     function reward(address _tokenAddress, uint256 _tokenAmount) public payable virtual {
        require(_members.length > 0, "No members to reward");
        require(_tokenAmount > 0, "Token amount must be greater than zero");

        if (msg.value > 0 && _tokenAddress == address(0)) {
            require(_tokenAmount == msg.value, "Ether amount mismatch");
            distributeEther(_tokenAmount);
        } else {
            require(_tokenAddress != address(0), "Invalid token address for ERC20 reward");
            distributeERC20(_tokenAddress, _tokenAmount);
        }
    }

    function distributeEther(uint256 _etherAmount) private {
        uint256 amountPerMember = _etherAmount / _members.length;
        require(amountPerMember > 0, "Insufficient amount for distribution");

        uint256 totalMembersRewarded = 0;
        for (uint256 i = 0; i < _members.length; i++) {
            address recipient = _members[i];
            bool isContract = recipient.code.length > 0;
            (bool success, ) = _members[i].call{value: amountPerMember}("");
            require(success, "Ether transfer failed");
            // Emit an event for each member rewarded
            emit MemberRewarded(
                address(this),
                recipient,
                amountPerMember,
                isContract,
                "ETH"
            );
            totalMembersRewarded++;
        }
        emit RewardDistributed(
            address(this),
            _etherAmount,
            totalMembersRewarded,
            "ETH"
        );
    }

    function distributeERC20(address _tokenAddress, uint256 _tokenAmount) private {
        IERC20 token = IERC20(_tokenAddress);
        require(token.balanceOf(address(this)) >= _tokenAmount, "Not enough tokens in the contract");

        uint256 amountPerMember = _tokenAmount / _members.length;
        require(amountPerMember > 0, "Insufficient amount for distribution");
        uint256 totalMembersRewarded = 0;

        for (uint256 i = 0; i < _members.length; i++) {
            address recipient = _members[i];
            bool isContract = recipient.code.length > 0;
            require(token.transfer(_members[i], amountPerMember), "ERC20 transfer failed");
            emit MemberRewarded(
                address(this),
                recipient,
                amountPerMember,
                isContract,
                "ERC20"
            );
            totalMembersRewarded++;
        }
        emit RewardDistributed(
            address(this),
            _tokenAmount,
            totalMembersRewarded,
            "ERC20"
        );
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
