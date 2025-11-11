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
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IHolonFactory.sol";
import "./HolonUpgradeable.sol";
import "forge-std/console.sol";

 contract ZonedUpgradeable is HolonUpgradeable{
    using SafeERC20 for IERC20;

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

    mapping(uint => string[]) public zonemembers;    // Maps zone number to array of member IDs
    mapping(string => uint) public zone;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory creatorUserId, address _creator, string memory _name, uint _nzones) public initializer {
        __Holon_init(_creator);
        __Zoned_init_unchained(creatorUserId, _creator, _name, _nzones);
    }

    function __Zoned_init_unchained(string memory creatorUserId, address _creator, string memory _name, uint _nzones) internal onlyInitializing {
        name = _name;
        console.log("ZonedUpgradeable.initialize: Set name to:", _name);

        creator = _creator;
        console.log("ZonedUpgradeable.initialize: Set creator to:", uint256(uint160(_creator)));

        flavor = "Zoned";
        console.log("ZonedUpgradeable.initialize: Set flavor to: Zoned");

        nzones = _nzones;
        console.log("ZonedUpgradeable.initialize: Set nzones to:", _nzones);

        // Set owner to creator and log
        owner = _creator;
        factory = msg.sender;
        console.log("ZonedUpgradeable.initialize: Set owner to creator with address: ", _creator);

        // Initialize reward parameters and call setRewardFunction
        a = 0;
        b = 0;
        c = 1;
        botAddress = 0xb2DA94d13735aF2DDCF5a3c797547290221f3DBb; // sepolia
        isZonedMember[creatorUserId] = true;
        userIds.push(creatorUserId);

        console.log("ZonedUpgradeable.initialize: Calling setRewardFunction with a, b, c =", a, b, c);
        setRewardFunction(creatorUserId, a, b, c);
        console.log("ZonedUpgradeable.initialize: setRewardFunction completed");

        console.log("ZonedUpgradeable.initialize: Exiting initialization successfully");
    }

    //=============================================================
    //                      Membrane Functions
    //=============================================================

    // Add a single member (automatically to zone 0)
    function addMember(string memory senderUserId, string memory _userId) external {
        require(msg.sender == creator || msg.sender == owner, "Only creator or owner can add members");
        require(!isZonedMember[_userId], "Member already added");

        isZonedMember[_userId] = true;
        userIds.push(_userId);

        // Add to zone 0
        zone[_userId] = 0;
        zonemembers[0].push(_userId);
    }

    function addMembers(string memory senderUserId, string[] memory _userIds) external {
        require(msg.sender == creator || msg.sender == owner, "Only creator or owner can add members");
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

    //=============================================================
    //                      Reward Functions
    //=============================================================

    function reward(address _tokenaddress, uint256 _tokenamount)
        public
        payable
        override
        nonReentrant
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

        for (uint256 z = 0;  z <= nzones; z++) { //skip zone 0 as unassigned members
            if (zonemembers[z].length > 0) {
                amount = rewardFunction(z, _tokenamount) / zonemembers[z].length; // divide reward equally for all members in the same zone
                for (uint256 i = 0; i < zonemembers[z].length; i++) {

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


    function setRewardFunction(string memory senderUserId, uint _a, uint _b, uint _c) public {
        console.log("setRewardFunction. msg.sender: ", msg.sender, "botAddress:", botAddress);
        // only core members can change reward function
        require (msg.sender == creator || msg.sender == factory, "only creator or bot can change the reward function currently");

        a = _a;
        b = _b;
        c = _c;
        rewards = calculateRewards();
    }

    // Function to calculate base rewards for zones 1 to 6
    function calculateRewards() public view returns (uint256[] memory) {
        uint256[] memory _rewards = new uint256[](6);
        uint256 total = 0;
        for (uint256 _zone = 0; _zone <= nzones; ++_zone) {
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
    }

    function addToZone(string memory senderUserId, string memory _userId, uint _zone) public
    {
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
    function removeFromZone(string memory senderUserId, string memory _userId) public {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
