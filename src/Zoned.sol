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

    uint256 public a;
    uint256 public b;
    uint256 public c;
    uint256 [] public rewards;
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
    constructor (address _creator, string memory _name, uint _nzones) {
        console.log("Zoned.constructor: Entered constructor");
        console.log("Zoned.constructor, creator: ", _creator);
        botAddress = 0x0000000000000000000000000000000000000015;
        
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
        console.log("Zoned.constructor: Set owner to creator");

        // Initialize reward parameters and call setRewardFunction
        a = 0;
        b = 0;
        c = 1;
        console.log("Zoned.constructor: Calling setRewardFunction with a, b, c =", a, b, c);
        setRewardFunction(a, b, c);
        console.log("Zoned.constructor: setRewardFunction completed");
        
        console.log("Zoned.constructor: Exiting constructor successfully");
    }


    //=============================================================
    //                      Membrane Functions
    //=============================================================

        // Only the creator can add members
    //#TODO: Modularize this ( into Membrane ), as it will become the same for most of the contracts
    //#TODO: This needs to be overwritten
    // Add a single member (automatically to zone 0)
    function addMember(string memory _userId) external {
        require(msg.sender == creator, "Only creator can add members");
        
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
    function addMembers(string[] memory _userIds) external {
        require(msg.sender == creator, "Only creator can add members");
        
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
        require(
            msg.sender == creator,
            "Only creator can submit an user claim Ether"
        );
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
        require(
            msg.sender == creator,
            "Only creator can submit an user claim Tokens"
        );
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

    /// @dev Splits the ERC20 token amount sent to the holon according to the appreciation
    /// @notice If appreciation is not shared, it splits it equally across each member (calling BlanketReward)
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
        
        uint256 amount;
        uint256 totalMembersRewarded = 0; // Counter for all rewarded members

        for (uint256 z = 1;  z <= nzones; z++) { //skip zone 0 as unassigned members
            if (zonemembers[z].length > 0) {
                amount = rewardFunction(z, _tokenamount) / zonemembers[z].length; // divide reward equally for all members in the same zone
                for (uint256 i = 0; i < zonemembers[z].length; i++) {
            
            //     if (totalappreciation > 0 ) // if any appreciation was shared
            //         amount = appreciation[_members[i]] * ( _tokenamount / totalappreciation); //multiply given appreciation with unit reward
            //     else
            //         amount = _tokenamount / _members.length ; //else use blanket unit reward value.

                    string memory theUser = zonemembers[z][i];

                    if (amount > 0 ){
                        address recipient = userIdToAddress[theUser];
                        bool isContract = recipient.code.length > 0;

                        if (etherreward){
                            if (hasClaimed[theUser]) {
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
                                this.depositEtherForUser(theUser, amount);

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
                            if (hasClaimed[theUser]) {
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
                                this.depositTokenForUser(theUser, _tokenaddress, amount);

                                emit MemberRewarded(
                                    address(this),
                                    address(0),
                                    amount,
                                    isContract,
                                    "STORED_ERC20"
                                );
                            }
                        }
                        totalMembersRewarded++;
                    }
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
    

    function setRewardFunction(uint _a, uint _b, uint _c) public {
        // v1
        // require (zone[tx.origin] == nzones, "only core members can change the reward function");
        // require (zone[tx.origin] == nzones, "only core members can change the reward function");
        // require (zone[creator] == nzones, "only core members can change the reward function");
        // require (zone[msg.sender] == nzones, "only core members can change the reward function");
        console.log("setRewardFunction. msg.sender: ", msg.sender, "botAddress:", botAddress);
        require (msg.sender == creator || msg.sender == factory, "only creator or factory can change the reward function");
        a = _a;
        b = _b;
        c = _c;
        rewards = calculateRewards();
    }

    // Function to calculate base rewards for zones 1 to 6
    function calculateRewards() public view returns (uint256[] memory) {
        uint256[] memory _rewards = new uint256[](6);
        uint256 total = 0;
        for (uint256 _zone = 1; _zone <= nzones; ++_zone) {
            _rewards[_zone] = a * _zone * _zone + b * _zone + c;
            total += _rewards[_zone];
        }
        // Function to normalize _rewards to sum to 100%
        for (uint256 i = 0; i < _rewards.length; i++) {
            // Multiply by 10000 for scaling to maintain precision
            _rewards[i] = _rewards[i] * 10000 / total;
        }
        return _rewards;
    }
    

    function rewardFunction(uint _zone, uint _totalreward) private view returns (uint zonereward)
    {
        return (rewards[_zone] * _totalreward) / 10000;

        //return _totalreward / nzones ;//(2 ^ (_zone + 1));
    }

    function addToZone(string memory _userId, uint _zone) public/// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param Documents a parameter just like in doxygen (must be followed by parameter name)) private returns (uint zonereward)
    {
        require(msg.sender == botAddress, "only creator can change the zones currently!");
        // require(zone[_userId] >= _zone, "members in lower zones cannot promote to higher zones");
        // TODO Cooloff period for nominations or validation of nomination
       
       
        if (zone[_userId] > 0) {//if member was already in a zone
             //search and remove member from current group
            // fetch correct zone members 
            uint previouszone = zone[_userId];
            for (uint256 i = 0; i < zonemembers[previouszone].length; i++) {
                if (keccak256(abi.encodePacked(zonemembers[previouszone][i])) == keccak256(abi.encodePacked(_userId))){
                zonemembers[previouszone][i] = zonemembers[previouszone][zonemembers[previouszone].length - 1]; //swap position with last member
                break;
                }
            }
            zonemembers[previouszone].pop(); // remove last member
        }
        
        zone[_userId]= _zone;
        zonemembers[_zone].push(_userId);
    }

    function getZoneMembers(uint _zone) external view returns (string[] memory)
    {
        return zonemembers[_zone];
    }

}