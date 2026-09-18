// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../src/Bundle.sol";
import "../../src/TestToken.sol";

/// A recipient that refuses every push.
contract Refuser {
    receive() external payable {
        revert("no");
    }
}

/// A recipient that takes ETH but has no reward() to cascade through.
contract Sink {
    receive() external payable {}
}

/// Bundle behind the guarded claim: who may bind, how a share cascades
/// through a member's own Bundle, and what happens when a recipient
/// refuses, loops back, or tries to become the owner.
contract BundleCascadeTest is Test {
    uint256 constant STEEPNESS = 5e17; // 0.5
    uint256 constant NZONES = 2;

    address owner = makeAddr("owner");
    address childOwner = makeAddr("childOwner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address stranger = makeAddr("stranger");
    address funder = makeAddr("funder");

    Bundle parent;
    Bundle child; // bob's personal holon
    TestToken token;

    // mirrored from Bundle for expectEmit (solc 0.8.20 has no `emit C.E`)
    event DistributionCompleted(
        address indexed contractAddress,
        string holonId,
        address tokenAddress,
        uint256 totalAmount,
        uint256 recipientCount,
        uint256 cascadeCount
    );
    event PushFailed(
        address indexed contractAddress, string userId, address indexed recipient, address tokenAddress, uint256 amount
    );

    function setUp() public {
        vm.prank(owner);
        parent = new Bundle(owner, "creator", "Collective", STEEPNESS, NZONES);
        vm.prank(childOwner);
        child = new Bundle(childOwner, "bob", "Bob", STEEPNESS, NZONES);

        // collective: everything interior, alice and bob half each
        string[] memory ids = new string[](2);
        ids[0] = "alice";
        ids[1] = "bob";
        uint256[] memory shares = new uint256[](2);
        shares[0] = 5000;
        shares[1] = 5000;
        vm.startPrank(owner);
        parent.setContractSplit(10000, 0);
        parent.setInteriorSplit(ids, shares);
        vm.stopPrank();

        // bob keeps 60% and passes 40% on to carol
        string[] memory keep = new string[](1);
        keep[0] = "bob";
        uint256[] memory all = new uint256[](1);
        all[0] = 10000;
        string[] memory carol = new string[](1);
        carol[0] = "carol";
        uint256[] memory ring = new uint256[](1);
        ring[0] = 1;
        vm.prank(childOwner);
        child.syncAll(6000, 4000, STEEPNESS, NZONES, keep, all, carol, ring);

        token = new TestToken(1_000_000 ether);
        vm.deal(funder, 100 ether);
    }

    //=============================================================
    //                      Who may claim
    //=============================================================

    function test_claim_strangerCannotBindAMember() public {
        vm.prank(stranger);
        vm.expectRevert("Not authorized");
        parent.claim("alice", stranger);
        assertEq(parent.userIdToAddress("alice"), address(0));
    }

    function test_claim_ownerBindsAndSweeps() public {
        vm.prank(funder);
        (bool ok,) = address(parent).call{value: 2 ether}("");
        assertTrue(ok);
        assertEq(parent.etherBalance("alice"), 1 ether);
        assertEq(parent.totalEtherDeposited(), 2 ether);

        vm.prank(owner);
        parent.claim("alice", alice);

        assertEq(alice.balance, 1 ether);
        assertEq(parent.etherBalance("alice"), 0);
        assertEq(parent.totalEtherDeposited(), 1 ether);
        assertTrue(parent.hasClaimed("alice"));
        assertEq(parent.userIdToAddress("alice"), alice);
    }

    function test_claim_boundWalletRebindsItself() public {
        vm.prank(owner);
        parent.claim("alice", alice);

        address aliceNew = makeAddr("aliceNew");
        vm.prank(alice);
        parent.claim("alice", aliceNew);
        assertEq(parent.userIdToAddress("alice"), aliceNew);

        // the old wallet lost its standing
        vm.prank(alice);
        vm.expectRevert("Not authorized");
        parent.claim("alice", alice);

        // the new wallet is pushed to from now on
        vm.prank(funder);
        parent.reward{value: 2 ether}(address(0), 0);
        assertEq(aliceNew.balance, 1 ether);
    }

    function test_claim_ownerCanRebindAway() public {
        vm.prank(owner);
        parent.claim("alice", alice);
        vm.prank(owner);
        parent.claim("alice", bob);
        assertEq(parent.userIdToAddress("alice"), bob);
    }

    function test_claim_refusesNonMember() public {
        vm.prank(owner);
        vm.expectRevert("Not a member");
        parent.claim("nobody", alice);
    }

    function test_claim_rejectsABeneficiaryThatCannotTakeIt() public {
        vm.prank(funder);
        parent.reward{value: 2 ether}(address(0), 0);
        Refuser r = new Refuser();
        vm.prank(owner);
        vm.expectRevert("Claiming Ether failed");
        parent.claim("alice", address(r));
    }

    //=============================================================
    //                      Cascade
    //=============================================================

    function test_cascade_ethFlowsThroughBobsBundle() public {
        vm.prank(owner);
        parent.claim("bob", address(child));

        vm.prank(funder);
        vm.expectEmit(true, false, false, true);
        emit DistributionCompleted(address(parent), "Collective", address(0), 10 ether, 2, 1);
        parent.reward{value: 10 ether}(address(0), 0);

        // alice stored at the collective; bob's 5 went into his own Bundle
        assertEq(parent.etherBalance("alice"), 5 ether);
        assertEq(address(child).balance, 5 ether);
        assertEq(child.etherBalance("bob"), 3 ether);
        assertEq(child.etherBalance("carol"), 2 ether);
    }

    function test_cascade_erc20FlowsThroughBobsBundle() public {
        vm.prank(owner);
        parent.claim("bob", address(child));

        token.transfer(address(parent), 10 ether);
        vm.expectEmit(true, false, false, true);
        emit DistributionCompleted(address(parent), "Collective", address(token), 10 ether, 2, 1);
        parent.reward(address(token), 10 ether);

        assertEq(parent.tokenBalance("alice", address(token)), 5 ether);
        assertEq(token.balanceOf(address(child)), 5 ether);
        assertEq(child.tokenBalance("bob", address(token)), 3 ether);
        assertEq(child.tokenBalance("carol", address(token)), 2 ether);
        assertEq(child.totalDeposited(address(token)), 5 ether);
    }

    function test_claim_storedErc20CascadesIntoAContractBeneficiary() public {
        token.transfer(address(parent), 10 ether);
        parent.reward(address(token), 10 ether);
        assertEq(parent.tokenBalance("bob", address(token)), 5 ether);

        // binding bob to his Bundle later still divides what was waiting
        vm.prank(owner);
        parent.claim("bob", address(child));
        assertEq(parent.tokenBalance("bob", address(token)), 0);
        assertEq(child.tokenBalance("bob", address(token)), 3 ether);
        assertEq(child.tokenBalance("carol", address(token)), 2 ether);
    }

    function test_claim_toAContractThatCannotCascadeIsRejected() public {
        token.transfer(address(parent), 10 ether);
        parent.reward(address(token), 10 ether);
        Sink s = new Sink();
        vm.prank(owner);
        vm.expectRevert("Beneficiary refused the cascade");
        parent.claim("bob", address(s));
    }

    function test_cascade_loopDoesNotBrickEitherSide() public {
        // bob's Bundle gives 40% to "carol"; make carol the collective itself
        vm.prank(childOwner);
        child.addMember("carol");
        vm.prank(childOwner);
        child.claim("carol", address(parent));
        vm.prank(owner);
        parent.claim("bob", address(child));

        vm.prank(funder);
        parent.reward{value: 10 ether}(address(0), 0);

        // parent -> child (5) -> carol=parent (2) is re-entrant and refused,
        // so the child holds it for the collective instead of reverting
        assertEq(parent.etherBalance("alice"), 5 ether);
        assertEq(child.etherBalance("bob"), 3 ether);
        assertEq(child.etherBalance("carol"), 2 ether);
        assertEq(child.userIdToAddress("carol"), address(parent));
    }

    function test_deliver_refusedEthIsStoredNotReverted() public {
        Refuser r = new Refuser();
        // bind while nothing is owed, so the bind itself has nothing to pay
        vm.prank(owner);
        parent.claim("alice", address(r));

        vm.prank(funder);
        vm.expectEmit(true, true, false, true);
        emit PushFailed(address(parent), "alice", address(r), address(0), 1 ether);
        parent.reward{value: 2 ether}(address(0), 0);

        assertEq(parent.etherBalance("alice"), 1 ether);
        assertEq(parent.totalEtherDeposited(), 2 ether);

        // the owner frees the share by re-binding to a wallet that works
        vm.prank(owner);
        parent.claim("alice", alice);
        assertEq(alice.balance, 1 ether);
    }

    function test_deliver_erc20CascadeFailureLeavesTokensRetryable() public {
        Sink s = new Sink();
        vm.prank(owner);
        parent.claim("alice", address(s));

        token.transfer(address(parent), 10 ether);
        vm.expectEmit(true, false, false, true);
        emit DistributionCompleted(address(parent), "Collective", address(token), 10 ether, 2, 0);
        parent.reward(address(token), 10 ether);
        assertEq(token.balanceOf(address(s)), 5 ether);
    }

    //=============================================================
    //                      Stored ETH is not distributable
    //=============================================================

    function test_reward_cannotSpendStoredEther() public {
        vm.prank(funder);
        parent.reward{value: 2 ether}(address(0), 0);

        vm.prank(stranger);
        vm.expectRevert("Not enough ether in the contract");
        parent.reward(address(0), 1 ether);
    }

    function test_reward_strayEtherIsDistributable() public {
        vm.prank(funder);
        parent.reward{value: 2 ether}(address(0), 0);
        // ETH that arrived without going through the split (selfdestruct etc.)
        vm.deal(address(parent), 3 ether);

        parent.reward(address(0), 1 ether);
        assertEq(parent.etherBalance("alice"), 1.5 ether);
        assertEq(parent.totalEtherDeposited(), 3 ether);
    }

    //=============================================================
    //                      Elections and ownership
    //=============================================================

    function test_election_strangerCannotNominateOrVote() public {
        vm.prank(owner);
        parent.startElection();
        vm.prank(stranger);
        vm.expectRevert("Not authorized");
        parent.nominateSelf("alice");
        vm.prank(stranger);
        vm.expectRevert("Not authorized");
        parent.vote("alice", "alice");
    }

    function test_election_contractBoundMemberCannotRun() public {
        vm.prank(owner);
        parent.claim("bob", address(child));
        vm.prank(owner);
        parent.startElection();
        vm.prank(owner);
        vm.expectRevert("A contract cannot own the Bundle");
        parent.nominateSelf("bob");
    }

    function test_election_winnerReboundToContractNeverOwns() public {
        vm.prank(owner);
        parent.claim("bob", bob);
        vm.prank(owner);
        parent.startElection();
        vm.prank(bob);
        parent.nominateSelf("bob");
        vm.prank(bob);
        parent.vote("bob", "bob");

        // bob moves his share into his Bundle before the count
        vm.prank(bob);
        parent.claim("bob", address(child));
        vm.prank(owner);
        parent.finalizeElection();
        assertEq(parent.owner(), owner);
    }

    function test_election_boundWalletWins() public {
        vm.prank(owner);
        parent.claim("alice", alice);
        vm.prank(owner);
        parent.startElection();
        vm.prank(alice);
        parent.nominateSelf("alice");
        vm.prank(alice);
        parent.vote("alice", "alice");
        vm.prank(owner);
        parent.finalizeElection();
        assertEq(parent.owner(), alice);
    }

    function test_addMember_onlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert("Only owner");
        parent.addMember("mallory");
    }

    function test_transferOwnership() public {
        vm.prank(stranger);
        vm.expectRevert("Only owner");
        parent.transferOwnership(stranger);

        vm.prank(owner);
        parent.transferOwnership(alice);
        assertEq(parent.owner(), alice);
    }
}
