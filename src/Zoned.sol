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
import "./IHolonFactory.sol";
import "./Holon.sol";
import "forge-std/console.sol";

 contract Zoned is Holon{

    // Membrane variables and functionalities
    //#TODO: Modularize this ( into Membrane ), as it will become the same for most of the contracts
    string[] public userIds; // list of userIds
    mapping(string => address) public userIdToAddress; // mapping for userIds to addresses
    mapping(address => string) public addressToUserId; // reverse mapping for addresses to userIds
    mapping(string => bool) public hasClaimed; // mapping to track if userId has already claimed
    mapping(string => bool) public isZonedMember; // mapping to track if userId is a member
    mapping(string => uint256) public etherBalance; // storage for Ether by userID
    mapping(string => mapping(address => uint256)) public tokenBalance; // storage for ERC20 by userID
    mapping(string => address[]) public tokensOf; // list of received tokens for a specific userID
    mapping(address => uint256) public totalDeposited; // total amount of tokens deposited in the contract
    mapping(string => uint) public percentages;
    // string public flavor;
    //#TODO: Modularize this ( into Membrane ), as it will become the same for most of the contracts
    // Membrane variables and functionalities

    address public botAddress;
    address public factory;

    uint256 private constant WAD = 1e18;
    uint256 public s; // steepness parameter in WAD (e.g., 0.75e18 means each zone is 25% less per person)  
     //======================== Public holon variables
  
    uint public nzones;
    
    // v1
    // mapping (uint => address[]) public zonemembers;
    // mapping (address => uint) public zone;
    mapping(uint => string[]) public zonemembers;    // Maps zone number to array of member IDs
    mapping(string => uint) public zone;

    /// @notice Constructor to create an holon
    ///  created the Holon contract, the factory needs to be deployed first

    // v1
    // constructor (address _creator, string  memory _name, uint _nzones)
    // {
    //     name = _name;
    //     creator = _creator;
    //     flavor = "Zoned";

    //     nzones = _nzones;
    //     zone[tx.origin]= _nzones;
    //     zonemembers[_nzones].push(tx.origin);    


    constructor (string memory creatorUserId, address _creator, string memory _name, uint _nzones) {
        name = _name;
        console.log("Zoned.constructor: Set name to:", _name);
        
        creator = _creator;
        console.log("Zoned.constructor: Set creator to:", uint256(uint160(_creator)));
        
        flavor = "Zoned";
        console.log("Zoned.constructor: Set flavor to: Zoned");
        
        nzones = _nzones;
        console.log("Zoned.constructor: Set nzones to:", _nzones);
        
        // Set owner to creator and log
        owner = _creator;
        factory = msg.sender;
        // owner = msg.sender;
        console.log("Zoned.constructor: Set owner to creator with address: ", _creator);

        // Initialize reward parameters and call setRewardFunction
        s = 0.75e18; // Default steepness: each zone gets 25% less per person
        // botAddress = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // localhost
        botAddress = 0xb2DA94d13735aF2DDCF5a3c797547290221f3DBb; // sepolia
        isZonedMember[creatorUserId] = true;
        userIds.push(creatorUserId);
        // commenting out to test if the group itself won't be part of the zones
        // zonemembers[_nzones].push(creatorUserId);
        // zone[creatorUserId] = _nzones;
        console.log("Zoned.constructor: Calling setSteepness with s =", s);
        setSteepness(creatorUserId, s);
        console.log("Zoned.constructor: setSteepness completed");
        
        console.log("Zoned.constructor: Exiting constructor successfully");
    }
    // constructor(string memory creatorUserId, address _creator, string memory _name, uint _nzones) {
    //     name = _name;
    //     creator = _creator;
    //     flavor = "Zoned";    
    //     owner = _creator;
    // }

    //=============================================================
    //                      Membrane Functions
    //=============================================================

        // Only the creator can add members
    //#TODO: Modularize this ( into Membrane ), as it will become the same for most of the contracts
    //#TODO: This needs to be overwritten
    // Add a single member (automatically to zone 0)
    function addMember(string memory senderUserId, string memory _userId) external {
        // require(msg.sender == creator || isZonedMember[senderUserId], "Only creator or existing members can add new members");
        
        if (isZonedMember[_userId]) return; // Gently fail if user is already added
        
        isZonedMember[_userId] = true;
        userIds.push(_userId);
        
        // Add to zone 0
        zone[_userId] = 0;  
        zonemembers[0].push(_userId);
    }
    // Add multiple members at once
    //#TODO: Modularize this ( into Membrane ), as it will become the same for most of the contracts
    //#TODO: This needs to be overwritten
    function addMembers(string memory senderUserId, string[] memory _userIds) external {
        // require(msg.sender == creator || isZonedMember[senderUserId], "Only creator or existing members can add new members");
        
        for (uint i = 0; i < _userIds.length; i++) {
            string memory userId = _userIds[i];
            if (isZonedMember[userId]) continue; // Skip if user is already added
            
            isZonedMember[userId] = true;
            userIds.push(userId);
            
            // Add to zone 0
            zone[userId] = 0;
            zonemembers[0].push(userId);
        }
    }

    // Add federation member using federationId as userId
    // This function is specifically designed for federation scenarios
    function addFederationMember(string memory federationId) external {
        require(msg.sender == creator || msg.sender == factory, "Only creator or factory can add federation members");
        
        if (isZonedMember[federationId]) return; // Gently fail if federation is already added
        
        isZonedMember[federationId] = true;
        userIds.push(federationId);
        
        // Add to zone 0
        zone[federationId] = 0;  
        zonemembers[0].push(federationId);
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
        //#TODO: creator should become bot?
        // require(
        //     msg.sender == creator,
        //     "Only creator can submit an user claim Ether"
        // );
        //#TODO: Later this will be member address. 
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
        //#TODO: creator should become bot?
        // require(
        //     msg.sender == creator,
        //     "Only creator can submit an user claim Tokens"
        // );
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

    //=============================================================
    //                      Reward Functions
    //=============================================================
    //these function will be called when a payment is sent to the holon

    /// @dev Splits tokens across zones using steepness formula: each zone z gets N[z] * s^z share
    /// @param _tokenaddress Address of the ERC20 token (address(0) for ETH)
    /// @param _tokenamount Amount to distribute
    function reward(address _tokenaddress, uint256 _tokenamount)
        public
        payable
        override
    {
        bool etherreward;
        IERC20 token;

        if (msg.value > 0 && _tokenaddress == address(0)) {
            _tokenamount = msg.value;
            etherreward = true;
        } else {
            token = IERC20(_tokenaddress);
            require(token.balanceOf(address(this)) >= _tokenamount, "Not enough tokens in the contract");
        }

        require(_tokenamount > 0, "amount=0");
        require(s > 0 && s < WAD, "s out of range");

        uint256 Z = nzones + 1; // Total number of zones (0 to nzones inclusive)

        // Pass 1: compute Σ N[z] * s^z and store counts and s^z
        uint256[] memory counts = new uint256[](Z);
        uint256[] memory sPow = new uint256[](Z);

        uint256 S = 0;
        uint256 sp = WAD; // s^0
        for (uint256 z = 0; z < Z; z++) {
            uint256 n = zonemembers[z].length;
            counts[z] = n;
            sPow[z] = sp;
            if (n > 0) S += n * sp;
            sp = (sp * s) / WAD; // s^(z+1)
        }
        require(S > 0, "no recipients");

        uint256 totalMembersRewarded = 0;

        // Pass 2: distribute per zone
        for (uint256 z = 0; z < Z; z++) {
            uint256 n = counts[z];
            if (n == 0) continue;

            // zoneTotal = amount * (N[z] * s^z) / S
            uint256 zoneTotal = (_tokenamount * (n * sPow[z])) / S;
            uint256 per = zoneTotal / n;

            for (uint256 i = 0; i < zonemembers[z].length; i++) {
                string memory theUser = zonemembers[z][i];

                // Calculate amount for this user (last user gets remainder to handle dust)
                uint256 amount;
                if (i + 1 == zonemembers[z].length) {
                    uint256 sentBefore = per * (n - 1);
                    amount = zoneTotal - sentBefore;
                } else {
                    amount = per;
                }

                if (amount > 0) {
                    address recipient = userIdToAddress[theUser];
                    bool isContract = recipient.code.length > 0;

                    if (etherreward) {
                        if (hasClaimed[theUser]) {
                            (bool success, ) = payable(recipient).call{value: amount}("");
                            require(success, "Transfer failed");
                            emit MemberRewarded(address(this), recipient, amount, isContract, "ETH");
                        } else {
                            this.depositEtherForUser(theUser, amount);
                            emit MemberRewarded(address(this), address(0), amount, isContract, "STORED_ETH");
                        }
                    } else {
                        if (hasClaimed[theUser]) {
                            token.transfer(recipient, amount);
                            (bool success, ) = recipient.call(
                                abi.encodeWithSignature("reward(address,uint256)", _tokenaddress, amount)
                            );
                            require(success, "Unable to call the reward function");
                            emit MemberRewarded(address(this), recipient, amount, isContract, "ERC20");
                        } else {
                            this.depositTokenForUser(theUser, _tokenaddress, amount);
                            emit MemberRewarded(address(this), address(0), amount, isContract, "STORED_ERC20");
                        }
                    }
                    totalMembersRewarded++;
                }
            }
        }

        emit RewardDistributed(
            address(this),
            _tokenamount,
            totalMembersRewarded,
            etherreward ? "ETH" : "ERC20"
        );
    }
    

    /// @notice Sets the steepness parameter for zone-based reward distribution
    /// @param senderUserId The user requesting the change
    /// @param _s Steepness in WAD units (e.g., 0.75e18 = 75% = each zone gets 25% less per person)
    function setSteepness(string memory senderUserId, uint256 _s) public {
        console.log("setSteepness. msg.sender: ", msg.sender, "botAddress:", botAddress);
        require(msg.sender == creator || msg.sender == factory, "only creator or factory can change steepness");
        require(_s > 0 && _s < WAD, "s must be between 0 and WAD");

        s = _s;
    }

    function addToZone(string memory senderUserId, string memory _userId, uint _zone) public/// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param Documents a parameter just like in doxygen (must be followed by parameter name)) private returns (uint zonereward)
    {
        // Commenting out temporairly
        // require(msg.sender == botAddress, "only creator can change the zones currently!");
        // Commenting out temporairly, as in who is going to promote the member if not the bot itself? Even then, the bot should not be in the zones
        // require(zone[senderUserId] >= _zone, "members in lower zones cannot promote to higher zones");
        // TODO Cooloff period for nominations or validation of nomination
        require(isZonedMember[_userId], "only zone members can have their zones changed");
       
        uint previouszone = zone[_userId];
        for (uint256 i = 0; i < zonemembers[previouszone].length; i++) {
            if (keccak256(abi.encodePacked(zonemembers[previouszone][i])) == keccak256(abi.encodePacked(_userId))){
            zonemembers[previouszone][i] = zonemembers[previouszone][zonemembers[previouszone].length - 1]; //swap position with last member
            break;
            }
        }
        zonemembers[previouszone].pop(); // remove last member
        
        zone[_userId]= _zone;
        zonemembers[_zone].push(_userId);
    }

    /// @notice Removes a user from their current zone and membership
    /// @param senderUserId The userId of the sender requesting the removal
    /// @param _userId The userId to remove from their zone
    function removeFromZone(string memory senderUserId, string memory _userId) public {
        // Optionally restrict who can call this
        // require(msg.sender == botAddress, "Only bot can remove from zone");

        require(isZonedMember[_userId], "User is not a zone member");

        uint currentZone = zone[_userId];

        // Remove user from zonemembers[currentZone] array
        for (uint256 i = 0; i < zonemembers[currentZone].length; i++) {
            if (keccak256(abi.encodePacked(zonemembers[currentZone][i])) == keccak256(abi.encodePacked(_userId))) {
                zonemembers[currentZone][i] = zonemembers[currentZone][zonemembers[currentZone].length - 1];
                zonemembers[currentZone].pop();
                break;
            }
        }

        // Optionally, mark as not a member and clear zone
        isZonedMember[_userId] = false;
        zone[_userId] = 0; // or type(uint).max if you want to indicate "no zone"
    }

    function getZoneMembers(uint _zone) external view returns (string[] memory)
    {
        return zonemembers[_zone];
    }

}