async function init() {
    try {
        if (typeof window.ethereum !== "undefined") {
            await getReadOnlyContracts();
            await loadElectionDropdowns();
        }
    } catch (e) {
        console.error("Init failed:", e);
    }
}

async function handleConnect() {
    const connected = await connectWallet();
    if (!connected) return;

    const address = await signer.getAddress();
    const btn = document.getElementById("connectBtn");
    btn.textContent = "✅ " + shortenAddress(address);
    btn.classList.add("wallet-connected");

    document.getElementById("myWalletNotConnected").style.display = "none";
    document.getElementById("myWalletConnected").style.display = "block";

    await loadElectionDropdowns();
}

async function loadElectionDropdowns() {
    try {
        const count = await votingContract.getElectionCount();
        const dropdowns = ["matricElectionId", "walletElectionId", "nftElectionId", "myWalletElectionId"];

        dropdowns.forEach(id => {
            const select = document.getElementById(id);
            select.innerHTML = '<option value="">-- Select Election --</option>';
        });

        for (let i = 1; i <= count; i++) {
            const e = await votingContract.getElection(i);
            dropdowns.forEach(id => {
                document.getElementById(id).innerHTML +=
                    `<option value="${e.id}">${e.title}</option>`;
            });
        }
    } catch (e) {
        console.error("Failed to load elections:", e);
    }
}

async function verifyMatric() {
    const electionId = document.getElementById("matricElectionId").value;
    const matric = document.getElementById("matricInput").value.trim();
    const container = document.getElementById("matricResult");

    if (!electionId || !matric) {
        container.innerHTML = '<div class="alert alert-error">Please select an election and enter a matric number.</div>';
        return;
    }

    try {
        const isRegistered = await votingContract.isMatricRegistered(electionId, matric);
        const election = await votingContract.getElection(electionId);

        if (isRegistered) {
            container.innerHTML = `
                <div class="result-card">
                    <div style="text-align: center; margin-bottom: 1rem;">
                        <div style="font-size: 2.5rem;">✅</div>
                        <div style="font-weight: 700; font-size: 1.1rem; margin-top: 0.5rem;">Matric Number Verified</div>
                    </div>
                    <div class="result-row">
                        <span class="result-label">Matric Number</span>
                        <span class="result-value">${matric}</span>
                    </div>
                    <div class="result-row">
                        <span class="result-label">Election</span>
                        <span class="result-value">${election.title}</span>
                    </div>
                    <div class="result-row">
                        <span class="result-label">Status</span>
                        <span class="result-value"><span class="badge badge-success">Registered</span></span>
                    </div>
                    <div class="result-row">
                        <span class="result-label">On-Chain Hash</span>
                        <span class="result-value" style="font-size: 0.75rem; color: var(--text-muted);">
                            ${ethers.keccak256(ethers.toUtf8Bytes(matric)).slice(0, 20)}...
                        </span>
                    </div>
                </div>
            `;
        } else {
            container.innerHTML = `
                <div class="result-card">
                    <div style="text-align: center; margin-bottom: 1rem;">
                        <div style="font-size: 2.5rem;">❌</div>
                        <div style="font-weight: 700; font-size: 1.1rem; margin-top: 0.5rem;">Not Registered</div>
                    </div>
                    <p style="color: var(--text-muted); font-size: 0.875rem; text-align: center;">
                        Matric number <strong>${matric}</strong> is not registered for <strong>${election.title}</strong>.
                    </p>
                </div>
            `;
        }
    } catch (e) {
        container.innerHTML = `<div class="alert alert-error">❌ ${e.reason || e.message}</div>`;
    }
}

async function verifyWallet() {
    const electionId = document.getElementById("walletElectionId").value;
    const address = document.getElementById("walletInput").value.trim();
    const container = document.getElementById("walletResult");

    if (!electionId || !address) {
        container.innerHTML = '<div class="alert alert-error">Please select an election and enter a wallet address.</div>';
        return;
    }

    if (!ethers.isAddress(address)) {
        container.innerHTML = '<div class="alert alert-error">Invalid wallet address.</div>';
        return;
    }

    try {
        const status = await votingContract.getVoterStatus(electionId, address);
        const election = await votingContract.getElection(electionId);

        container.innerHTML = `
            <div class="result-card">
                <div class="result-row">
                    <span class="result-label">Wallet</span>
                    <span class="result-value">${shortenAddress(address)}</span>
                </div>
                <div class="result-row">
                    <span class="result-label">Election</span>
                    <span class="result-value">${election.title}</span>
                </div>
                <div class="result-row">
                    <span class="result-label">Registered</span>
                    <span class="result-value">
                        <span class="badge ${status.isRegistered ? 'badge-success' : 'badge-danger'}">
                            ${status.isRegistered ? '✅ Yes' : '❌ No'}
                        </span>
                    </span>
                </div>
                <div class="result-row">
                    <span class="result-label">Has Voted</span>
                    <span class="result-value">
                        <span class="badge ${status.hasVoted ? 'badge-success' : 'badge-warning'}">
                            ${status.hasVoted ? '✅ Yes' : '⏳ Not yet'}
                        </span>
                    </span>
                </div>
                ${status.hasVoted ? `
                <div class="result-row">
                    <span class="result-label">Voted For</span>
                    <span class="result-value">Candidate #${status.votedCandidateId}</span>
                </div>` : ''}
            </div>
        `;
    } catch (e) {
        container.innerHTML = `<div class="alert alert-error">❌ ${e.reason || e.message}</div>`;
    }
}

