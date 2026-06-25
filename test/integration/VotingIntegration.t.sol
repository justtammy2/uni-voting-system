// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/Voting.sol";
import "../../src/VoterNFT.sol";

/// @title Integration Tests for Voting Contract
/// @notice Tests complete election flows end to end

contract VotingIntegrationTest is Test {
    Voting voting;
    VoterNFT nft;

    address admin = address(this);
    address voter1 = address(0x1);
    address voter2 = address(0x2);
    address voter3 = address(0x3);
    address voter4 = address(0x4);
    address voter5 = address(0x5);

    uint256 startTime;
    uint256 endTime;

    function setUp() public {
        nft = new VoterNFT(address(1));
        voting = new Voting(address(nft));
        nft = new VoterNFT(address(voting));
        voting.setNFTContract(address(nft));
        startTime = block.timestamp + 1 hours;
        endTime = block.timestamp + 2 hours;
    }

    // ─────────────────────────────────────────────
    //  FLOW 1 — Complete Election Lifecycle
    // ─────────────────────────────────────────────

    function test_Integration_CompleteElectionLifecycle() public {
        // Step 1 — Admin creates election
        voting.createElection(
            "SUG Election 2025",
            "Annual student union election",
            startTime,
            endTime
        );
        assertEq(voting.getElectionCount(), 1);

        // Step 2 — Admin adds candidates
        voting.addCandidate(1, "John Doe", "President");
        voting.addCandidate(1, "Jane Smith", "President");
        voting.addCandidate(1, "Mike Johnson", "President");

        Voting.Candidate[] memory candidates = voting.getCandidates(1);
        assertEq(candidates.length, 3);

        // Step 3 — Admin registers voters with matric numbers
        voting.registerVoter(1, voter1, "BU22CSC1126");
        voting.registerVoter(1, voter2, "BU22CSC1127");
        voting.registerVoter(1, voter3, "BU22CSC1128");
        voting.registerVoter(1, voter4, "BU22CSC1129");
        voting.registerVoter(1, voter5, "BU22CSC1130");

        Voting.Election memory e = voting.getElection(1);
        assertEq(e.voterCount, 5);

        // Step 4 — Election starts
        vm.warp(startTime + 1);
        assertTrue(voting.isElectionActive(1));

        // Step 5 — All voters cast votes
        vm.prank(voter1);
        voting.castVote(1, 1); // votes for John
        vm.prank(voter2);
        voting.castVote(1, 1); // votes for John
        vm.prank(voter3);
        voting.castVote(1, 2); // votes for Jane
        vm.prank(voter4);
        voting.castVote(1, 3); // votes for Mike
        vm.prank(voter5);
        voting.castVote(1, 1); // votes for John

        // Step 6 — Verify vote counts
        Voting.Candidate memory john = voting.getCandidate(1, 1);
        Voting.Candidate memory jane = voting.getCandidate(1, 2);
        Voting.Candidate memory mike = voting.getCandidate(1, 3);
        assertEq(john.voteCount, 3);
        assertEq(jane.voteCount, 1);
        assertEq(mike.voteCount, 1);

        // Step 7 — Election ends
        vm.warp(endTime + 1);
        assertFalse(voting.isElectionActive(1));

        // Step 8 — Get winner
        Voting.Candidate memory winner = voting.getWinner(1);
        assertEq(winner.name, "John Doe");
        assertEq(winner.voteCount, 3);
    }

    // ─────────────────────────────────────────────
    //  FLOW 2 — Matric Number Identity Binding
    // ─────────────────────────────────────────────

    function test_Integration_MatricNumberBinding_PreventsDuplicateRegistration()
        public
    {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);

        // voter1 registers with their matric number
        voting.registerVoter(1, voter1, "BU22CSC1126");
        assertTrue(voting.isMatricRegistered(1, "BU22CSC1126"));

        // voter2 tries to use the same matric number with a different wallet
        vm.expectRevert("Matric number already registered to another wallet");
        voting.registerVoter(1, voter2, "BU22CSC1126");

        // voter1 tries to register again with a different matric number
        vm.expectRevert("Wallet already registered");
        voting.registerVoter(1, voter1, "BU22CSC9999");

        // voter2 can still register with their own matric number
        voting.registerVoter(1, voter2, "BU22CSC1127");
        assertTrue(voting.isMatricRegistered(1, "BU22CSC1127"));
    }

    function test_Integration_MatricNumber_IsUniquePerElection() public {
        // create two separate elections
        voting.createElection("Election 1", "Test", startTime, endTime);
        voting.createElection("Election 2", "Test", startTime, endTime);

        // same matric number can register in different elections
        voting.registerVoter(1, voter1, "BU22CSC1126");
        voting.registerVoter(2, voter1, "BU22CSC1126");

        assertTrue(voting.isMatricRegistered(1, "BU22CSC1126"));
        assertTrue(voting.isMatricRegistered(2, "BU22CSC1126"));
    }

    // ─────────────────────────────────────────────
    //  FLOW 3 — Multiple Elections Running
    // ─────────────────────────────────────────────

    function test_Integration_MultipleElectionsRunningSimultaneously() public {
        // create two elections
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.createElection(
            "Faculty Election 2025",
            "Test",
            startTime,
            endTime
        );

        // add candidates to both
        voting.addCandidate(1, "John Doe", "SUG President");
        voting.addCandidate(2, "Jane Smith", "Faculty Rep");

        // register voters for both elections
        voting.registerVoter(1, voter1, "BU22CSC1126");
        voting.registerVoter(2, voter1, "BU22CSC1126");

        // both elections start
        vm.warp(startTime + 1);

        // voter1 votes in both elections
        vm.prank(voter1);
        voting.castVote(1, 1);

        vm.prank(voter1);
        voting.castVote(2, 1);

        // verify votes in both elections
        Voting.Candidate memory winner1 = voting.getCandidate(1, 1);
        Voting.Candidate memory winner2 = voting.getCandidate(2, 1);
        assertEq(winner1.voteCount, 1);
        assertEq(winner2.voteCount, 1);
    }

    // ─────────────────────────────────────────────
    //  FLOW 4 — Voter Status Tracking
    // ─────────────────────────────────────────────

    function test_Integration_VoterStatusTrackedCorrectly() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        // before voting
        (bool isRegistered, bool hasVoted, uint256 votedFor, ) = voting
            .getVoterStatus(1, voter1);
        assertTrue(isRegistered);
        assertFalse(hasVoted);
        assertEq(votedFor, 0);

        // after voting
        vm.warp(startTime + 1);
        vm.prank(voter1);
        voting.castVote(1, 1);

        (isRegistered, hasVoted, votedFor, ) = voting.getVoterStatus(1, voter1);
        assertTrue(isRegistered);
        assertTrue(hasVoted);
        assertEq(votedFor, 1);
    }

    // ─────────────────────────────────────────────
    //  FLOW 5 — Election Timing Enforcement
    // ─────────────────────────────────────────────

    function test_Integration_ElectionTimingEnforcedCorrectly() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        // before start — election not active
        assertFalse(voting.isElectionActive(1));

        // cannot vote before start
        vm.prank(voter1);
        vm.expectRevert("Election has not started yet");
        voting.castVote(1, 1);

        // during election — active
        vm.warp(startTime + 1);
        assertTrue(voting.isElectionActive(1));

        // can vote during election
        vm.prank(voter1);
        voting.castVote(1, 1);

        // after end — not active
        vm.warp(endTime + 1);
        assertFalse(voting.isElectionActive(1));

        // cannot get winner before end was already tested
        // winner is now available
        Voting.Candidate memory winner = voting.getWinner(1);
        assertEq(winner.name, "John Doe");
    }

    // ─────────────────────────────────────────────
    //  FLOW 6 — Full Voter Turnout
    // ─────────────────────────────────────────────

    function test_Integration_AllRegisteredVotersVote() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.addCandidate(1, "Jane Smith", "President");

        voting.registerVoter(1, voter1, "BU22CSC1126");
        voting.registerVoter(1, voter2, "BU22CSC1127");
        voting.registerVoter(1, voter3, "BU22CSC1128");
        voting.registerVoter(1, voter4, "BU22CSC1129");
        voting.registerVoter(1, voter5, "BU22CSC1130");

        vm.warp(startTime + 1);

        vm.prank(voter1);
        voting.castVote(1, 2);
        vm.prank(voter2);
        voting.castVote(1, 2);
        vm.prank(voter3);
        voting.castVote(1, 2);
        vm.prank(voter4);
        voting.castVote(1, 1);
        vm.prank(voter5);
        voting.castVote(1, 1);

        vm.warp(endTime + 1);

        Voting.Candidate memory winner = voting.getWinner(1);
        assertEq(winner.name, "Jane Smith");
        assertEq(winner.voteCount, 3);

        // verify all voters are marked as voted
        (, bool v1Voted, , ) = voting.getVoterStatus(1, voter1);
        (, bool v2Voted, , ) = voting.getVoterStatus(1, voter2);
        (, bool v3Voted, , ) = voting.getVoterStatus(1, voter3);
        (, bool v4Voted, , ) = voting.getVoterStatus(1, voter4);
        (, bool v5Voted, , ) = voting.getVoterStatus(1, voter5);

        assertTrue(v1Voted);
        assertTrue(v2Voted);
        assertTrue(v3Voted);
        assertTrue(v4Voted);
        assertTrue(v5Voted);
    }
}
