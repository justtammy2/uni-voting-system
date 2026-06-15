// ─────────────────────────────────────────────
//  CONTRACT ADDRESSES — update these after deployment
// ─────────────────────────────────────────────

const VOTING_ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
const NFT_ADDRESS = "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9";

// ─────────────────────────────────────────────
//  VOTING CONTRACT ABI
// ─────────────────────────────────────────────

const VOTING_ABI = [
    "function admin() view returns (address)",
    "function getElectionCount() view returns (uint256)",
    "function getElection(uint256 _electionId) view returns (tuple(uint256 id, string title, string description, uint256 startTime, uint256 endTime, bool exists, uint256 candidateCount, uint256 voterCount))",
    "function getCandidates(uint256 _electionId) view returns (tuple(uint256 id, string name, string position, uint256 voteCount)[])",
    "function getCandidate(uint256 _electionId, uint256 _candidateId) view returns (tuple(uint256 id, string name, string position, uint256 voteCount))",
    "function getVoterStatus(uint256 _electionId, address _voter) view returns (bool isRegistered, bool hasVoted, uint256 votedCandidateId, bytes32 matricHash)",
    "function isMatricRegistered(uint256 _electionId, string _matricNumber) view returns (bool)",
    "function isElectionActive(uint256 _electionId) view returns (bool)",
    "function getWinner(uint256 _electionId) view returns (tuple(uint256 id, string name, string position, uint256 voteCount))",
    "function createElection(string _title, string _description, uint256 _startTime, uint256 _endTime)",
    "function addCandidate(uint256 _electionId, string _name, string _position)",
    "function registerVoter(uint256 _electionId, address _voter, string _matricNumber)",
    "function castVote(uint256 _electionId, uint256 _candidateId)",
    "function setNFTContract(address _voterNFT)",
    "event ElectionCreated(uint256 indexed electionId, string title, uint256 startTime, uint256 endTime)",
    "event CandidateAdded(uint256 indexed electionId, uint256 indexed candidateId, string name, string position)",
    "event VoterRegistered(uint256 indexed electionId, address indexed voter, bytes32 matricHash)",
    "event VoteCast(uint256 indexed electionId, uint256 indexed candidateId, address indexed voter)"
];

// ─────────────────────────────────────────────
//  VOTER NFT CONTRACT ABI
// ─────────────────────────────────────────────

const NFT_ABI = [
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function totalSupply() view returns (uint256)",
    "function balanceOf(address _voter) view returns (uint256)",
    "function ownerOf(uint256 _tokenId) view returns (address)",
    "function getTokenData(uint256 _tokenId) view returns (tuple(uint256 tokenId, uint256 electionId, string electionTitle, address voter, uint256 timestamp))",
    "function getVoterToken(uint256 _electionId, address _voter) view returns (uint256)",
    "function hasVoted(uint256 _electionId, address _voter) view returns (bool)",
    "event VoterCertificateMinted(uint256 indexed tokenId, uint256 indexed electionId, address indexed voter, string electionTitle, uint256 timestamp)"
];

// ─────────────────────────────────────────────
//  PROVIDER & SIGNER SETUP
// ─────────────────────────────────────────────

let provider;
let signer;
let votingContract;
let nftContract;

async function connectWallet() {
    if (typeof window.ethereum === "undefined") {
        alert("MetaMask is not installed. Please install MetaMask to use this application.");
        return false;
    }

    try {
        await window.ethereum.request({ method: "eth_requestAccounts" });
        provider = new ethers.BrowserProvider(window.ethereum);
        signer = await provider.getSigner();
        votingContract = new ethers.Contract(VOTING_ADDRESS, VOTING_ABI, signer);
        nftContract = new ethers.Contract(NFT_ADDRESS, NFT_ABI, signer);
        return true;
    } catch (error) {
        console.error("Wallet connection failed:", error);
        alert("Failed to connect wallet. Please try again.");
        return false;
    }
}

async function getReadOnlyContracts() {
    provider = new ethers.BrowserProvider(window.ethereum);
    votingContract = new ethers.Contract(VOTING_ADDRESS, VOTING_ABI, provider);
    nftContract = new ethers.Contract(NFT_ADDRESS, NFT_ABI, provider);
}

// ─────────────────────────────────────────────
//  HELPER FUNCTIONS
// ─────────────────────────────────────────────

function shortenAddress(address) {
    return address.slice(0, 6) + "..." + address.slice(-4);
}

function formatTimestamp(timestamp) {
    return new Date(Number(timestamp) * 1000).toLocaleString();
}

function timeUntil(timestamp) {
    const now = Math.floor(Date.now() / 1000);
    const diff = Number(timestamp) - now;
    if (diff <= 0) return "Ended";
    const hours = Math.floor(diff / 3600);
    const minutes = Math.floor((diff % 3600) / 60);
    return `${hours}h ${minutes}m remaining`;
}