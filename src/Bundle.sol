// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/*
    Copyright 2020-2026, Roberto Valenti

    This program is free software: you can use it, redistribute it and/or modify
    it under the terms of the Peer Production License as published by
    the P2P Foundation.

    https://wiki.p2pfoundation.net/Peer_Production_License

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    Peer Production License for more details.

    ---------------------------------------------------------------------------
    RECONSTRUCTION NOTE (2026-08-30)

    The original src/Bundle.sol (compiled 2025-12-16, solc 0.8.20, deployed to
    Sepolia) was lost — only the compiled artifact survived in
    liminalvillage/holons. This file is a faithful reconstruction built from:

      * the artifact's complete ABI (signatures, events with indexed flags,
        OZ v5 errors) — the compiled ABI of this file is diffed against the
        original artifact's ABI;
      * the ancestor contracts Managed.sol / Zoned.sol / Holon.sol in
        liminalvillage/contracts (membrane, claim, reward-loop logic);
      * on-chain black-box probes of the deployed original on Sepolia
        (constructor defaults, basis-point split semantics, geometric zone
        weights, per-member zone weighting, event ordering, cascade flow).

    One deliberate behavioral FIX vs. the deployed original:
      * DistributionCompleted.cascadeCount was always emitted as 0 even when
        funds cascaded into a member contract. It now counts deliveries where
        the bound recipient is a contract.

    Election internals were not observable on-chain and are reconstructed to
    match the ABI with sensible semantics (per-round state, winner takes
    ownership when a wallet is bound).

    GUARDED CLAIM (2026-09-18) — behavioral changes vs. the 2026-08-30 build:
      * claim() is no longer open: only the owner or the wallet already bound
        to that member id may call it, and it may be called again — that is
        how a member (or the owner) re-binds. The first caller can no longer
        take a member's share for good.
      * A push that fails no longer reverts the whole distribution: ETH that
        cannot be delivered is stored for a later claim; an ERC-20 cascade
        call that fails leaves the tokens at the recipient, where anyone can
        retry it through reward(). A broken member cannot brick its holon.
      * reward(address(0), n) without value used to move `n` of the
        contract's ETH — including members' unclaimed balances — out through
        the split. ETH is now checked against stored balances like tokens.
      * Elections: nominate/vote need the owner or the member's bound wallet,
        and a contract-bound member can neither run nor become owner (a
        Bundle owning a Bundle could never call syncAll again).
      * addMember(s) are owner-only; transferOwnership() exists.
    ---------------------------------------------------------------------------

    A Bundle is a self-contained holon treasury: incoming value is split
    between an interior circle (named members with explicit basis-point
    shares) and an exterior ring structure (federated members placed in
    zones whose weights decay geometrically with `steepness`). Members with
    a bound wallet get pushed funds — a bound *contract* receives the push
    through its own receive() and re-distributes: the federation cascade.
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Bundle is ReentrancyGuard {
    using SafeERC20 for IERC20;

    //======================== Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant WAD = 1e18;

    //======================== Identity
    string public name;
    string public flavor;
    address public owner;
    address public creator;
    address public factory;

    //======================== Split configuration
    uint256 public steepness; // WAD scale, 0 < s < 1e18
    uint256 public nzones;
    uint256 public interiorPercentage; // basis points
    uint256 public exteriorPercentage; // basis points

    //======================== Membrane
    string[] public userIds;
    mapping(string => bool) public isBundleMember;
    mapping(string => address) public userIdToAddress;
    mapping(string => bool) public hasClaimed;
    mapping(string => uint256) public etherBalance;
    mapping(string => mapping(address => uint256)) public tokenBalance;
    mapping(string => address[]) public tokensOf;
    mapping(address => uint256) public totalDeposited;
    /// @dev ETH held for unbound members; everything above it is distributable.
    uint256 public totalEtherDeposited;

    //======================== Interior (contribution split)
    string[] public interiorMembers;
    mapping(string => uint256) public interiorShare; // basis points
    mapping(string => bool) public isInteriorMember;

    //======================== Exterior (federation zones)
    mapping(uint256 => string[]) public zonemembers;
    mapping(string => uint256) public zone; // 0 = unplaced
    mapping(string => bool) public isExteriorMember;
    uint256[] public zoneWeights; // index z = WAD * (steepness/WAD)^z

    //======================== Elections
    bool public electionActive;
    string[] public candidates;
    uint256 private electionRound;
    mapping(uint256 => mapping(string => uint256)) private _votes;
    mapping(uint256 => mapping(string => bool)) private _hasVoted;
    mapping(uint256 => mapping(string => string)) private _votedFor;
    mapping(uint256 => mapping(string => bool)) private _isCandidate;

    //======================== Events
    event CandidateNominated(string userId);
    event ContractSplitSet(uint256 interior, uint256 exterior);
    event DistributionCompleted(
        address indexed contractAddress,
        string holonId,
        address tokenAddress,
        uint256 totalAmount,
        uint256 recipientCount,
        uint256 cascadeCount
    );
    event ElectionCancelled();
    event ElectionFinalized(string winner, uint256 voteCount);
    event ElectionStarted();
    event FundsAllocated(
        address indexed contractAddress,
        string holonId,
        string userId,
        address tokenAddress,
        uint256 amount,
        string distributionType
    );
    event FundsClaimed(
        address indexed contractAddress,
        string holonId,
        string userId,
        address indexed beneficiary,
        address tokenAddress,
        uint256 amount
    );
    event FundsReceived(
        address indexed contractAddress,
        address indexed sender,
        address tokenAddress,
        uint256 amount
    );
    event FundsTransferred(
        address indexed contractAddress,
        string holonId,
        string userId,
        address indexed recipient,
        address tokenAddress,
        uint256 amount
    );
    event InteriorSplitSet(string[] userIds, uint256[] percentages);
    event MemberAdded(string userId);
    event MemberAddedStd(
        address indexed contractAddress,
        string holonId,
        string userId,
        address addedBy
    );
    event MemberAssignedToZone(string userId, uint256 zoneNumber);
    event MemberBound(
        string userId,
        address indexed previousBeneficiary,
        address indexed beneficiary
    );
    event MemberRemovedFromZone(string userId);
    event MemberRewarded(
        address indexed from,
        address indexed to,
        uint256 amount,
        bool isContract,
        string rewardType
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    /// @notice A bound recipient refused a push. ETH was stored for a later
    ///         claim; ERC-20 sits at the recipient, whose reward() anyone
    ///         may call again.
    event PushFailed(
        address indexed contractAddress,
        string userId,
        address indexed recipient,
        address tokenAddress,
        uint256 amount
    );
    event RewardDistributed(
        address indexed contractAddress,
        uint256 amount,
        uint256 totalMembers,
        string rewardType
    );
    event SteepnessSet(uint256 steepness);
    event VoteCast(string voter, string candidate);
    event ZoneAssigned(
        address indexed contractAddress,
        string holonId,
        string userId,
        uint256 oldZone,
        uint256 newZone
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /// @dev The owner, or the wallet a member id is already bound to. The
    ///      owner already decides every share, so binding adds no power.
    modifier onlyOwnerOrBound(string memory _userId) {
        address bound = userIdToAddress[_userId];
        require(
            msg.sender == owner || (bound != address(0) && msg.sender == bound),
            "Not authorized"
        );
        _;
    }

    constructor(
        address _owner,
        string memory _creatorUserId,
        string memory _name,
        uint256 _steepness,
        uint256 _nzones
    ) {
        require(_steepness > 0 && _steepness < WAD, "Invalid steepness");
        name = _name;
        flavor = "Bundle";
        owner = _owner;
        creator = _owner;
        factory = msg.sender;
        steepness = _steepness;
        nzones = _nzones;
        _recomputeZoneWeights();

        isBundleMember[_creatorUserId] = true;
        userIds.push(_creatorUserId);
    }

    //=============================================================
    //                      Membrane
    //=============================================================

    function addMember(string memory _userId) external onlyOwner {
        _addMember(_userId);
    }

    function addMembers(string[] memory _userIds) external onlyOwner {
        for (uint256 i = 0; i < _userIds.length; i++) {
            _addMember(_userIds[i]);
        }
    }

    function _addMember(string memory _userId) internal {
        if (isBundleMember[_userId]) return; // gently fail if already added
        isBundleMember[_userId] = true;
        userIds.push(_userId);
        emit MemberAdded(_userId);
        emit MemberAddedStd(address(this), name, _userId, msg.sender);
    }

    function getSize() external view returns (uint256) {
        return userIds.length;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function getTokensOf(
        string memory _userId
    ) public view returns (address[] memory) {
        return tokensOf[_userId];
    }

    //=============================================================
    //                      Split configuration
    //=============================================================

    function setContractSplit(
        uint256 _interior,
        uint256 _exterior
    ) public onlyOwner {
        require(_interior + _exterior == BASIS_POINTS, "Must sum to 10000");
        interiorPercentage = _interior;
        exteriorPercentage = _exterior;
        emit ContractSplitSet(_interior, _exterior);
    }

    function setInteriorSplit(
        string[] memory _userIds,
        uint256[] memory _percentages
    ) public onlyOwner {
        require(
            _userIds.length == _percentages.length,
            "Array lengths do not match"
        );

        // clear the previous interior circle
        for (uint256 i = 0; i < interiorMembers.length; i++) {
            interiorShare[interiorMembers[i]] = 0;
            isInteriorMember[interiorMembers[i]] = false;
        }
        delete interiorMembers;

        if (_userIds.length > 0) {
            uint256 total = 0;
            for (uint256 i = 0; i < _percentages.length; i++) {
                total += _percentages[i];
            }
            require(total == BASIS_POINTS, "Must sum to 10000");

            for (uint256 i = 0; i < _userIds.length; i++) {
                _addMember(_userIds[i]);
                interiorMembers.push(_userIds[i]);
                interiorShare[_userIds[i]] = _percentages[i];
                isInteriorMember[_userIds[i]] = true;
            }
        }
        emit InteriorSplitSet(_userIds, _percentages);
    }

    function setSteepness(uint256 _steepness) public onlyOwner {
        require(_steepness > 0 && _steepness < WAD, "Invalid steepness");
        steepness = _steepness;
        _recomputeZoneWeights();
        emit SteepnessSet(_steepness);
    }

    function setNzones(uint256 _nzones) public onlyOwner {
        // members already placed above the new count keep their zone number;
        // zones beyond nzones simply stop receiving until reassigned
        nzones = _nzones;
        _recomputeZoneWeights();
    }

    function _recomputeZoneWeights() internal {
        delete zoneWeights;
        uint256 w = WAD;
        for (uint256 z = 0; z <= nzones; z++) {
            zoneWeights.push(w);
            w = (w * steepness) / WAD;
        }
    }

    function getZoneWeights() external view returns (uint256[] memory) {
        return zoneWeights;
    }

    //=============================================================
    //                      Exterior zones (federation)
    //=============================================================

    function assignToZone(string memory _userId, uint256 _zone) public onlyOwner {
        _assignToZone(_userId, _zone);
    }

    function assignMembersToZones(
        string[] memory _userIds,
        uint256[] memory _zones
    ) public onlyOwner {
        require(_userIds.length == _zones.length, "Array lengths do not match");
        for (uint256 i = 0; i < _userIds.length; i++) {
            _assignToZone(_userIds[i], _zones[i]);
        }
    }

    function _assignToZone(string memory _userId, uint256 _zone) internal {
        require(_zone >= 1 && _zone <= nzones, "Invalid zone");
        _addMember(_userId);

        uint256 previous = zone[_userId];
        if (isExteriorMember[_userId]) {
            _removeFromZoneList(previous, _userId);
        }
        zone[_userId] = _zone;
        zonemembers[_zone].push(_userId);
        isExteriorMember[_userId] = true;

        emit MemberAssignedToZone(_userId, _zone);
        emit ZoneAssigned(address(this), name, _userId, previous, _zone);
    }

    function removeFromExterior(string memory _userId) public onlyOwner {
        require(isExteriorMember[_userId], "Not an exterior member");
        _removeFromZoneList(zone[_userId], _userId);
        zone[_userId] = 0;
        isExteriorMember[_userId] = false;
        emit MemberRemovedFromZone(_userId);
    }

    function _removeFromZoneList(uint256 _zone, string memory _userId) internal {
        string[] storage members = zonemembers[_zone];
        bytes32 target = keccak256(abi.encodePacked(_userId));
        for (uint256 i = 0; i < members.length; i++) {
            if (keccak256(abi.encodePacked(members[i])) == target) {
                members[i] = members[members.length - 1];
                members.pop();
                break;
            }
        }
    }

    function getZoneMembers(
        uint256 _zone
    ) external view returns (string[] memory) {
        return zonemembers[_zone];
    }

    function getInteriorMembers() external view returns (string[] memory) {
        return interiorMembers;
    }

    /// @notice Sum of every placed exterior member's zone weight (WAD scale).
    function totalWeightedMembers() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 z = 1; z <= nzones; z++) {
            total += zonemembers[z].length * zoneWeights[z];
        }
        return total;
    }

    /// @notice One transaction to configure the whole split.
    function syncAll(
        uint256 _interior,
        uint256 _exterior,
        uint256 _steepness,
        uint256 _nzones,
        string[] memory _interiorUserIds,
        uint256[] memory _interiorPercentages,
        string[] memory _exteriorUserIds,
        uint256[] memory _exteriorZones
    ) external onlyOwner {
        setContractSplit(_interior, _exterior);
        setSteepness(_steepness);
        setNzones(_nzones);
        setInteriorSplit(_interiorUserIds, _interiorPercentages);

        // clear every current exterior placement, then apply the new ones
        for (uint256 z = 1; z <= _nzones; z++) {
            string[] storage members = zonemembers[z];
            for (uint256 i = members.length; i > 0; i--) {
                string memory userId = members[i - 1];
                zone[userId] = 0;
                isExteriorMember[userId] = false;
                members.pop();
            }
        }
        require(
            _exteriorUserIds.length == _exteriorZones.length,
            "Array lengths do not match"
        );
        for (uint256 i = 0; i < _exteriorUserIds.length; i++) {
            _assignToZone(_exteriorUserIds[i], _exteriorZones[i]);
        }
    }

    //=============================================================
    //                      Reward / distribution
    //=============================================================

    receive() external payable {
        _distribute(address(0), msg.value);
    }

    fallback() external payable {
        _distribute(address(0), msg.value);
    }

    /// @notice Irrigate `_tokenamount` of `_tokenaddress` (or msg.value of
    ///         ETH) through the interior/exterior split.
    function reward(
        address _tokenaddress,
        uint256 _tokenamount
    ) public payable {
        if (msg.value > 0 && _tokenaddress == address(0)) {
            _tokenamount = msg.value;
        }
        _distribute(_tokenaddress, _tokenamount);
    }

    function _distribute(
        address _tokenaddress,
        uint256 _tokenamount
    ) internal nonReentrant {
        bool etherreward = _tokenaddress == address(0);
        if (_tokenamount == 0) return;

        // only what is not held for an unbound member may be distributed
        if (etherreward) {
            require(
                address(this).balance - totalEtherDeposited >= _tokenamount,
                "Not enough ether in the contract"
            );
        } else {
            IERC20 token = IERC20(_tokenaddress);
            require(
                token.balanceOf(address(this)) - totalDeposited[_tokenaddress] >=
                    _tokenamount,
                "Not enough tokens in the contract"
            );
        }

        emit FundsReceived(address(this), msg.sender, _tokenaddress, _tokenamount);

        uint256 recipients = 0;
        uint256 cascades = 0;

        // interior: explicit basis-point shares
        uint256 interiorPot = (_tokenamount * interiorPercentage) / BASIS_POINTS;
        for (uint256 i = 0; i < interiorMembers.length; i++) {
            string memory userId = interiorMembers[i];
            uint256 amount = (interiorPot * interiorShare[userId]) / BASIS_POINTS;
            if (amount > 0) {
                bool cascaded = _deliver(
                    userId,
                    _tokenaddress,
                    amount,
                    etherreward,
                    "percentage"
                );
                recipients++;
                if (cascaded) cascades++;
            }
        }

        // exterior: geometric zone weights, per placed member
        uint256 exteriorPot = (_tokenamount * exteriorPercentage) / BASIS_POINTS;
        uint256 weighted = totalWeightedMembers();
        if (exteriorPot > 0 && weighted > 0) {
            for (uint256 z = 1; z <= nzones; z++) {
                string[] storage members = zonemembers[z];
                for (uint256 i = 0; i < members.length; i++) {
                    uint256 amount = (exteriorPot * zoneWeights[z]) / weighted;
                    if (amount > 0) {
                        bool cascaded = _deliver(
                            members[i],
                            _tokenaddress,
                            amount,
                            etherreward,
                            "zone"
                        );
                        recipients++;
                        if (cascaded) cascades++;
                    }
                }
            }
        }

        emit RewardDistributed(
            address(this),
            _tokenamount,
            recipients,
            etherreward ? "ETH" : "ERC20"
        );
        emit DistributionCompleted(
            address(this),
            name,
            _tokenaddress,
            _tokenamount,
            recipients,
            cascades // FIX: was always 0 in the 2025-12 deployment
        );
    }

    /// @dev Push to a bound recipient (cascading into contracts), or store
    ///      for later claim. Returns true when the delivery cascaded into a
    ///      contract recipient. A refused push is stored (ETH) or left at the
    ///      recipient (ERC-20) rather than reverting: one broken member must
    ///      not stop the whole holon from being paid.
    function _deliver(
        string memory _userId,
        address _tokenaddress,
        uint256 _amount,
        bool _etherreward,
        string memory _distributionType
    ) internal returns (bool) {
        address recipient = userIdToAddress[_userId];
        bool isContract = recipient.code.length > 0;

        if (hasClaimed[_userId] && recipient != address(0)) {
            bool cascaded = false;
            if (_etherreward) {
                (bool success, ) = payable(recipient).call{value: _amount}("");
                if (!success) {
                    emit PushFailed(address(this), _userId, recipient, _tokenaddress, _amount);
                    _store(_userId, _tokenaddress, _amount, _etherreward, _distributionType);
                    return false;
                }
                cascaded = isContract;
                emit MemberRewarded(
                    address(this),
                    recipient,
                    _amount,
                    isContract,
                    "ETH"
                );
            } else {
                IERC20(_tokenaddress).safeTransfer(recipient, _amount);
                if (isContract) {
                    // federation cascade: ask the member holon to re-distribute
                    cascaded = _callReward(recipient, _tokenaddress, _amount);
                    if (!cascaded) {
                        emit PushFailed(address(this), _userId, recipient, _tokenaddress, _amount);
                    }
                }
                emit MemberRewarded(
                    address(this),
                    recipient,
                    _amount,
                    isContract,
                    "ERC20"
                );
            }
            emit FundsTransferred(
                address(this),
                name,
                _userId,
                recipient,
                _tokenaddress,
                _amount
            );
            return cascaded;
        }

        _store(_userId, _tokenaddress, _amount, _etherreward, _distributionType);
        return false;
    }

    /// @dev Ask a contract recipient to re-distribute what it was just sent.
    function _callReward(
        address _recipient,
        address _tokenaddress,
        uint256 _amount
    ) internal returns (bool) {
        (bool success, ) = _recipient.call(
            abi.encodeWithSignature(
                "reward(address,uint256)",
                _tokenaddress,
                _amount
            )
        );
        return success;
    }

    /// @dev Hold a member's share until it is claimed.
    function _store(
        string memory _userId,
        address _tokenaddress,
        uint256 _amount,
        bool _etherreward,
        string memory _distributionType
    ) internal {
        if (_etherreward) {
            etherBalance[_userId] += _amount;
            totalEtherDeposited += _amount;
            emit MemberRewarded(
                address(this),
                address(0),
                _amount,
                false,
                "STORED_ETH"
            );
        } else {
            if (tokenBalance[_userId][_tokenaddress] == 0) {
                tokensOf[_userId].push(_tokenaddress);
            }
            tokenBalance[_userId][_tokenaddress] += _amount;
            totalDeposited[_tokenaddress] += _amount;
            emit MemberRewarded(
                address(this),
                address(0),
                _amount,
                false,
                "STORED_ERC20"
            );
        }
        emit FundsAllocated(
            address(this),
            name,
            _userId,
            _tokenaddress,
            _amount,
            _distributionType
        );
    }

    //=============================================================
    //                      Claims
    //=============================================================

    /// @notice Bind a member's wallet and pay out their stored balances.
    ///         Future rewards are pushed to `_beneficiary` directly; a
    ///         contract beneficiary makes the member a cascading sub-holon.
    ///         Only the owner or the wallet already bound to `_userId` may
    ///         call this, and calling it again re-binds — a member can move
    ///         their share to a new wallet, and the owner can free a share
    ///         from a recipient that refuses it. Unlike a distribution, the
    ///         payout here must succeed: a beneficiary that cannot take it
    ///         is rejected at binding time.
    function claim(
        string memory _userId,
        address _beneficiary
    ) external nonReentrant onlyOwnerOrBound(_userId) {
        require(isBundleMember[_userId], "Not a member");
        require(_beneficiary != address(0), "Invalid beneficiary address");
        address previous = userIdToAddress[_userId];
        if (previous != _beneficiary) {
            userIdToAddress[_userId] = _beneficiary;
            emit MemberBound(_userId, previous, _beneficiary);
        }
        hasClaimed[_userId] = true;

        uint256 amount = etherBalance[_userId];
        if (amount > 0) {
            etherBalance[_userId] = 0;
            totalEtherDeposited -= amount;
            (bool sent, ) = _beneficiary.call{value: amount}("");
            require(sent, "Claiming Ether failed");
            emit FundsClaimed(
                address(this),
                name,
                _userId,
                _beneficiary,
                address(0),
                amount
            );
        }

        address[] memory tokens = tokensOf[_userId];
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenAmount = tokenBalance[_userId][tokens[i]];
            if (tokenAmount > 0) {
                tokenBalance[_userId][tokens[i]] = 0;
                totalDeposited[tokens[i]] -= tokenAmount;
                IERC20(tokens[i]).safeTransfer(_beneficiary, tokenAmount);
                if (_beneficiary.code.length > 0) {
                    // a sub-holon divides what it was just handed
                    require(
                        _callReward(_beneficiary, tokens[i], tokenAmount),
                        "Beneficiary refused the cascade"
                    );
                }
                emit FundsClaimed(
                    address(this),
                    name,
                    _userId,
                    _beneficiary,
                    tokens[i],
                    tokenAmount
                );
            }
        }
    }

    //=============================================================
    //                      Elections
    //=============================================================

    function startElection() external onlyOwner {
        require(!electionActive, "Election already active");
        electionRound++;
        delete candidates;
        electionActive = true;
        emit ElectionStarted();
    }

    function cancelElection() external onlyOwner {
        require(electionActive, "No active election");
        electionActive = false;
        emit ElectionCancelled();
    }

    function nominateSelf(
        string memory _userId
    ) external onlyOwnerOrBound(_userId) {
        require(electionActive, "No active election");
        require(isBundleMember[_userId], "Not a member");
        require(_canOwn(_userId), "A contract cannot own the Bundle");
        require(!_isCandidate[electionRound][_userId], "Already nominated");
        _isCandidate[electionRound][_userId] = true;
        candidates.push(_userId);
        emit CandidateNominated(_userId);
    }

    function vote(
        string memory _voterId,
        string memory _candidateId
    ) external onlyOwnerOrBound(_voterId) {
        require(electionActive, "No active election");
        require(isBundleMember[_voterId], "Not a member");
        require(_isCandidate[electionRound][_candidateId], "Not a candidate");
        require(!_hasVoted[electionRound][_voterId], "Already voted");
        _hasVoted[electionRound][_voterId] = true;
        _votedFor[electionRound][_voterId] = _candidateId;
        _votes[electionRound][_candidateId]++;
        emit VoteCast(_voterId, _candidateId);
    }

    function finalizeElection() external onlyOwner {
        require(electionActive, "No active election");
        require(candidates.length > 0, "No candidates");

        string memory winner = candidates[0];
        uint256 winnerVotes = _votes[electionRound][winner];
        for (uint256 i = 1; i < candidates.length; i++) {
            uint256 candidateVotes = _votes[electionRound][candidates[i]];
            if (candidateVotes > winnerVotes) {
                winner = candidates[i];
                winnerVotes = candidateVotes;
            }
        }

        electionActive = false;
        emit ElectionFinalized(winner, winnerVotes);

        // the binding may have moved since nomination: a contract never owns
        address newOwner = userIdToAddress[winner];
        if (newOwner != address(0) && newOwner != owner && _canOwn(winner)) {
            emit OwnershipTransferred(owner, newOwner);
            owner = newOwner;
        }
    }

    /// @dev A Bundle owned by another Bundle could never be configured
    ///      again (a contract cannot call syncAll), so a member whose bound
    ///      wallet is a contract may not be elected. Unbound members have no
    ///      wallet to hand ownership to and are refused at nomination too.
    function _canOwn(string memory _userId) internal view returns (bool) {
        address bound = userIdToAddress[_userId];
        return bound != address(0) && bound.code.length == 0;
    }

    function getCandidates() external view returns (string[] memory) {
        return candidates;
    }

    function votes(string memory _userId) external view returns (uint256) {
        return _votes[electionRound][_userId];
    }

    function hasVoted(string memory _userId) external view returns (bool) {
        return _hasVoted[electionRound][_userId];
    }

    function votedFor(
        string memory _userId
    ) external view returns (string memory) {
        return _votedFor[electionRound][_userId];
    }

    function isCandidate(string memory _userId) external view returns (bool) {
        return _isCandidate[electionRound][_userId];
    }
}
