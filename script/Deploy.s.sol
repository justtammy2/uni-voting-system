// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Voting.sol";
import "../src/VoterNFT.sol";

contract DeployVotingSystem is Script {
    function run() external {
        vm.startBroadcast();

        // Step 1 — deploy VoterNFT with dummy address first
        VoterNFT nft = new VoterNFT(address(1));
        console.log("VoterNFT deployed at:", address(nft));

        // Step 2 — deploy Voting with NFT address
        Voting voting = new Voting(address(nft));
        console.log("Voting deployed at:", address(voting));

        // Step 3 — update NFT to point to correct Voting address
        voting.setNFTContract(address(nft));
        console.log("NFT contract linked to Voting contract");

        // Step 4 — deploy fresh NFT with correct voting address
        VoterNFT nftFinal = new VoterNFT(address(voting));
        voting.setNFTContract(address(nftFinal));
        console.log("Final VoterNFT deployed at:", address(nftFinal));

        vm.stopBroadcast();

        console.log("=====================================");
        console.log("DEPLOYMENT COMPLETE");
        console.log("Voting Contract:  ", address(voting));
        console.log("VoterNFT Contract:", address(nftFinal));
        console.log("=====================================");
    }
}
