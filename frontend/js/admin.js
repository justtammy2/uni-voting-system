let isAdmin = false;
let elections = [];
let selectedElectionId = null;

async function handleConnect() {
    const connected = await connectWallet();
    if (!connected) return;

    const address = await signer.getAddress();
    const btn = document.getElementById("connectBtn");
    btn.textContent = "✅ " + shortenAddress(address);
    btn.classList.add("wallet-connected");

    await checkAdminAccess(address);
}

async function checkAdminAccess(address) {
    try {
        const adminAddress = await votingContract.admin();
        if (address.toLowerCase() === adminAddress.toLowerCase()) {
            isAdmin = true;
            document.getElementById("notConnected").style.display = "none";
            document.getElementById("notAdmin").style.display = "none";
            document.getElementById("dashboard").style.display = "block";
            await loadElections();
        } else {
            document.getElementById("notConnected").style.display = "none";
            document.getElementById("notAdmin").style.display = "block";
        }
    } catch (e) {
        console.error(e);
    }
}

async function loadElections() {
    try {
        const count = await votingContract.getElectionCount();
        elections = [];

        for (let i = 1; i <= count; i++) {
            const e = await votingContract.getElection(i);
            elections.push(e);
        }

        renderElectionsList();
        populateElectionDropdowns();
    } catch (e) {
        console.error("Failed to load elections:", e);
    }
}

function renderElectionsList() {
    const container = document.getElementById("electionsList");
    if (elections.length === 0) {
        container.innerHTML = '<p style="color: var(--text-muted); font-size: 0.875rem;">No elections created yet.</p>';
        return;
    }

    container.innerHTML = elections.map(e => {
        const now = Math.floor(Date.now() / 1000);
        const start = Number(e.startTime);
        const end = Number(e.endTime);
        let status, badgeClass;

        if (now < start) {
            status = "Upcoming";
            badgeClass = "badge-warning";
        } else if (now >= start && now <= end) {
            status = "Active";
            badgeClass = "badge-success";
        } else {
            status = "Ended";
            badgeClass = "badge-danger";
        }

        return `
            <div class="election-item">
                <div>
                    <div class="election-title">${e.title}</div>
                    <div class="election-meta">
                        ${e.candidateCount} candidates • ${e.voterCount} voters registered
                    </div>
                    <div class="election-meta">
                        Ends: ${formatTimestamp(e.endTime)}
                    </div>
                </div>
                <span class="badge ${badgeClass}">${status}</span>
            </div>
        `;
    }).join("");
}

function populateElectionDropdowns() {
    const dropdowns = ["candidateElectionId", "voterElectionId", "checkElectionId"];
    dropdowns.forEach(id => {
        const select = document.getElementById(id);
        select.innerHTML = '<option value="">-- Select Election --</option>';
        elections.forEach(e => {
            select.innerHTML += `<option value="${e.id}">${e.title}</option>`;
        });
    });
}

async function createElection() {
    const title = document.getElementById("electionTitle").value.trim();
    const desc = document.getElementById("electionDesc").value.trim();
    const startInput = document.getElementById("electionStart").value;
    const endInput = document.getElementById("electionEnd").value;

    if (!title || !desc || !startInput || !endInput) {
        showAlert("electionAlert", "error", "Please fill in all fields.");
        return;
    }

    const startTime = Math.floor(new Date(startInput).getTime() / 1000);
    const endTime = Math.floor(new Date(endInput).getTime() / 1000);

    if (startTime >= endTime) {
        showAlert("electionAlert", "error", "Start time must be before end time.");
        return;
    }

    try {
        const btn = document.getElementById("createElectionBtn");
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner"></span> Creating...';

        const tx = await votingContract.createElection(title, desc, startTime, endTime);
        showAlert("electionAlert", "info", "Transaction submitted. Waiting for confirmation...");
        await tx.wait();

        showAlert("electionAlert", "success", "✅ Election created successfully!");
        document.getElementById("electionTitle").value = "";
        document.getElementById("electionDesc").value = "";
        document.getElementById("electionStart").value = "";
        document.getElementById("electionEnd").value = "";

        await loadElections();
    } catch (e) {
        showAlert("electionAlert", "error", "❌ " + (e.reason || e.message || "Transaction failed"));
    } finally {
        const btn = document.getElementById("createElectionBtn");
        btn.disabled = false;
        btn.innerHTML = "➕ Create Election";
    }
}

