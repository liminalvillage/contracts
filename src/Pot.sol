// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

/// @title Pot — a holon's pool, divided by a rights table committed once per lunation.
///
/// The Pot holds value and never splits it. Who holds a right over the pool is
/// decided off-chain (the holon's flows, cascaded down to each final person)
/// and committed here as the Merkle root of a RIGHTS TABLE: one row per
/// party and token with the party's CUMULATIVE amount and payout address.
///
/// What the contract enforces:
///  - at most one root per lunation (mean synodic month), so between two new
///    moons neither the shares, the amounts nor the payout addresses can move;
///  - a posted root waits out a challenge window before it pays anyone, the
///    previous root stays in force meanwhile, and the owner can veto it;
///  - the totals a root declares never exceed what the Pot has received and
///    never decrease, so every root is solvent on the day it is posted;
///  - a claim pays `cumulative − released` to the committed address only, and
///    the sum released per token never exceeds the committed total.
///
/// What it does not know: the split, the cascade, the scores. The table is
/// built and published off-chain (`tableRef` names it), and anyone can rebuild
/// it during the challenge window and compare roots.
contract Pot is Ownable, ReentrancyGuard, EIP712 {
    using SafeERC20 for IERC20;

    //=============================================================
    //                         Constants
    //=============================================================

    /// @notice ETH is the zero token.
    address public constant ETH = address(0);
    /// @notice Mean synodic month in seconds (29.530588853 days).
    uint256 public constant LUNATION = 2_551_443;
    /// @notice A reference new moon: 2000-01-06 18:14 UTC.
    uint256 public constant EPOCH0 = 947_182_440;
    /// @dev EIP-712 type of a signed commitment.
    bytes32 public constant ROOT_TYPEHASH =
        keccak256("Root(uint256 epoch,bytes32 root,bytes32 tableRef,address[] tokens,uint256[] totals)");

    //=============================================================
    //                          Storage
    //=============================================================

    /// @notice The holon this Pot belongs to.
    string public name;
    string public constant flavor = "Pot";
    /// @notice Seconds a posted root (or a signer change) waits before it applies.
    uint256 public immutable challenge;

    struct Commitment {
        /// The holon's own lunation index (its `lunationAt`), strictly increasing.
        uint256 epoch;
        bytes32 root;
        /// The published table (a Nostr event id), so a claimant can build a proof.
        bytes32 tableRef;
        /// When it was posted; it applies at `since + challenge`.
        uint256 since;
        address[] tokens;
        uint256[] totals;
    }

    Commitment internal _active;
    Commitment internal _pending;
    /// @notice The mean lunation of the last post; one post per lunation.
    uint256 public lastLunation;
    /// @notice The holon epoch of the last post.
    uint256 public lastEpoch;

    /// @notice Cumulative receipts per token, counted on deposit or sweep.
    mapping(address => uint256) public received;
    /// @notice The active root's committed total per token.
    mapping(address => uint256) public declared;
    /// @notice Paid out per token, across every root.
    mapping(address => uint256) public totalReleased;
    /// @notice Paid out per party (keccak of its id) and token.
    mapping(bytes32 => mapping(address => uint256)) public released;

    address[] internal _signers;
    uint256 public threshold;
    mapping(address => bool) public isSigner;
    address[] internal _pendingSigners;
    uint256 internal _pendingThreshold;
    uint256 internal _signersSince;

    //=============================================================
    //                           Events
    //=============================================================

    event Received(address indexed token, address indexed from, uint256 amount, uint256 lunation);
    event RootPosted(uint256 indexed epoch, bytes32 root, bytes32 tableRef, uint256 since, uint256 lunation);
    event RootActive(uint256 indexed epoch, bytes32 root);
    event RootVetoed(uint256 indexed epoch, bytes32 root);
    event Released(
        bytes32 indexed party,
        string partyId,
        address indexed to,
        address indexed token,
        uint256 amount,
        uint256 cumulative
    );
    event SignersProposed(address[] signers, uint256 threshold, uint256 since);
    event SignersApplied(address[] signers, uint256 threshold);

    //=============================================================
    //                        Construction
    //=============================================================

    constructor(address owner_, string memory name_, uint256 challenge_, address[] memory signers_, uint256 threshold_)
        Ownable(owner_)
        EIP712("Pot", "1")
    {
        require(bytes(name_).length > 0, "Name required");
        require(challenge_ < LUNATION, "Challenge longer than a lunation");
        name = name_;
        challenge = challenge_;
        _checkSigners(signers_, threshold_);
        _applySigners(signers_, threshold_);
    }

    //=============================================================
    //                          Receiving
    //=============================================================

    receive() external payable {
        _received(ETH, msg.sender, msg.value);
    }

    /// @notice Bring tokens in through an allowance; the lot is counted now.
    function deposit(address token, uint256 amount) external {
        require(token != ETH, "Send ETH directly");
        uint256 before = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _received(token, msg.sender, IERC20(token).balanceOf(address(this)) - before);
    }

    /// @notice Count what arrived by plain transfer (a Bundle's push, a mint) into the pool.
    function sweep(address token) external {
        uint256 unaccounted = free(token);
        require(unaccounted > 0, "Nothing to sweep");
        _received(token, msg.sender, unaccounted);
    }

    function _received(address token, address from, uint256 amount) internal {
        if (amount == 0) return;
        received[token] += amount;
        emit Received(token, from, amount, lunationAt(block.timestamp));
    }

    //=============================================================
    //                        Committing
    //=============================================================

    /// @notice Post the lunation's rights table. Needs `threshold` signers, in ascending address order.
    /// @dev Refused while a root is still pending its window, and more than once per mean lunation.
    function postRoot(
        uint256 epoch,
        bytes32 root,
        bytes32 tableRef,
        address[] calldata tokens,
        uint256[] calldata totals,
        bytes[] calldata signatures
    ) external {
        settle();
        require(_pending.root == bytes32(0), "A root is pending");
        require(root != bytes32(0), "Empty root");
        uint256 lunation = lunationAt(block.timestamp);
        require(lunation > lastLunation, "Already committed this lunation");
        require(epoch > lastEpoch, "Epoch not after the last");
        require(tokens.length == totals.length, "Array lengths do not match");

        address previous = address(0);
        for (uint256 i = 0; i < tokens.length; i++) {
            require(i == 0 || tokens[i] > previous, "Tokens not ascending");
            previous = tokens[i];
            require(totals[i] <= received[tokens[i]], "Total beyond receipts");
            require(totals[i] >= declared[tokens[i]], "Total below the committed");
        }

        _checkQuorum(rootDigest(epoch, root, tableRef, tokens, totals), signatures);

        _pending.epoch = epoch;
        _pending.root = root;
        _pending.tableRef = tableRef;
        _pending.since = block.timestamp;
        _pending.tokens = tokens;
        _pending.totals = totals;
        lastLunation = lunation;
        lastEpoch = epoch;
        emit RootPosted(epoch, root, tableRef, block.timestamp, lunation);
    }

    /// @notice Withdraw a pending root before it applies. The lunation stays spent.
    function veto() external onlyOwner {
        require(_pending.root != bytes32(0), "Nothing pending");
        emit RootVetoed(_pending.epoch, _pending.root);
        delete _pending;
    }

    /// @notice Apply whatever has waited out its window. Called by every claim and post; anyone may call it.
    function settle() public {
        if (_pending.root != bytes32(0) && block.timestamp >= _pending.since + challenge) {
            _active = _pending;
            for (uint256 i = 0; i < _active.tokens.length; i++) {
                declared[_active.tokens[i]] = _active.totals[i];
            }
            emit RootActive(_active.epoch, _active.root);
            delete _pending;
        }
        if (_signersSince != 0 && block.timestamp >= _signersSince + challenge) {
            _applySigners(_pendingSigners, _pendingThreshold);
            delete _pendingSigners;
            _pendingThreshold = 0;
            _signersSince = 0;
        }
    }

    //=============================================================
    //                          Claiming
    //=============================================================

    /// @notice Collect what a row of the active table still owes: `cumulative − released`, to the row's address.
    /// @dev Anyone may submit; the funds go to `to` as committed. A replayed row has nothing to collect.
    function claim(string calldata partyId, address to, address token, uint256 cumulative, bytes32[] calldata proof)
        external
        nonReentrant
    {
        settle();
        require(_active.root != bytes32(0), "No active root");
        require(to != address(0), "No payout address");
        bytes32 party = keccak256(bytes(partyId));
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(party, to, token, cumulative))));
        require(MerkleProof.verify(proof, _active.root, leaf), "Not in the table");

        uint256 paid = released[party][token];
        require(cumulative > paid, "Nothing to collect");
        uint256 amount = cumulative - paid;
        released[party][token] = cumulative;
        totalReleased[token] += amount;
        require(totalReleased[token] <= declared[token], "Beyond the committed total");
        emit Released(party, partyId, to, token, amount, cumulative);

        if (token == ETH) {
            (bool sent,) = to.call{value: amount}("");
            require(sent, "Paying ETH failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    //=============================================================
    //                           Signers
    //=============================================================

    /// @notice Replace the signer set; it applies after the challenge window.
    function setSigners(address[] calldata signers_, uint256 threshold_) external onlyOwner {
        _checkSigners(signers_, threshold_);
        _pendingSigners = signers_;
        _pendingThreshold = threshold_;
        _signersSince = block.timestamp;
        emit SignersProposed(signers_, threshold_, block.timestamp);
    }

    function _checkSigners(address[] memory signers_, uint256 threshold_) internal pure {
        require(signers_.length > 0, "No signers");
        require(threshold_ > 0 && threshold_ <= signers_.length, "Bad threshold");
        for (uint256 i = 0; i < signers_.length; i++) {
            require(signers_[i] != address(0), "Zero signer");
            require(i == 0 || signers_[i] > signers_[i - 1], "Signers not ascending");
        }
    }

    function _applySigners(address[] memory signers_, uint256 threshold_) internal {
        for (uint256 i = 0; i < _signers.length; i++) {
            isSigner[_signers[i]] = false;
        }
        _signers = signers_;
        threshold = threshold_;
        for (uint256 i = 0; i < signers_.length; i++) {
            isSigner[signers_[i]] = true;
        }
        emit SignersApplied(signers_, threshold_);
    }

    /// @dev `threshold` distinct signers, in ascending address order.
    function _checkQuorum(bytes32 digest, bytes[] calldata signatures) internal view {
        require(signatures.length >= threshold, "Below threshold");
        address previous = address(0);
        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = ECDSA.recover(digest, signatures[i]);
            require(signer > previous, "Signers not ascending");
            require(isSigner[signer], "Not a signer");
            previous = signer;
        }
    }

    //=============================================================
    //                            Views
    //=============================================================

    /// @notice The mean lunation a timestamp falls in.
    function lunationAt(uint256 timestamp) public pure returns (uint256) {
        return (timestamp - EPOCH0) / LUNATION;
    }

    /// @notice What a signer signs to commit a table.
    function rootDigest(
        uint256 epoch,
        bytes32 root,
        bytes32 tableRef,
        address[] calldata tokens,
        uint256[] calldata totals
    ) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    ROOT_TYPEHASH,
                    epoch,
                    root,
                    tableRef,
                    keccak256(abi.encodePacked(tokens)),
                    keccak256(abi.encodePacked(totals))
                )
            )
        );
    }

    /// @notice What the pool still owes under every root: received less released.
    function holdings(address token) public view returns (uint256) {
        return received[token] - totalReleased[token];
    }

    /// @notice What sits in the contract but has not been counted into the pool yet.
    function free(address token) public view returns (uint256) {
        uint256 balance = token == ETH ? address(this).balance : IERC20(token).balanceOf(address(this));
        return balance - holdings(token);
    }

    function active() external view returns (Commitment memory) {
        return _active;
    }

    function pending() external view returns (Commitment memory) {
        return _pending;
    }

    function signers() external view returns (address[] memory) {
        return _signers;
    }

    function pendingSigners() external view returns (address[] memory, uint256, uint256) {
        return (_pendingSigners, _pendingThreshold, _signersSince);
    }
}
