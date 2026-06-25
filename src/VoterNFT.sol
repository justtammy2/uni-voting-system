// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Voter Participation NFT
/// @author Aremu Oluwatamilore
/// @notice A non-transferable NFT minted to a voter's wallet after successfully casting a vote
/// @dev Soulbound — transfer functions are disabled after minting

contract VoterNFT {
    // ─────────────────────────────────────────────
    //  STRUCTS
    // ─────────────────────────────────────────────

    struct TokenData {
        uint256 tokenId;
        uint256 electionId;
        string electionTitle;
        address voter;
        uint256 timestamp;
    }

    // ─────────────────────────────────────────────
    //  STATE VARIABLES
    // ─────────────────────────────────────────────

    string public name = "University Voter Certificate";
    string public symbol = "UVC";

    address public votingContract;
    uint256 private _tokenIdCounter;

    // tokenId => TokenData
    mapping(uint256 => TokenData) public tokenData;

    // tokenId => owner
    mapping(uint256 => address) private _owners;

    // owner => token count
    mapping(address => uint256) private _balances;

    // electionId => voter => tokenId (0 means no token)
    mapping(uint256 => mapping(address => uint256)) public voterToken;

    // ─────────────────────────────────────────────
    //  EVENTS
    // ─────────────────────────────────────────────

    event VoterCertificateMinted(
        uint256 indexed tokenId,
        uint256 indexed electionId,
        address indexed voter,
        string electionTitle,
        uint256 timestamp
    );

    // ─────────────────────────────────────────────
    //  MODIFIERS
    // ─────────────────────────────────────────────

    modifier onlyVotingContract() {
        require(
            msg.sender == votingContract,
            "Only the voting contract can mint"
        );
        _;
    }

    // ─────────────────────────────────────────────
    //  CONSTRUCTOR
    // ─────────────────────────────────────────────

    constructor(address _votingContract) {
        votingContract = _votingContract;
    }

    // ─────────────────────────────────────────────
    //  MINT FUNCTION
    // ─────────────────────────────────────────────

    /// @notice Mints a voter certificate NFT after a vote is cast
    /// @dev Can only be called by the Voting contract
    /// @param _voter Wallet address of the voter
    /// @param _electionId Election the voter participated in
    /// @param _electionTitle Title of the election
    function mintVoterCertificate(
        address _voter,
        uint256 _electionId,
        string memory _electionTitle
    ) external onlyVotingContract {
        require(
            voterToken[_electionId][_voter] == 0,
            "Certificate already minted for this election"
        );

        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;

        _owners[newTokenId] = _voter;
        _balances[_voter]++;

        tokenData[newTokenId] = TokenData({
            tokenId: newTokenId,
            electionId: _electionId,
            electionTitle: _electionTitle,
            voter: _voter,
            timestamp: block.timestamp
        });

        voterToken[_electionId][_voter] = newTokenId;

        emit VoterCertificateMinted(
            newTokenId,
            _electionId,
            _voter,
            _electionTitle,
            block.timestamp
        );
    }

    // ─────────────────────────────────────────────
    //  SOULBOUND — Transfer Disabled
    // ─────────────────────────────────────────────

    /// @notice Transfers are permanently disabled — this is a soulbound token
    function transfer(address, uint256) external pure {
        revert("Voter certificates are non-transferable");
    }

    function transferFrom(address, address, uint256) external pure {
        revert("Voter certificates are non-transferable");
    }

    function approve(address, uint256) external pure {
        revert("Voter certificates are non-transferable");
    }

    // ─────────────────────────────────────────────
    //  VIEW FUNCTIONS
    // ─────────────────────────────────────────────

    /// @notice Get the owner of a token
    function ownerOf(uint256 _tokenId) external view returns (address) {
        require(_owners[_tokenId] != address(0), "Token does not exist");
        return _owners[_tokenId];
    }

    /// @notice Get number of certificates a voter holds
    function balanceOf(address _voter) external view returns (uint256) {
        return _balances[_voter];
    }

    /// @notice Get full token data for a specific token
    function getTokenData(
        uint256 _tokenId
    ) external view returns (TokenData memory) {
        require(_owners[_tokenId] != address(0), "Token does not exist");
        return tokenData[_tokenId];
    }

    /// @notice Get token ID for a voter in a specific election
    function getVoterToken(
        uint256 _electionId,
        address _voter
    ) external view returns (uint256) {
        return voterToken[_electionId][_voter];
    }

    /// @notice Check if a voter has a certificate for a specific election
    function hasVoted(
        uint256 _electionId,
        address _voter
    ) external view returns (bool) {
        return voterToken[_electionId][_voter] != 0;
    }

    /// @notice Get total number of certificates minted
    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