async function checkMyStatus() {
    const electionId = document.getElementById("myWalletElectionId").value;
    const container = document.getElementById("myStatusResult");

    if (!electionId || !signer) return;

    try {
        const address = await signer.getAddress();
        const status = await votingContract.getVoterStatus(electionId, address);
        const election = await votingContract.getElection(electionId);

        container.innerHTML = `
            <div class="result-card">
                <div class="result-row">
                    <span class="result-label">Election</span>
                    <span class="result-value">${election.title}</span>
                </div>
                <div class="result-row">
                    <span class="result-label">Registered</span>
                    <span class="result-value">
                        <span class="badge ${status.isRegistered ? 'badge-success' : 'badge-danger'}">
                            ${status.isRegistered ? '✅ Yes' : '❌ No'}
                        </span>
                    </span>
                </div>
                <div class="result-row">
                    <span class="result-label">Has Voted</span>
                    <span class="result-value">
                        <span class="badge ${status.hasVoted ? 'badge-success' : 'badge-warning'}">
                            ${status.hasVoted ? '✅ Yes' : '⏳ Not yet'}
                        </span>
                    </span>
                </div>
            </div>
        `;
    } catch (e) {
        container.innerHTML = `<div class="alert alert-error">❌ ${e.reason || e.message}</div>`;
    }
}

async function verifyNFT() {
    const electionId = document.getElementById("nftElectionId").value;
    const address = document.getElementById("nftWalletInput").value.trim();
    const container = document.getElementById("nftResult");

    if (!electionId || !address) {
        container.innerHTML = '<div class="alert alert-error">Please select an election and enter a wallet address.</div>';
        return;
    }

    if (!ethers.isAddress(address)) {
        container.innerHTML = '<div class="alert alert-error">Invalid wallet address.</div>';
        return;
    }

    try {
        const tokenId = await nftContract.getVoterToken(electionId, address);
        const election = await votingContract.getElection(electionId);

        if (Number(tokenId) === 0) {
            container.innerHTML = `
                <div class="result-card">
                    <div style="text-align: center;">
                        <div style="font-size: 2.5rem;">❌</div>
                        <div style="font-weight: 700; margin-top: 0.5rem;">No Certificate Found</div>
                        <p style="color: var(--text-muted); font-size: 0.875rem; margin-top: 0.5rem;">
                            This wallet does not hold a voter certificate for ${election.title}.
                        </p>
                    </div>
                </div>
            `;
        } else {
            const tokenData = await nftContract.getTokenData(tokenId);
            container.innerHTML = `
                <div class="nft-card">
                    <div class="nft-icon">🏅</div>
                    <div style="font-weight: 700; font-size: 1.2rem; margin-bottom: 0.3rem;">Voter Certificate Verified</div>
                    <div style="color: var(--text-muted); font-size: 0.875rem; margin-bottom: 1.5rem;">
                        This wallet participated in ${election.title}
                    </div>
                    <div class="result-card" style="text-align: left; background: rgba(0,0,0,0.2);">
                        <div class="result-row">
                            <span class="result-label">Token ID</span>
                            <span class="result-value">#${tokenData.tokenId}</span>
                        </div>
                        <div class="result-row">
                            <span class="result-label">Election</span>
                            <span class="result-value">${tokenData.electionTitle}</span>
                        </div>
                        <div class="result-row">
                            <span class="result-label">Holder</span>
                            <span class="result-value">${shortenAddress(tokenData.voter)}</span>
                        </div>
                        <div class="result-row">
                            <span class="result-label">Issued On</span>
                            <span class="result-value">${formatTimestamp(tokenData.timestamp)}</span>
                        </div>
                        <div class="result-row">
                            <span class="result-label">Transferable</span>
                            <span class="result-value"><span class="badge badge-danger">No — Soulbound</span></span>
                        </div>
                    </div>
                </div>
            `;
        }
    } catch (e) {
        container.innerHTML = `<div class="alert alert-error">❌ ${e.reason || e.message}</div>`;
    }
}

function switchVerifyTab(tab, event) {
    document.querySelectorAll(".verify-tab-content").forEach(t => t.classList.remove("active"));
    document.querySelectorAll(".verify-tab").forEach(b => b.classList.remove("active"));
    document.getElementById(`tab-${tab}`).classList.add("active");
    event.target.classList.add("active");
}

init();