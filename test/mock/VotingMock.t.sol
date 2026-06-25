// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/Voting.sol";
import "../../src/VoterNFT.sol";

/// @title Mock Tests for Voting Contract
/// @notice Tests edge cases, adversarial scenarios and system limits

contract VotingMockTest is Test {
    Voting voting;
    VoterNFT nft;

    address admin = address(this);
    address attacker = address(0xDEAD);
    address voter1 = address(0x1);
    address voter2 = address(0x2);
    address voter3 = address(0x3);

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
    //  ADVERSARIAL — Attacker Scenarios
    // ─────────────────────────────────────────────

    function test_Mock_Attacker_CannotCreateElection() public {
        vm.prank(attacker);
        vm.expectRevert("Only admin can perform this action");
        voting.createElection(
            "Fake Election",
            "Attacker created",
            startTime,
            endTime
        );
    }

    function test_Mock_Attacker_CannotAddCandidate() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        vm.prank(attacker);
        vm.expectRevert("Only admin can perform this action");
        voting.addCandidate(1, "Fake Candidate", "President");
    }

    function test_Mock_Attacker_CannotRegisterVoters() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        vm.prank(attacker);
        vm.expectRevert("Only admin can perform this action");
        voting.registerVoter(1, attacker, "BU22CSC0000");
    }

    function test_Mock_Attacker_CannotVoteWithoutRegistration() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");

        vm.warp(startTime + 1);
        vm.prank(attacker);
        vm.expectRevert("You are not registered to vote in this election");
        voting.castVote(1, 1);
    }

    function test_Mock_Attacker_CannotVoteWithSameMatricDifferentWallet()
        public
    {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");

        // legitimate voter registers
        voting.registerVoter(1, voter1, "BU22CSC1126");

        // attacker tries to register with same matric number
        vm.expectRevert("Matric number already registered to another wallet");
        voting.registerVoter(1, attacker, "BU22CSC1126");

        // attacker tries to vote directly
        vm.warp(startTime + 1);
        vm.prank(attacker);
        vm.expectRevert("You are not registered to vote in this election");
        voting.castVote(1, 1);
    }

    function test_Mock_Attacker_CannotDoubleVote() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.addCandidate(1, "Jane Smith", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        vm.warp(startTime + 1);

        // first vote succeeds
        vm.prank(voter1);
        voting.castVote(1, 1);

        // second vote attempt fails
        vm.prank(voter1);
        vm.expectRevert("You have already voted");
        voting.castVote(1, 2);

        // vote count unchanged
        Voting.Candidate memory john = voting.getCandidate(1, 1);
        assertEq(john.voteCount, 1);
    }

    function test_Mock_Attacker_CannotVoteOnNonExistentElection() public {
        vm.prank(attacker);
        vm.expectRevert("Election does not exist");
        voting.castVote(99, 1);
    }

    function test_Mock_Attacker_CannotAddCandidateToNonExistentElection()
        public
    {
        vm.expectRevert("Election does not exist");
        voting.addCandidate(99, "Ghost Candidate", "President");
    }

    // ─────────────────────────────────────────────
    //  EDGE CASES — Boundary Conditions
    // ─────────────────────────────────────────────

    function test_Mock_EdgeCase_VoteAtExactStartTime() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        // warp to exact start time
        vm.warp(startTime);
        vm.prank(voter1);
        voting.castVote(1, 1);

        (, bool hasVoted, , ) = voting.getVoterStatus(1, voter1);
        assertTrue(hasVoted);
    }

    function test_Mock_EdgeCase_VoteAtExactEndTime() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        // warp to exact end time
        vm.warp(endTime);
        vm.prank(voter1);
        voting.castVote(1, 1);

        (, bool hasVoted, , ) = voting.getVoterStatus(1, voter1);
        assertTrue(hasVoted);
    }

    function test_Mock_EdgeCase_CannotVoteOneSecondAfterEnd() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        vm.warp(endTime + 1);
        vm.prank(voter1);
        vm.expectRevert("Election has ended");
        voting.castVote(1, 1);
    }

    function test_Mock_EdgeCase_EmptyMatricNumberIsUnique() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);

        // edge case — what if someone passes empty string
        voting.registerVoter(1, voter1, "");

        // second wallet cannot use empty string either
        vm.expectRevert("Matric number already registered to another wallet");
        voting.registerVoter(1, voter2, "");
    }

    function test_Mock_EdgeCase_CaseSensitiveMatricNumbers() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);

        // uppercase and lowercase are treated as different matric numbers
        voting.registerVoter(1, voter1, "bu22csc1126");
        voting.registerVoter(1, voter2, "BU22CSC1126");

        assertTrue(voting.isMatricRegistered(1, "bu22csc1126"));
        assertTrue(voting.isMatricRegistered(1, "BU22CSC1126"));
    }

    function test_Mock_EdgeCase_WinnerWithSingleVote() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.addCandidate(1, "Jane Smith", "President");
        voting.registerVoter(1, voter1, "BU22CSC1126");

        vm.warp(startTime + 1);
        vm.prank(voter1);
        voting.castVote(1, 2);

        vm.warp(endTime + 1);
        Voting.Candidate memory winner = voting.getWinner(1);
        assertEq(winner.name, "Jane Smith");
        assertEq(winner.voteCount, 1);
    }

    function test_Mock_EdgeCase_CannotGetWinnerWithNoVotes() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");

        vm.warp(endTime + 1);
        vm.expectRevert("No votes have been cast");
        voting.getWinner(1);
    }

    // ─────────────────────────────────────────────
    //  STRESS — Large Scale Simulation
    // ─────────────────────────────────────────────

    function test_Mock_Stress_TenVotersOneElection() public {
        voting.createElection("SUG Election 2025", "Test", startTime, endTime);
        voting.addCandidate(1, "John Doe", "President");
        voting.addCandidate(1, "Jane Smith", "President");

        // register 10 voters
        for (uint256 i = 1; i <= 10; i++) {
            address voterAddr = address(uint160(i));
            string memory matric = string(
                abi.encodePacked("BU22CSC", vm.toString(i))
            );
            voting.registerVoter(1, voterAddr, matric);
        }

        assertEq(voting.getElection(1).voterCount, 10);

        vm.warp(startTime + 1);

        // first 6 vote for candidate 1, last 4 vote for candidate 2
        for (uint256 i = 1; i <= 10; i++) {
            address voterAddr = address(uint160(i));
            vm.prank(voterAddr);
            if (i <= 6) {
                voting.castVote(1, 1);
            } else {
                voting.castVote(1, 2);
            }
        }

        vm.warp(endTime + 1);

        Voting.Candidate memory winner = voting.getWinner(1);
        assertEq(winner.name, "John Doe");
        assertEq(winner.voteCount, 6);
    }

    function test_Mock_Stress_FiftyElectionsCreated() public {
        for (uint256 i = 1; i <= 50; i++) {
            voting.createElection(
                string(abi.encodePacked("Election ", vm.toString(i))),
                "Test election",
                startTime,
                endTime
            );
        }
        assertEq(voting.getElectionCount(), 50);
    }
}
