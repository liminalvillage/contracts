// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "v3-core/contracts/libraries/FullMath.sol";
import "forge-std/console.sol";

/*
    Copyright 2020, Roberto Valenti, co-authored by Aleksa Stojanović

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
    // string public flavor;

    constructor(address _creator, string memory _name) {
        name = _name;
        creator = _creator;
        totalappreciation = 0;
        flavor = "Managed";
        console.log("Managed.constructor: Set owner to creator with address: ", _creator);
    }

    // Only the creator can add members
    function addMember(string memory _userId) external {
        // require(msg.sender == creator, "Only creator can add members");
        if (isManagedMember[_userId]) return; // Gently fail if user is already added
        isManagedMember[_userId] = true;
        userIds.push(_userId);
    }

    // Add multiple members at once
    function addMembers(string[] memory _userIds) external {
        // require(msg.sender == creator, "Only creator can add members");
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
    function setUserAppreciation(string memory _userId, uint256 _amount) external onlyCreator {
        require(_amount <= maxAppreciation, "Appreciation value too high");

        uint256 prev = appreciation[_userId];
        appreciation[_userId] = _amount;

        // keep total in sync (no drift)
        if (_amount >= prev) {
            totalappreciation += (_amount - prev);
        } else {
            totalappreciation -= (prev - _amount);
        }
    }

    //set appreciation for an array of users
    function setAppreciation(string[] memory _userIds, uint256[] memory _amounts) external onlyCreator {
        require(_userIds.length == _amounts.length, "Array lengths do not match");

        // 1) write provided pairs
        for (uint i = 0; i < _userIds.length; i++) {
            uint256 a = _amounts[i];
            require(a <= maxAppreciation, "Appreciation value too high");
            appreciation[_userIds[i]] = a;
        }

        // 2) recompute canonical denominator across all members
        _recomputeTotalAppreciation();
    }

    function _recomputeTotalAppreciation() internal {
        uint256 n = userIds.length;
        uint256 sum = 0;
        for (uint i = 0; i < n; i++) {
            sum += appreciation[userIds[i]];
        }
        totalappreciation = sum;
    }

    // Callable any time to “repair” totals
    function recomputeTotalAppreciation() external onlyCreator {
        _recomputeTotalAppreciation();
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
        // require(
        //     msg.sender == creator,
        //     "Only creator can submit an user claim Ether"
        // );
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
    // reward function to reward all members through their user id
    function reward(address _tokenaddress, uint256 _tokenamount) public payable override {
        console.log(">>> Managed.reward: Entered");
        console.log("_tokenaddress:", _tokenaddress);
        console.log("_tokenamount (initial):", _tokenamount);
        console.log("msg.value:", msg.value);
        console.log("address(this):", address(this));

        bool etherreward;
        IERC20 token;

        if (msg.value > 0 && _tokenaddress == address(0)) {
            console.log("--- Managed.reward: ETH path selected ---");
            _tokenamount = msg.value; // Amount is now msg.value
            etherreward = true;
            console.log("    _tokenamount (updated for ETH):", _tokenamount);
        } else {
            console.log("--- Managed.reward: ERC20 path selected ---");
            console.log("ERC20 token address:", _tokenaddress);
            token = IERC20(_tokenaddress);
            etherreward = false;
            uint256 currentBalance = token.balanceOf(address(this));
            uint256 deposited = totalDeposited[_tokenaddress];
            console.log("Checking token balance: currentBalance =", currentBalance);
            console.log("Total deposited: ", deposited);
            console.log("Token amount:", _tokenamount);
            
            require(
                currentBalance - deposited >= _tokenamount, // Keep original logic
                "Not enough tokens in the contract"
            );
             console.log("Token balance check passed.");
        }

        uint256 amount;
        console.log("--- Managed.reward: Starting user loop ---");
        console.log("Number of userIds:", userIds.length);
        console.log("Total appreciation:", totalappreciation);

        for (uint256 i = 0; i < userIds.length; i++) {
            string memory currentUserId = userIds[i];
            console.log("Loop", i, "- Processing userId:", currentUserId);

            if (totalappreciation > 0) {
                console.log("Calculating amount based on appreciation.");
                uint256 userAppreciation = appreciation[currentUserId];
                console.log("User appreciation:", userAppreciation);
                amount = FullMath.mulDiv(userAppreciation, _tokenamount, totalappreciation);
                console.log("Calculated amount:", amount);
            } else {
                console.log("Calculating amount based on even split.");
                require(userIds.length > 0, "Managed.reward: Division by zero users (should not happen here)"); // Keep original check
                amount = _tokenamount / userIds.length;
                console.log("    Calculated amount:", amount);
            }

            if (amount > 0) {
                console.log("Amount > 0. Processing distribution.");
                address recipient = userIdToAddress[currentUserId];
                 console.log("Recipient address (from mapping):", recipient);
                // Note: recipient will be address(0) if user hasn't claimed yet
                bool isContract = recipient.code.length > 0;
                console.log("Is recipient a contract?", isContract);
                bool claimed = hasClaimed[currentUserId];
                console.log("Has user claimed?", claimed);


                if (etherreward) { // Ether case
                    if (hasClaimed[userIds[i]]) {
                        console.log("Ether reward user has claimed.");
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
                        console.log("Ether reward user has not claimed.");
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
                        console.log("ERC20 reward user has claimed.");
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
                        console.log("ERC20 reward user has not claimed.");
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