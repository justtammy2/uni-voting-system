// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/Voting.sol";

/// @title Unit Tests for Voting Contract
/// @notice Tests each function in isolation

contract VotingUnitTest is Test {
    Voting voting;

    address admin = address(this);
    address voter1 = address(0x1);
    address voter2 = address(0x2);

    uint256 startTime;
    uint256 endTime;

    function setUp() public {
        voting = new Voting();
        startTime = block.timestamp + 1 hours;
        endTime = block.timestamp + 2 hours;
    }

    // ─────────────────────────────────────────────
    //  DEPLOYMENT
    // ─────────────────────────────────────────────

    function test_Unit_AdminIsSetOnDeployment() public view {
        assertEq(voting.admin(), admin);
    }

    function test_Unit_ElectionCountIsZeroOnDeployment() public view {
        assertEq(voting.getElectionCount(), 0);
    }

    // ─────────────────────────────────────────────
    //  createElection()
    // ─────────────────────────────────────────────

    function test_Unit_CreateElection_Success() public {
        voting.createElection(
            "SUG Election 2025",
            "Annual SUG election",
            startTime,
            endTime
        );
        assertEq(voting.getElectionCount(), 1);
    }

    function test_Unit_CreateElection_StoresCorrectData() public {
        voting.createElection(
            "SUG Election 2025",
            "Annual SUG election",
            startTime,
            endTime
        );
        Voting.Election memory e = voting.getElection(1);
        assertEq(e.title, "SUG Election 2025");
        assertEq(e.description, "Annual SUG election");
        assertEq(e.startTime, startTime);
        assertEq(e.endTime, endTime);
        assertTrue(e.exists);
        assertEq(e.candidateCount, 0);
        assertEq(e.voterCount, 0);
    }

    function test_Unit_CreateElection_RevertIf_NotAdmin() public {
        vm.prank(voter1);
        vm.expectRevert("Only admin can perform this action");
        voting.createElection("Fake Election", "Test", startTime, endTime);
    }

    function test_Unit_CreateElection_RevertIf_EndTimeInPast() public {
        vm.expectRevert("End time must be in the future");
        voting.createElection(
            "Bad Election",
            "Test",
            block.timestamp - 2,
            block.timestamp - 1
        );
    }

    function test_Unit_CreateElection_RevertIf_StartAfterEnd() public {
        vm.expectRevert("Start time must be before end time");
        voting.createElection("Bad Election", "Test", endTime, startTime);
    }

    function test_Unit_CreateElection_MultipleElections() public {
        voting.createElection("Election 1", "Test", startTime, endTime);
        voting.createElection("Election 2", "Test", startTime, endTime);
        voting.createElection("Election 3", "Test", startTime, endTime);
        assertEq(voting.getElectionCount(), 3);
    }

    // ─────────────────────────────────────────────
    //  addCandidate()
    // ─────────────────────────────────────────────

    function test_Unit_AddCandidate_Success() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");

        Voting.Candidate[] memory c = voting.getCandidates(1);
        assertEq(c.length, 1);
        assertEq(c[0].name, "John Doe");
        assertEq(c[0].position, "President");
        assertEq(c[0].voteCount, 0);
    }

    function test_Unit_AddCandidate_RevertIf_NotAdmin() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        vm.prank(voter1);
        vm.expectRevert("Only admin can perform this action");
        voting.addCandidate(1, "John Doe", "President");
    }

    function test_Unit_AddCandidate_RevertIf_ElectionDoesNotExist() public {
        vm.expectRevert("Election does not exist");
        voting.addCandidate(99, "John Doe", "President");
    }

    function test_Unit_AddCandidate_RevertIf_ElectionAlreadyStarted() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        vm.warp(startTime + 1);
        vm.expectRevert("Cannot add candidates after election starts");
        voting.addCandidate(1, "John Doe", "President");
    }

    function test_Unit_AddCandidate_MultipleCandidates() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.addCandidate(1, "Jane Smith", "President");
        voting.addCandidate(1, "Mike Johnson", "President");

        Voting.Candidate[] memory c = voting.getCandidates(1);
        assertEq(c.length, 3);
    }

    // ─────────────────────────────────────────────
    //  registerVoter()
    // ─────────────────────────────────────────────

    function test_Unit_RegisterVoter_Success() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.registerVoter(1, voter1, "BU22CSC1126");

        (bool isRegistered, bool hasVoted, , ) = voting.getVoterStatus(
            1,
            voter1
        );
        assertTrue(isRegistered);
        assertFalse(hasVoted);
    }

    function test_Unit_RegisterVoter_IncreasesVoterCount() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.registerVoter(1, voter1, "BU22CSC1126");
        voting.registerVoter(1, voter2, "BU22CSC1127");

        Voting.Election memory e = voting.getElection(1);
        assertEq(e.voterCount, 2);
    }

    function test_Unit_RegisterVoter_MatricHashStoredCorrectly() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.registerVoter(1, voter1, "BU22CSC1126");

        bytes32 expectedHash = keccak256(abi.encodePacked("BU22CSC1126"));
        (, , , bytes32 storedHash) = voting.getVoterStatus(1, voter1);
        assertEq(storedHash, expectedHash);
    }

    function test_Unit_RegisterVoter_RevertIf_WalletAlreadyRegistered() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.registerVoter(1, voter1, "BU22CSC1126");

        vm.expectRevert("Wallet already registered");
        voting.registerVoter(1, voter1, "BU22CSC1127");
    }

    function test_Unit_RegisterVoter_RevertIf_MatricAlreadyUsed() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.registerVoter(1, voter1, "BU22CSC1126");

        vm.expectRevert("Matric number already registered to another wallet");
        voting.registerVoter(1, voter2, "BU22CSC1126");
    }

    function test_Unit_RegisterVoter_RevertIf_NotAdmin() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        vm.prank(voter1);
        vm.expectRevert("Only admin can perform this action");
        voting.registerVoter(1, voter2, "BU22CSC1127");
    }

    function test_Unit_RegisterVoter_RevertIf_ElectionDoesNotExist() public {
        vm.expectRevert("Election does not exist");
        voting.registerVoter(99, voter1, "BU22CSC1126");
    }

    // ─────────────────────────────────────────────
    //  isMatricRegistered()
    // ─────────────────────────────────────────────

    function test_Unit_IsMatricRegistered_ReturnsTrueIfRegistered() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.registerVoter(1, voter1, "BU22CSC1126");
        assertTrue(voting.isMatricRegistered(1, "BU22CSC1126"));
    }

    function test_Unit_IsMatricRegistered_ReturnsFalseIfNotRegistered() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        assertFalse(voting.isMatricRegistered(1, "BU22CSC9999"));
    }

    // ─────────────────────────────────────────────
    //  castVote()
    // ─────────────────────────────────────────────

    function test_Unit_CastVote_Success() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        vm.warp(startTime + 1);
        vm.prank(voter1);
        voting.castVote(1, 1);

        (, bool hasVoted, uint256 votedFor, ) = voting.getVoterStatus(
            1,
            voter1
        );
        assertTrue(hasVoted);
        assertEq(votedFor, 1);
    }

    function test_Unit_CastVote_IncreasesCandidateVoteCount() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        vm.warp(startTime + 1);
        vm.prank(voter1);
        voting.castVote(1, 1);

        Voting.Candidate memory c = voting.getCandidate(1, 1);
        assertEq(c.voteCount, 1);
    }

    function test_Unit_CastVote_RevertIf_NotRegistered() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");

        vm.warp(startTime + 1);
        vm.prank(voter1);
        vm.expectRevert("You are not registered to vote in this election");
        voting.castVote(1, 1);
    }

    function test_Unit_CastVote_RevertIf_AlreadyVoted() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        vm.warp(startTime + 1);
        vm.prank(voter1);
        voting.castVote(1, 1);

        vm.prank(voter1);
        vm.expectRevert("You have already voted");
        voting.castVote(1, 1);
    }

    function test_Unit_CastVote_RevertIf_BeforeStart() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        vm.prank(voter1);
        vm.expectRevert("Election has not started yet");
        voting.castVote(1, 1);
    }

    function test_Unit_CastVote_RevertIf_AfterEnd() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        vm.warp(endTime + 1);
        vm.prank(voter1);
        vm.expectRevert("Election has ended");
        voting.castVote(1, 1);
    }

    function test_Unit_CastVote_RevertIf_InvalidCandidate() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        vm.warp(startTime + 1);
        vm.prank(voter1);
        vm.expectRevert("Invalid candidate");
        voting.castVote(1, 99);
    }

    // ─────────────────────────────────────────────
    //  getWinner()
    // ─────────────────────────────────────────────

    function test_Unit_GetWinner_RevertIf_ElectionStillOngoing() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");

        vm.warp(startTime + 1);
        vm.expectRevert("Election is still ongoing");
        voting.getWinner(1);
    }

    function test_Unit_IsElectionActive_ReturnsFalseBeforeStart() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        assertFalse(voting.isElectionActive(1));
    }

    function test_Unit_IsElectionActive_ReturnsTrueDuringElection() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        vm.warp(startTime + 1);
        assertTrue(voting.isElectionActive(1));
    }

    function test_Unit_IsElectionActive_ReturnsFalseAfterEnd() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        vm.warp(endTime + 1);
        assertFalse(voting.isElectionActive(1));
    }
}
