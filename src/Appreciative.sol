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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Holon.sol";

contract Appreciative is Holon {

    //======================== Structures for tracking appreciation
    uint256 public totalappreciation;               // max amount of appreciation in this holon
    mapping (string => uint256) public appreciation; //appreciaton received by a member
    mapping (string => uint256) public remainingappreciation; //appreciation left to give (max=100)

    // Added in accordance with Managed.sol
    string[] public userIds; // list of userIds
    mapping(string => address) public userIdToAddress; // mapping for userIds to addresses
    mapping(address => string) public addressToUserId; // reverse mapping
    mapping(string => bool) public hasClaimed; // mapping to track if userId has already claimed
    mapping(string => bool) public isAppreciativeMember; // mapping to track if userId has already claimed
    mapping(string => uint256) public etherBalance; // storage for Ether by userID
    mapping(string => mapping(address => uint256)) public tokenBalance; // storage for ERC20 by userID
    mapping(string => address[]) public tokensOf; // list of received tokens for a specific userID
    mapping(address => uint256) public totalDeposited; // total amount of tokens deposited in the contract

    constructor (address _creator, string  memory _name)
    {
        name = _name;
        creator = _creator;
        flavor = "Appreciative";
        totalappreciation = 0;
        v1
        owner = _creator; // We explicitly set it to understand if this causes an issues
        addressToUserId[msg.sender] = "bot123"; // Was necessary as we set telegramUserIds as base

    }

      //=============================================================
    //                      Appreciative Functions
    //=============================================================
    //  these function are called to signal appreciation to others

    /// @dev Gives a percentage of appreciation to a specific member
    /// @notice Only the holon members (not contributors) can call this function
    /// @notice A member cannot send appreciation to himself
    /// @notice Sender should have enough appreciation left to give
    /// @param _userId The ( telegram ) userId of the receiving member
    /// @param _percentage The amount of the appreciation to give in percentage.

    function appreciate(string memory _userId, uint8 _percentage)
        external
    {
        // senderUserId is bot in this case, might be the user in case of AA. 
        // We need to add it's userId alongside the address if this function should remain the same
        string memory senderUserId = addressToUserId[msg.sender]; // The problem here is that the message sender will always
        // be the same ( bot )
        require(isAppreciativeMember[senderUserId] || isAppreciativeMember[_userId], 
                "Sender or Receiver is not a member");
        require(keccak256(bytes(senderUserId)) != keccak256(bytes(_userId)), 
                "Sender cannot appreciate himself.. that's selfish");
        require(remainingappreciation[senderUserId] >= _percentage, 
                "Not enough appreciation remaining");
        remainingappreciation[senderUserId] -= _percentage;
        appreciation[_userId] += _percentage;
        totalappreciation += _percentage;
    }

    /// @dev Gives a percentage of appreciation to a specific member
    /// @notice Only the holon members can call this function
    /// @notice A member cannot send appreciation to himself
    /// @notice Sender should have enough appreciation left to give in parent
    /// @param _parent The address of the receiving member
    /// @param _sibling The address of the receiving member
    /// @param _percentage The amount of the appreciation to give in percentage.
    /// #TODO: Decide what needs to be done with this function ( we could create backwards compatibility anyway)
    // function appreciateSibling(address _parent, address _sibling, uint8 _percentage)
    //     external
    // {
    //     require (msg.sender == owner,"Only lead can perform this action");
    //     Appreciative(payable(_parent)).appreciate(_sibling,_percentage);
    // }

    /// @dev Sets appreciation for a group of members
    /// @notice This is the only way to change already assigned appreciation
    /// @notice Currently could be called by anyone?
    function setAppreciation(string[] memory _userIds, uint8[] memory _percentages)
        external
    {
        require(_userIds.length == _percentages.length, "Array length mismatch");
        totalappreciation = 0;
         for (uint256 i = 0; i < _userIds.length; i++) {
             appreciation[_userIds[i]] = _percentages[i];
             remainingappreciation[_userIds[i]] -= _percentages[i];
             totalappreciation += _percentages[i];
         }
    }

    /// @dev Resets appreciation of the caller
    /// @notice This is the only way to change already assigned appreciation
    function resetAppreciation()
        external
    {
        require(msg.sender == owner, "Only the lead can reset appreciation");
        totalappreciation = 0;
         for (uint256 i = 0; i < userIds.length; i++) {
             string memory _userId = userIds[i];
             remainingappreciation[_userId] = 100;
             appreciation[_userId] = 0;
         }
    }

    function addMember(string memory _userId) external {
        require(msg.sender == creator, "Only creator can add members");
        if (isAppreciativeMember[_userId]) return; // Gently fail if user is already added
        isAppreciativeMember[_userId] = true;
        userIds.push(_userId);
    }
    function addMembers(string[] memory _userIds) external {
        require(msg.sender == creator, "Only creator can add members");
        for (uint i = 0; i < userIds.length; i++) {
            string memory userId = _userIds[i];
            if (isAppreciativeMember[userId]) continue; // Skip if user is already added
            isAppreciativeMember[userId] = true;
            userIds.push(userId);
        }
    }

    //#TODO: Modularize this
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
    //#TODO: Modularize this

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
            if (totalappreciation > 0 ) // if any appreciation was shared
                amount = (appreciation[userIds[i]] * _tokenamount) / totalappreciation; //multiply given appreciation with unit reward
            else
                amount = _tokenamount /userIds.length ; //else use blanket unit reward value.

            if (amount > 0 ){
                address recipient = userIdToAddress[userIds[i]];
                bool isContract = recipient.code.length > 0;

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
                }else{
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
           emit RewardDistributed(
                address(this),
                _tokenamount,
                userIds.length,
                etherreward ? "ETH" : "ERC20"
            );
    }
   
}