async function addCandidate() {
    const electionId = document.getElementById("candidateElectionId").value;
    const name = document.getElementById("candidateName").value.trim();
    const position = document.getElementById("candidatePosition").value.trim();

    if (!electionId || !name || !position) {
        showAlert("candidateAlert", "error", "Please fill in all fields.");
        return;
    }

    try {
        const btn = document.getElementById("addCandidateBtn");
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner"></span> Adding...';

        const tx = await votingContract.addCandidate(electionId, name, position);
        showAlert("candidateAlert", "info", "Transaction submitted. Waiting for confirmation...");
        await tx.wait();

        showAlert("candidateAlert", "success", `✅ ${name} added as candidate successfully!`);
        document.getElementById("candidateName").value = "";
        document.getElementById("candidatePosition").value = "";

        await loadCandidates(electionId);
        await loadElections();
    } catch (e) {
        showAlert("candidateAlert", "error", "❌ " + (e.reason || e.message || "Transaction failed"));
    } finally {
        const btn = document.getElementById("addCandidateBtn");
        btn.disabled = false;
        btn.innerHTML = "➕ Add Candidate";
    }
}

async function loadCandidates(electionId) {
    try {
        const candidates = await votingContract.getCandidates(electionId);
        const container = document.getElementById("candidatesList");

        if (candidates.length === 0) {
            container.innerHTML = '<p style="color: var(--text-muted); font-size: 0.875rem;">No candidates added yet.</p>';
            return;
        }

        container.innerHTML = `
            <table>
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Name</th>
                        <th>Position</th>
                        <th>Votes</th>
                    </tr>
                </thead>
                <tbody>
                    ${candidates.map((c, i) => `
                        <tr>
                            <td>${i + 1}</td>
                            <td>${c.name}</td>
                            <td>${c.position}</td>
                            <td>${c.voteCount}</td>
                        </tr>
                    `).join("")}
                </tbody>
            </table>
        `;
    } catch (e) {
        console.error(e);
    }
}

document.getElementById("candidateElectionId")?.addEventListener("change", function () {
    if (this.value) loadCandidates(this.value);
});

async function registerVoter() {
    const electionId = document.getElementById("voterElectionId").value;
    const address = document.getElementById("voterAddress").value.trim();
    const matric = document.getElementById("voterMatric").value.trim();

    if (!electionId || !address || !matric) {
        showAlert("voterAlert", "error", "Please fill in all fields.");
        return;
    }

    if (!ethers.isAddress(address)) {
        showAlert("voterAlert", "error", "Invalid wallet address.");
        return;
    }

    try {
        const btn = document.getElementById("registerVoterBtn");
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner"></span> Registering...';

        const tx = await votingContract.registerVoter(electionId, address, matric);
        showAlert("voterAlert", "info", "Transaction submitted. Waiting for confirmation...");
        await tx.wait();

        showAlert("voterAlert", "success", `✅ Voter registered successfully!`);
        document.getElementById("voterAddress").value = "";
        document.getElementById("voterMatric").value = "";
        await loadElections();
    } catch (e) {
        showAlert("voterAlert", "error", "❌ " + (e.reason || e.message || "Transaction failed"));
    } finally {
        const btn = document.getElementById("registerVoterBtn");
        btn.disabled = false;
        btn.innerHTML = "➕ Register Voter";
    }
}

async function checkVoterStatus() {
    const electionId = document.getElementById("checkElectionId").value;
    const input = document.getElementById("checkVoter").value.trim();
    const container = document.getElementById("voterStatusResult");

    if (!electionId || !input) {
        container.innerHTML = '<div class="alert alert-error">Please select an election and enter a wallet address.</div>';
        return;
    }

    try {
        if (ethers.isAddress(input)) {
            const status = await votingContract.getVoterStatus(electionId, input);
            container.innerHTML = `
                <div class="card" style="padding: 1rem;">
                    <div style="display: flex; flex-direction: column; gap: 0.5rem;">
                        <div>Registered: <span class="badge ${status.isRegistered ? 'badge-success' : 'badge-danger'}">${status.isRegistered ? 'Yes' : 'No'}</span></div>
                        <div>Has Voted: <span class="badge ${status.hasVoted ? 'badge-success' : 'badge-warning'}">${status.hasVoted ? 'Yes' : 'No'}</span></div>
                        ${status.hasVoted ? `<div style="font-size: 0.8rem; color: var(--text-muted);">Voted for candidate #${status.votedCandidateId}</div>` : ''}
                    </div>
                </div>
            `;
        } else {
            const isRegistered = await votingContract.isMatricRegistered(electionId, input);
            container.innerHTML = `
                <div class="alert ${isRegistered ? 'alert-success' : 'alert-error'}">
                    Matric number <strong>${input}</strong> is ${isRegistered ? 'registered' : 'not registered'} for this election.
                </div>
            `;
        }
    } catch (e) {
        container.innerHTML = `<div class="alert alert-error">❌ ${e.reason || e.message}</div>`;
    }
}

function switchTab(tab) {
    document.querySelectorAll(".tab-content").forEach(t => t.classList.remove("active"));
    document.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
    document.getElementById(`tab-${tab}`).classList.add("active");
    event.target.classList.add("active");
}

function showAlert(containerId, type, message) {
    const container = document.getElementById(containerId);
    container.innerHTML = `<div class="alert alert-${type}" style="margin-bottom: 1rem;">${message}</div>`;
    setTimeout(() => { container.innerHTML = ""; }, 5000);
}