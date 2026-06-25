// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title University Election Voting System
/// @author Aremu Oluwatamilore
/// @notice A decentralized voting system for university elections with on-chain student identity verification

interface IVoterNFT {
    function mintVoterCertificate(
        address _voter,
        uint256 _electionId,
        string memory _electionTitle
    ) external;
}

contract Voting {
    // ─────────────────────────────────────────────
    //  STRUCTS
    // ─────────────────────────────────────────────

    struct Candidate {
        uint256 id;
        string name;
        string position;
        uint256 voteCount;
    }

    struct Election {
        uint256 id;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        bool exists;
        uint256 candidateCount;
        uint256 voterCount;
    }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedCandidateId;
        bytes32 matricHash; // hashed matric number bound to this voter
    }

    // ─────────────────────────────────────────────
    //  STATE VARIABLES
    // ─────────────────────────────────────────────

    address public admin;
    uint256 public electionCount;
    IVoterNFT public voterNFT;

    // electionId => Election
    mapping(uint256 => Election) public elections;

    // electionId => candidateId => Candidate
    mapping(uint256 => mapping(uint256 => Candidate)) public candidates;

    // electionId => voterAddress => Voter
    mapping(uint256 => mapping(address => Voter)) public voters;

    // electionId => matricHash => already registered?
    // prevents same matric number being used across different wallets
    mapping(uint256 => mapping(bytes32 => bool)) public matricRegistered;

    // ─────────────────────────────────────────────
    //  EVENTS
    // ─────────────────────────────────────────────

    event ElectionCreated(
        uint256 indexed electionId,
        string title,
        uint256 startTime,
        uint256 endTime
    );
    event CandidateAdded(
        uint256 indexed electionId,
        uint256 indexed candidateId,
        string name,
        string position
    );
    event VoterRegistered(
        uint256 indexed electionId,
        address indexed voter,
        bytes32 matricHash
    );
    event VoteCast(
        uint256 indexed electionId,
        uint256 indexed candidateId,
        address indexed voter
    );

    // ─────────────────────────────────────────────
    //  MODIFIERS
    // ─────────────────────────────────────────────

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier electionExists(uint256 _electionId) {
        require(elections[_electionId].exists, "Election does not exist");
        _;
    }

    modifier electionActive(uint256 _electionId) {
        require(
            block.timestamp >= elections[_electionId].startTime,
            "Election has not started yet"
        );
        require(
            block.timestamp <= elections[_electionId].endTime,
            "Election has ended"
        );
        _;
    }

    modifier electionEnded(uint256 _electionId) {
        require(
            block.timestamp > elections[_electionId].endTime,
            "Election is still ongoing"
        );
        _;
    }

    // ─────────────────────────────────────────────
    //  CONSTRUCTOR
    // ─────────────────────────────────────────────

    constructor(address _voterNFT) {
        admin = msg.sender;
        voterNFT = IVoterNFT(_voterNFT);
    }

    function setNFTContract(address _voterNFT) external onlyAdmin {
        voterNFT = IVoterNFT(_voterNFT);
    }

    // ─────────────────────────────────────────────
    //  ADMIN FUNCTIONS
    // ─────────────────────────────────────────────

    function createElection(
        string memory _title,
        string memory _description,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyAdmin {
        require(_startTime < _endTime, "Start time must be before end time");
        require(_endTime > block.timestamp, "End time must be in the future");

        electionCount++;

        elections[electionCount] = Election({
            id: electionCount,
            title: _title,
            description: _description,
            startTime: _startTime,
            endTime: _endTime,
            exists: true,
            candidateCount: 0,
            voterCount: 0
        });

        emit ElectionCreated(electionCount, _title, _startTime, _endTime);
    }

    function addCandidate(
        uint256 _electionId,
        string memory _name,
        string memory _position
    ) external onlyAdmin electionExists(_electionId) {
        require(
            block.timestamp < elections[_electionId].startTime,
            "Cannot add candidates after election starts"
        );

        elections[_electionId].candidateCount++;
        uint256 candidateId = elections[_electionId].candidateCount;

        candidates[_electionId][candidateId] = Candidate({
            id: candidateId,
            name: _name,
            position: _position,
            voteCount: 0
        });

        emit CandidateAdded(_electionId, candidateId, _name, _position);
    }

    /// @notice Register a voter using their matric number
    /// @dev Matric number is hashed on-chain — raw matric number is never stored
    /// @param _electionId Election to register voter for
    /// @param _voter Wallet address of the student
    /// @param _matricNumber Raw matric number string (e.g. "BU22CSC1126")
    function registerVoter(
        uint256 _electionId,
        address _voter,
        string memory _matricNumber
    ) external onlyAdmin electionExists(_electionId) {
        require(
            block.timestamp < elections[_electionId].endTime,
            "Election has already ended"
        );
        require(
            !voters[_electionId][_voter].isRegistered,
            "Wallet already registered"
        );

        // hash the matric number on-chain
        bytes32 matricHash = keccak256(abi.encodePacked(_matricNumber));

        // check this matric number hasn't been used for another wallet
        require(
            !matricRegistered[_electionId][matricHash],
            "Matric number already registered to another wallet"
        );

        // bind matric hash to wallet
        voters[_electionId][_voter] = Voter({
            isRegistered: true,
            hasVoted: false,
            votedCandidateId: 0,
            matricHash: matricHash
        });

        // mark matric number as used for this election
        matricRegistered[_electionId][matricHash] = true;

        elections[_electionId].voterCount++;

        emit VoterRegistered(_electionId, _voter, matricHash);
    }

    // ─────────────────────────────────────────────
    //  VOTER FUNCTIONS
    // ─────────────────────────────────────────────

    function castVote(
        uint256 _electionId,
        uint256 _candidateId
    ) external electionExists(_electionId) electionActive(_electionId) {
        Voter storage voter = voters[_electionId][msg.sender];

        require(
            voter.isRegistered,
            "You are not registered to vote in this election"
        );
        require(!voter.hasVoted, "You have already voted");
        require(
            _candidateId > 0 &&
                _candidateId <= elections[_electionId].candidateCount,
            "Invalid candidate"
        );

        voter.hasVoted = true;
        voter.votedCandidateId = _candidateId;
        candidates[_electionId][_candidateId].voteCount++;

        emit VoteCast(_electionId, _candidateId, msg.sender);

        // mint voter certificate NFT
        voterNFT.mintVoterCertificate(
            msg.sender,
            _electionId,
            elections[_electionId].title
        );
    }

    // ─────────────────────────────────────────────
    //  VIEW FUNCTIONS
    // ─────────────────────────────────────────────

    function getElection(
        uint256 _electionId
    ) external view electionExists(_electionId) returns (Election memory) {
        return elections[_electionId];
    }

    function getCandidates(
        uint256 _electionId
    ) external view electionExists(_electionId) returns (Candidate[] memory) {
        uint256 count = elections[_electionId].candidateCount;
        Candidate[] memory result = new Candidate[](count);
        for (uint256 i = 1; i <= count; i++) {
            result[i - 1] = candidates[_electionId][i];
        }
        return result;
    }

    function getCandidate(
        uint256 _electionId,
        uint256 _candidateId
    ) external view electionExists(_electionId) returns (Candidate memory) {
        require(
            _candidateId > 0 &&
                _candidateId <= elections[_electionId].candidateCount,
            "Invalid candidate"
        );
        return candidates[_electionId][_candidateId];
    }

    function getVoterStatus(
        uint256 _electionId,
        address _voter
    )
        external
        view
        electionExists(_electionId)
        returns (
            bool isRegistered,
            bool hasVoted,
            uint256 votedCandidateId,
            bytes32 matricHash
        )
    {
        Voter memory voter = voters[_electionId][_voter];
        return (
            voter.isRegistered,
            voter.hasVoted,
            voter.votedCandidateId,
            voter.matricHash
        );
    }

    /// @notice Check if a matric number is already registered for an election
    function isMatricRegistered(
        uint256 _electionId,
        string memory _matricNumber
    ) external view electionExists(_electionId) returns (bool) {
        bytes32 matricHash = keccak256(abi.encodePacked(_matricNumber));
        return matricRegistered[_electionId][matricHash];
    }

    function getWinner(
        uint256 _electionId
    )
        external
        view
        electionExists(_electionId)
        electionEnded(_electionId)
        returns (Candidate memory winner)
    {
        uint256 highestVotes = 0;
        uint256 winnerId = 0;
        uint256 count = elections[_electionId].candidateCount;
        for (uint256 i = 1; i <= count; i++) {
            if (candidates[_electionId][i].voteCount > highestVotes) {
                highestVotes = candidates[_electionId][i].voteCount;
                winnerId = i;
            }
        }
        require(winnerId != 0, "No votes have been cast");
        return candidates[_electionId][winnerId];
    }

    function isElectionActive(
        uint256 _electionId
    ) external view electionExists(_electionId) returns (bool) {
        return (block.timestamp >= elections[_electionId].startTime &&
            block.timestamp <= elections[_electionId].endTime);
    }

    function getElectionCount() external view returns (uint256) {
        return electionCount;
    }
}
