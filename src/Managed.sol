// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "v3-core/contracts/libraries/FullMath.sol";

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
import "./IHolonFactory.sol";
import "./Holon.sol";

contract Managed is Holon {
    string[] public userIds; // list of userIds
    mapping(string => address) public userIdToAddress; // mapping for userIds to addresses
    mapping(string => bool) public hasClaimed; // mapping to track if userId has already claimed
    mapping(string => bool) public isManagedMember; // mapping to track if userId has already claimed
    mapping(string => uint256) public etherBalance; // storage for Ether by userID
    mapping(string => mapping(address => uint256)) public tokenBalance; // storage for ERC20 by userID
    mapping(string => address[]) public tokensOf; // list of received tokens for a specific userID
    mapping(address => uint256) public totalDeposited; // total amount of tokens deposited in the contract
    uint256 public totalappreciation;
    mapping(string => uint256) public appreciation; // appreciation received by a member based on UserID
    uint256 public maxAppreciation = 1e30; // appreciation has to be capped, and potentionaly dynamically changed so we can evade 0x11 arithmethic overflows


    constructor(address _creator, string memory _name) {
        name = _name;
        creator = _creator;
        totalappreciation = 0;
    }

    // Only the creator can add members
    function addMember(string memory _userId) external {
        require(msg.sender == creator, "Only creator can add members");
        if (isManagedMember[_userId]) return; // Gently fail if user is already added
        isManagedMember[_userId] = true;
        userIds.push(_userId);
    }

    // Add multiple members at once
    function addMembers(string[] memory _userIds) external {
        require(msg.sender == creator, "Only creator can add members");
        for (uint i = 0; i < _userIds.length; i++) {
            string memory userId = _userIds[i];
            if (isManagedMember[userId]) continue; // Skip if user is already added
            isManagedMember[userId] = true;
            userIds.push(userId);
        }
    }

    function getSize() external view override returns (uint256) {
        return userIds.length;
    }

    // Only the creator can set appreciation for members
    function setUserAppreciation(
        string memory _userId,
        uint256 _appreciationAmount
    ) external {
        require(msg.sender == creator, "Only creator can set appreciation");
        // Check that the new value is within the allowed cap.
        require(_appreciationAmount <= maxAppreciation, "Appreciation value too high");
        appreciation[_userId] = _appreciationAmount;
        totalappreciation += _appreciationAmount;
    }

    //set appreciation for an array of users
    function setAppreciation(
        string[] memory _userIds,
        uint256[] memory _appreciationAmounts
    ) external {
        require(msg.sender == creator, "Only creator can set appreciation");
        require(
            _userIds.length == _appreciationAmounts.length,
            "Array lengths do not match"
        );
        // Pre-check loops to revert at the beggining, not in the middle of execution
        for (uint i = 0; i < _appreciationAmounts.length; i++) {
            if (_appreciationAmounts[i] > maxAppreciation) {
                require(_appreciationAmounts[i] <= maxAppreciation, "Appreciation value too high");
            }
        }
        for (uint i = 0; i < _userIds.length; i++) {
            appreciation[_userIds[i]] = _appreciationAmounts[i];
            totalappreciation += _appreciationAmounts[i];
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
    // reward function to reward all members through their user id
    function reward(address _tokenaddress, uint256 _tokenamount) public payable override {
        bool etherreward;
        IERC20 token;

        if (msg.value > 0 && _tokenaddress == address(0)) {
            // Ether reward
            _tokenamount = msg.value;
            etherreward = true;
        } else {
            // Token reward
            // Load ERC20 token information
            token = IERC20(_tokenaddress);
            require(
                token.balanceOf(address(this)) - totalDeposited[_tokenaddress] >= _tokenamount,
                "Not enough tokens in the contract"
            );
        }

        uint256 amount;

        for (uint256 i = 0; i < userIds.length; i++) {
            if (totalappreciation > 0) {
                // If any appreciation was shared
                // amount = (appreciation[userIds[i]] * _tokenamount) / totalappreciation; // Multiply given appreciation with unit reward
                // ^ was before
                amount = FullMath.mulDiv(appreciation[userIds[i]], _tokenamount, totalappreciation);
            } else {
                // Else use blanket unit reward value
                amount = _tokenamount / userIds.length;
            }

            if (amount > 0) {
                address recipient = userIdToAddress[userIds[i]];
                bool isContract = recipient.code.length > 0; // Check if the recipient is a contract

                if (etherreward) { // Ether case
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
                    } else {
                        this.depositEtherForUser(userIds[i], amount);

                        emit MemberRewarded(
                            address(this),
                            address(0),
                            amount,
                            isContract,
                            "STORED_ETH"
                        );
                    }
                } else { // ERC20 case
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


    function getTokensOf(string memory _userId) public view returns (address[] memory) {
        return tokensOf[_userId];
    }

}