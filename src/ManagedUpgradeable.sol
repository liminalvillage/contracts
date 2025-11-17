// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
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
import "./HolonUpgradeable.sol";

contract ManagedUpgradeable is HolonUpgradeable {
    using SafeERC20 for IERC20;
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
    uint256 public maxAppreciation; // appreciation has to be capped, and potentionaly dynamically changed so we can evade 0x11 arithmethic overflows

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _creator, string memory _name) public initializer {
        __Holon_init(_creator);
        __Managed_init_unchained(_creator, _name);
    }

    function __Managed_init_unchained(address _creator, string memory _name) internal onlyInitializing {
        name = _name;
        creator = _creator;
        totalappreciation = 0;
        flavor = "Managed";
        maxAppreciation = 1e30;
    }

    // Only the creator can add members
    function addMember(string memory _userId) external {
        require(msg.sender == creator || msg.sender == owner, "Only creator or owner can add members");
        require(!isManagedMember[_userId], "Member already added");
        isManagedMember[_userId] = true;
        userIds.push(_userId);
    }

    // Add multiple members at once
    function addMembers(string[] memory _userIds) external {
        require(msg.sender == creator || msg.sender == owner, "Only creator or owner can add members");
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
        // require(msg.sender == creator, "Only creator can set appreciation");
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
                token.safeTransfer(_beneficiary, amount);
            }
        }
    }
    // reward function to reward all members through their user id
    function reward(address _tokenaddress, uint256 _tokenamount) public payable override nonReentrant {
        bool etherreward;
        IERC20 token;

        if (msg.value > 0 && _tokenaddress == address(0)) {
            _tokenamount = msg.value; // Amount is now msg.value
            etherreward = true;
        } else {
            token = IERC20(_tokenaddress);
            etherreward = false;
            uint256 currentBalance = token.balanceOf(address(this));
            uint256 deposited = totalDeposited[_tokenaddress];

            require(
                currentBalance - deposited >= _tokenamount, // Keep original logic
                "Not enough tokens in the contract"
            );
        }

        uint256 amount;

        for (uint256 i = 0; i < userIds.length; i++) {
            string memory currentUserId = userIds[i];

            if (totalappreciation > 0) {
                uint256 userAppreciation = appreciation[currentUserId];
                amount = FullMath.mulDiv(userAppreciation, _tokenamount, totalappreciation);
            } else {
                require(userIds.length > 0, "ManagedUpgradeable.reward: Division by zero users (should not happen here)"); // Keep original check
                amount = _tokenamount / userIds.length;
            }

            if (amount > 0) {
                address recipient = userIdToAddress[currentUserId];
                // Note: recipient will be address(0) if user hasn't claimed yet
                bool isContract = recipient.code.length > 0;


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
                        token.safeTransfer(recipient, amount);
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
