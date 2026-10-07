// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../src/Pot.sol";
import "../../src/TestToken.sol";

/// A payout address that tries to collect again while being paid.
contract Reenterer {
    Pot pot;
    string party;
    uint256 cumulative;
    bytes32[] proof;

    constructor(Pot pot_) {
        pot = pot_;
    }

    function arm(string memory party_, uint256 cumulative_, bytes32[] memory proof_) external {
        party = party_;
        cumulative = cumulative_;
        proof = proof_;
    }

    receive() external payable {
        pot.claim(party, address(this), address(0), cumulative, proof);
    }
}

/// Pot: value held, a rights table committed once per lunation, one direct
/// transfer per claim.
contract PotTest is Test {
    uint256 constant T0 = 1_791_000_000; // 2026-10-07
    uint256 constant CHALLENGE = 3 days;

    address owner = makeAddr("owner");
    address stranger = makeAddr("stranger");
    address funder = makeAddr("funder");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    address s1;
    uint256 k1;
    address s2;
    uint256 k2;
    address s3;
    uint256 k3;

    Pot pot;
    TestToken token;

    // one row of the table
    struct Row {
        string party;
        address to;
        address token;
        uint256 cumulative;
    }

    function setUp() public {
        vm.warp(T0);
        (s1, k1) = makeAddrAndKey("signer-1");
        (s2, k2) = makeAddrAndKey("signer-2");
        (s3, k3) = makeAddrAndKey("signer-3");
        // the contract wants signers in ascending address order
        if (s1 > s2) (s1, k1, s2, k2) = (s2, k2, s1, k1);
        if (s2 > s3) (s2, k2, s3, k3) = (s3, k3, s2, k2);
        if (s1 > s2) (s1, k1, s2, k2) = (s2, k2, s1, k1);

        address[] memory signers = new address[](2);
        signers[0] = s1;
        signers[1] = s2;
        pot = new Pot(owner, "holon_test", CHALLENGE, signers, 2);

        token = new TestToken(1_000_000 ether);
        vm.deal(funder, 100 ether);
    }

    //=============================================================
    //                          Helpers
    //=============================================================

    function leafOf(Row memory r) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(keccak256(bytes(r.party)), r.to, r.token, r.cumulative))));
    }

    function pair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    /// Two-row table: root and the proof for each row.
    function table2(Row memory a, Row memory b)
        internal
        pure
        returns (bytes32 root, bytes32[] memory pa, bytes32[] memory pb)
    {
        bytes32 la = leafOf(a);
        bytes32 lb = leafOf(b);
        root = pair(la, lb);
        pa = new bytes32[](1);
        pa[0] = lb;
        pb = new bytes32[](1);
        pb[0] = la;
    }

    function sign(uint256 key, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function quorum(bytes32 digest) internal view returns (bytes[] memory sigs) {
        sigs = new bytes[](2);
        sigs[0] = sign(k1, digest);
        sigs[1] = sign(k2, digest);
    }

    function one(address t, uint256 total) internal pure returns (address[] memory tokens, uint256[] memory totals) {
        tokens = new address[](1);
        tokens[0] = t;
        totals = new uint256[](1);
        totals[0] = total;
    }

    /// Post a root over one token with the full quorum.
    function post(uint256 epoch, bytes32 root, address t, uint256 total) internal {
        postExpecting("", epoch, root, t, total);
    }

    /// Post, expecting `reason` when it is not empty (the digest is a view call, so
    /// `expectRevert` must come right before `postRoot`).
    function postExpecting(string memory reason, uint256 epoch, bytes32 root, address t, uint256 total) internal {
        (address[] memory tokens, uint256[] memory totals) = one(t, total);
        bytes32 digest = pot.rootDigest(epoch, root, bytes32(uint256(epoch)), tokens, totals);
        bytes[] memory sigs = quorum(digest);
        if (bytes(reason).length > 0) vm.expectRevert(bytes(reason));
        pot.postRoot(epoch, root, bytes32(uint256(epoch)), tokens, totals, sigs);
    }

    function fundEth(uint256 amount) internal {
        vm.prank(funder);
        (bool ok,) = address(pot).call{value: amount}("");
        require(ok);
    }

    function nextLunation() internal {
        vm.warp((pot.lunationAt(block.timestamp) + 1) * pot.LUNATION() + pot.EPOCH0() + 1 hours);
    }

    //=============================================================
    //                          Receiving
    //=============================================================

    function test_receive_countsEthIntoThePool() public {
        fundEth(10 ether);
        assertEq(pot.received(address(0)), 10 ether);
        assertEq(pot.holdings(address(0)), 10 ether);
        assertEq(pot.free(address(0)), 0);
    }

    function test_deposit_countsTokensThroughAnAllowance() public {
        token.approve(address(pot), 500 ether);
        pot.deposit(address(token), 500 ether);
        assertEq(pot.received(address(token)), 500 ether);
    }

    function test_sweep_countsAPlainTransfer() public {
        token.transfer(address(pot), 300 ether);
        assertEq(pot.received(address(token)), 0);
        assertEq(pot.free(address(token)), 300 ether);
        vm.prank(stranger);
        pot.sweep(address(token));
        assertEq(pot.received(address(token)), 300 ether);
        assertEq(pot.free(address(token)), 0);
        vm.expectRevert("Nothing to sweep");
        pot.sweep(address(token));
    }

    //=============================================================
    //                         Committing
    //=============================================================

    function test_post_belowThresholdIsRefused() public {
        fundEth(1 ether);
        (address[] memory tokens, uint256[] memory totals) = one(address(0), 1 ether);
        bytes32 root = keccak256("root");
        bytes32 digest = pot.rootDigest(1, root, bytes32(0), tokens, totals);
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = sign(k1, digest);
        vm.expectRevert("Below threshold");
        pot.postRoot(1, root, bytes32(0), tokens, totals, sigs);
    }

    function test_post_strangerSignatureIsRefused() public {
        fundEth(1 ether);
        (address[] memory tokens, uint256[] memory totals) = one(address(0), 1 ether);
        bytes32 root = keccak256("root");
        bytes32 digest = pot.rootDigest(1, root, bytes32(0), tokens, totals);
        (, uint256 kx) = makeAddrAndKey("outsider");
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = sign(k1, digest);
        sigs[1] = sign(kx, digest);
        vm.expectRevert();
        pot.postRoot(1, root, bytes32(0), tokens, totals, sigs);
    }

    function test_post_oneSignerTwiceIsRefused() public {
        fundEth(1 ether);
        (address[] memory tokens, uint256[] memory totals) = one(address(0), 1 ether);
        bytes32 root = keccak256("root");
        bytes32 digest = pot.rootDigest(1, root, bytes32(0), tokens, totals);
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = sign(k1, digest);
        sigs[1] = sign(k1, digest);
        vm.expectRevert("Signers not ascending");
        pot.postRoot(1, root, bytes32(0), tokens, totals, sigs);
    }

    function test_post_totalBeyondReceiptsIsRefused() public {
        fundEth(1 ether);
        (address[] memory tokens, uint256[] memory totals) = one(address(0), 2 ether);
        bytes32 root = keccak256("root");
        bytes32 digest = pot.rootDigest(1, root, bytes32(0), tokens, totals);
        vm.expectRevert("Total beyond receipts");
        pot.postRoot(1, root, bytes32(0), tokens, totals, quorum(digest));
    }

    function test_post_onlyOncePerLunation() public {
        fundEth(1 ether);
        post(1, keccak256("a"), address(0), 1 ether);
        vm.warp(block.timestamp + CHALLENGE);
        postExpecting("Already committed this lunation", 2, keccak256("b"), address(0), 1 ether);
    }

    /// A long window on a post made late in the lunation: the next lunation
    /// starts while the first root is still pending.
    function test_post_refusedWhileOneIsPending() public {
        address[] memory signers = new address[](2);
        signers[0] = s1;
        signers[1] = s2;
        Pot slow = new Pot(owner, "slow", 20 days, signers, 2);
        vm.prank(funder);
        (bool ok,) = address(slow).call{value: 1 ether}("");
        require(ok);
        (address[] memory tokens, uint256[] memory totals) = one(address(0), 1 ether);
        bytes32 digest = slow.rootDigest(1, keccak256("a"), bytes32(0), tokens, totals);
        slow.postRoot(1, keccak256("a"), bytes32(0), tokens, totals, quorumFor(slow, digest));
        // next mean lunation starts within 20 days of a post made late in this one
        vm.warp((slow.lunationAt(block.timestamp) + 1) * slow.LUNATION() + slow.EPOCH0() + 1);
        digest = slow.rootDigest(2, keccak256("b"), bytes32(0), tokens, totals);
        vm.expectRevert("A root is pending");
        slow.postRoot(2, keccak256("b"), bytes32(0), tokens, totals, quorumFor(slow, digest));
    }

    function quorumFor(Pot p, bytes32 digest) internal view returns (bytes[] memory sigs) {
        p; // same signer keys on every Pot in these tests
        sigs = new bytes[](2);
        sigs[0] = sign(k1, digest);
        sigs[1] = sign(k2, digest);
    }

    function test_post_epochMustIncrease() public {
        fundEth(1 ether);
        post(5, keccak256("a"), address(0), 1 ether);
        nextLunation();
        postExpecting("Epoch not after the last", 5, keccak256("b"), address(0), 1 ether);
    }

    function test_post_totalNeverDecreases() public {
        fundEth(2 ether);
        post(1, keccak256("a"), address(0), 2 ether);
        nextLunation();
        postExpecting("Total below the committed", 2, keccak256("b"), address(0), 1 ether);
    }

    function test_post_rootSignedForAnotherChainIsRefused() public {
        fundEth(1 ether);
        (address[] memory tokens, uint256[] memory totals) = one(address(0), 1 ether);
        bytes32 root = keccak256("root");
        bytes32 digest = pot.rootDigest(1, root, bytes32(0), tokens, totals);
        bytes[] memory sigs = quorum(digest);
        vm.chainId(999);
        vm.expectRevert();
        pot.postRoot(1, root, bytes32(0), tokens, totals, sigs);
    }

    //=============================================================
    //                      Window and veto
    //=============================================================

    function test_pendingRootPaysNothingUntilTheWindowPasses() public {
        fundEth(10 ether);
        Row memory a = Row("alice", alice, address(0), 6 ether);
        Row memory b = Row("bob", bob, address(0), 4 ether);
        (bytes32 root, bytes32[] memory pa,) = table2(a, b);
        post(1, root, address(0), 10 ether);

        vm.expectRevert("No active root");
        pot.claim("alice", alice, address(0), 6 ether, pa);

        vm.warp(block.timestamp + CHALLENGE);
        pot.claim("alice", alice, address(0), 6 ether, pa);
        assertEq(alice.balance, 6 ether);
        assertEq(pot.released(keccak256("alice"), address(0)), 6 ether);
        assertEq(pot.holdings(address(0)), 4 ether);
    }

    function test_veto_dropsThePendingRootAndSpendsTheLunation() public {
        fundEth(10 ether);
        Row memory a = Row("alice", alice, address(0), 6 ether);
        Row memory b = Row("bob", bob, address(0), 4 ether);
        (bytes32 root,,) = table2(a, b);
        post(1, root, address(0), 10 ether);

        vm.prank(stranger);
        vm.expectRevert();
        pot.veto();

        vm.prank(owner);
        pot.veto();
        assertEq(pot.pending().root, bytes32(0));

        vm.warp(block.timestamp + CHALLENGE);
        postExpecting("Already committed this lunation", 2, root, address(0), 10 ether);
    }

    function test_veto_keepsThePreviousRootCollectable() public {
        fundEth(10 ether);
        Row memory a = Row("alice", alice, address(0), 6 ether);
        Row memory b = Row("bob", bob, address(0), 4 ether);
        (bytes32 root, bytes32[] memory pa, bytes32[] memory pb) = table2(a, b);
        post(1, root, address(0), 10 ether);
        vm.warp(block.timestamp + CHALLENGE);
        pot.claim("alice", alice, address(0), 6 ether, pa);

        nextLunation();
        post(2, keccak256("bad"), address(0), 10 ether);
        vm.prank(owner);
        pot.veto();

        // bob still collects under the first root
        pot.claim("bob", bob, address(0), 4 ether, pb);
        assertEq(bob.balance, 4 ether);
    }

    //=============================================================
    //                          Claiming
    //=============================================================

    function _activate(Row memory a, Row memory b, uint256 epoch, address t, uint256 total)
        internal
        returns (bytes32[] memory pa, bytes32[] memory pb)
    {
        bytes32 root;
        (root, pa, pb) = table2(a, b);
        post(epoch, root, t, total);
        vm.warp(block.timestamp + CHALLENGE);
    }

    function test_claim_wrongProofOrAddressIsRefused() public {
        fundEth(10 ether);
        Row memory a = Row("alice", alice, address(0), 6 ether);
        Row memory b = Row("bob", bob, address(0), 4 ether);
        (bytes32[] memory pa,) = _activate(a, b, 1, address(0), 10 ether);

        vm.expectRevert("Not in the table");
        pot.claim("alice", stranger, address(0), 6 ether, pa);
        vm.expectRevert("Not in the table");
        pot.claim("alice", alice, address(0), 7 ether, pa);
        vm.expectRevert("Not in the table");
        pot.claim("bob", bob, address(0), 4 ether, pa);
    }

    function test_claim_zeroAddressRowIsRefused() public {
        fundEth(10 ether);
        Row memory a = Row("alice", address(0), address(0), 6 ether);
        Row memory b = Row("bob", bob, address(0), 4 ether);
        (bytes32[] memory pa,) = _activate(a, b, 1, address(0), 10 ether);
        vm.expectRevert("No payout address");
        pot.claim("alice", address(0), address(0), 6 ether, pa);
    }

    function test_claim_replayCollectsNothing() public {
        fundEth(10 ether);
        Row memory a = Row("alice", alice, address(0), 6 ether);
        Row memory b = Row("bob", bob, address(0), 4 ether);
        (bytes32[] memory pa,) = _activate(a, b, 1, address(0), 10 ether);
        vm.prank(stranger); // anyone may submit; it pays alice
        pot.claim("alice", alice, address(0), 6 ether, pa);
        vm.expectRevert("Nothing to collect");
        pot.claim("alice", alice, address(0), 6 ether, pa);
        assertEq(alice.balance, 6 ether);
    }

    function test_claim_aLaterRootPaysOnlyTheNewAccrual() public {
        fundEth(10 ether);
        Row memory a = Row("alice", alice, address(0), 6 ether);
        Row memory b = Row("bob", bob, address(0), 4 ether);
        (bytes32[] memory pa,) = _activate(a, b, 1, address(0), 10 ether);
        pot.claim("alice", alice, address(0), 6 ether, pa);

        // next lunation: 5 more ETH, alice's share re-split to 20%
        fundEth(5 ether);
        nextLunation();
        Row memory a2 = Row("alice", alice, address(0), 7 ether);
        Row memory b2 = Row("bob", bob, address(0), 8 ether);
        (bytes32[] memory pa2, bytes32[] memory pb2) = _activate(a2, b2, 2, address(0), 15 ether);

        pot.claim("alice", alice, address(0), 7 ether, pa2);
        assertEq(alice.balance, 7 ether);
        pot.claim("bob", bob, address(0), 8 ether, pb2);
        assertEq(bob.balance, 8 ether);
        assertEq(pot.holdings(address(0)), 0);
    }

    function test_claim_cannotExceedTheCommittedTotal() public {
        fundEth(10 ether);
        // the table over-promises: 6 + 6 against a declared 10
        Row memory a = Row("alice", alice, address(0), 6 ether);
        Row memory b = Row("bob", bob, address(0), 6 ether);
        (bytes32[] memory pa, bytes32[] memory pb) = _activate(a, b, 1, address(0), 10 ether);
        pot.claim("alice", alice, address(0), 6 ether, pa);
        vm.expectRevert("Beyond the committed total");
        pot.claim("bob", bob, address(0), 6 ether, pb);
    }

    function test_claim_erc20() public {
        token.transfer(address(pot), 100 ether);
        pot.sweep(address(token));
        Row memory a = Row("alice", alice, address(token), 60 ether);
        Row memory b = Row("bob", bob, address(token), 40 ether);
        (bytes32[] memory pa, bytes32[] memory pb) = _activate(a, b, 1, address(token), 100 ether);
        pot.claim("alice", alice, address(token), 60 ether, pa);
        pot.claim("bob", bob, address(token), 40 ether, pb);
        assertEq(token.balanceOf(alice), 60 ether);
        assertEq(token.balanceOf(bob), 40 ether);
        assertEq(pot.holdings(address(token)), 0);
    }

    function test_claim_reentryIsRefused() public {
        fundEth(10 ether);
        Reenterer evil = new Reenterer(pot);
        Row memory a = Row("alice", address(evil), address(0), 6 ether);
        Row memory b = Row("bob", bob, address(0), 4 ether);
        (bytes32[] memory pa,) = _activate(a, b, 1, address(0), 10 ether);
        evil.arm("alice", 6 ether, pa);
        vm.expectRevert("Paying ETH failed");
        pot.claim("alice", address(evil), address(0), 6 ether, pa);
        assertEq(address(evil).balance, 0);
        assertEq(pot.released(keccak256("alice"), address(0)), 0);
    }

    //=============================================================
    //                           Signers
    //=============================================================

    function test_signers_changeAppliesAfterTheWindow() public {
        fundEth(10 ether);
        address[] memory next = new address[](1);
        next[0] = s3;
        vm.prank(owner);
        pot.setSigners(next, 1);

        // the old quorum still commits inside the window
        post(1, keccak256("a"), address(0), 10 ether);

        vm.warp(block.timestamp + CHALLENGE);
        nextLunation();
        pot.settle();
        assertEq(pot.threshold(), 1);
        assertTrue(pot.isSigner(s3));
        assertFalse(pot.isSigner(s1));

        (address[] memory tokens, uint256[] memory totals) = one(address(0), 10 ether);
        bytes32 digest = pot.rootDigest(2, keccak256("b"), bytes32(0), tokens, totals);
        vm.expectRevert("Not a signer");
        pot.postRoot(2, keccak256("b"), bytes32(0), tokens, totals, quorum(digest));

        bytes[] memory sigs = new bytes[](1);
        sigs[0] = sign(k3, digest);
        pot.postRoot(2, keccak256("b"), bytes32(0), tokens, totals, sigs);
    }

    function test_signers_strangerCannotChangeThem() public {
        address[] memory next = new address[](1);
        next[0] = stranger;
        vm.prank(stranger);
        vm.expectRevert();
        pot.setSigners(next, 1);
    }

    //=============================================================
    //              Cross-check with @holons/core rights-tree
    //=============================================================

    /// The table `advanceRights` cuts for shares alice 50 / bob 30 / carol 20
    /// over 1000 EVO (at 0xee..ee) and 7 wei of ETH, as core's `rightsRoot`
    /// and `rightsProof` encode it (packages/core/src/flows/rights-tree.ts).
    function test_vector_coreTableVerifiesOnChain() public {
        address evo = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        vm.etch(evo, address(token).code);
        deal(evo, address(pot), 1000);
        pot.sweep(evo);
        fundEth(7);

        bytes32 root = 0xbb6fe7f4dcfb874d36b952e88ac50a66a2e8253c955c923d4c090fc9d72153ed;
        address[] memory tokens = new address[](2);
        tokens[0] = address(0);
        tokens[1] = evo;
        uint256[] memory totals = new uint256[](2);
        totals[0] = 7;
        totals[1] = 1000;
        bytes32 digest = pot.rootDigest(84, root, bytes32(0), tokens, totals);
        pot.postRoot(84, root, bytes32(0), tokens, totals, quorum(digest));
        vm.warp(block.timestamp + CHALLENGE);

        bytes32[] memory aliceEvo = new bytes32[](2);
        aliceEvo[0] = 0xf7ead572a2c76424bc42208d09c879e5da9f74616f97d2605af45e2cdbe2baaf;
        aliceEvo[1] = 0x9ed381e4509db13b70c2a3263805a10aa9591b41c8f7a6904b5f902d44d51cb3;
        pot.claim("alice", address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa), evo, 500, aliceEvo);
        assertEq(TestToken(evo).balanceOf(address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa)), 500);

        bytes32[] memory bobEth = new bytes32[](3);
        bobEth[0] = 0x925f71935d16f39e6edcad50ef7dc42c11103235af204e6f0f8e2b2fc81e496c;
        bobEth[1] = 0x47f873f7a02b6b4ad0b8abf203c2323656cfdc0119612808392a6878c86fe219;
        bobEth[2] = 0x7721571fde35e4e192c47fba499d04afd7fe59d6f3d4f3428085333b225a4dd1;
        pot.claim("bob", address(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB), address(0), 2, bobEth);
        assertEq(address(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB).balance, 2);

        // the same proof does not carry a different amount
        vm.expectRevert("Not in the table");
        pot.claim("bob", address(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB), address(0), 3, bobEth);
    }
}
