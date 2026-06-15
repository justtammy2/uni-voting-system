let selectedCandidateId = null;
let currentElectionId = null;
let currentUserAddress = null;

async function handleConnect() {
    const connected = await connectWallet();
    if (!connected) return;

    currentUserAddress = await signer.getAddress();
    const btn = document.getElementById("connectBtn");
    btn.textContent = "✅ " + shortenAddress(currentUserAddress);
    btn.classList.add("wallet-connected");

    document.getElementById("notConnected").style.display = "none";
    document.getElementById("votingInterface").style.display = "block";
    document.getElementById("walletStatus").textContent = "Connected: " + shortenAddress(currentUserAddress);

    await loadElections();
}

async function loadElections() {
    try {
        const count = await votingContract.getElectionCount();
        const select = document.getElementById("electionSelect");
        select.innerHTML = '<option value="">-- Select an election --</option>';

        for (let i = 1; i <= count; i++) {
            const e = await votingContract.getElection(i);
            const now = Math.floor(Date.now() / 1000);
            const isActive = now >= Number(e.startTime) && now <= Number(e.endTime);
            select.innerHTML += `<option value="${e.id}" ${!isActive ? 'style="color: var(--text-muted)"' : ''}>${e.title} ${isActive ? '🟢' : '⭕'}</option>`;
        }
    } catch (e) {
        console.error("Failed to load elections:", e);
    }
}

async function loadElectionDetails() {
    const electionId = document.getElementById("electionSelect").value;
    if (!electionId) {
        document.getElementById("electionDetails").style.display = "none";
        return;
    }

    currentElectionId = electionId;
    selectedCandidateId = null;

    try {
        const election = await votingContract.getElection(electionId);
        const now = Math.floor(Date.now() / 1000);
        const isActive = now >= Number(election.startTime) && now <= Number(election.endTime);
        const hasEnded = now > Number(election.endTime);

        // update election info
        document.getElementById("electionTitle").textContent = election.title;
        document.getElementById("electionDesc").textContent = election.description;
        document.getElementById("electionEnd").textContent = formatTimestamp(election.endTime);

        const statusBadge = document.getElementById("electionStatus");
        if (isActive) {
            statusBadge.textContent = "Active";
            statusBadge.className = "badge badge-success";
        } else if (hasEnded) {
            statusBadge.textContent = "Ended";
            statusBadge.className = "badge badge-danger";
        } else {
            statusBadge.textContent = "Upcoming";
            statusBadge.className = "badge badge-warning";
        }

        // turnout
        const candidates = await votingContract.getCandidates(electionId);
        let totalVotes = 0;
        candidates.forEach(c => totalVotes += Number(c.voteCount));
        const voterCount = Number(election.voterCount);
        const turnout = voterCount > 0 ? Math.round((totalVotes / voterCount) * 100) : 0;
        document.getElementById("turnoutBar").style.width = turnout + "%";
        document.getElementById("turnoutText").textContent = `${turnout}% (${totalVotes} of ${voterCount} registered voters)`;

        // voter status
        const voterStatus = await votingContract.getVoterStatus(electionId, currentUserAddress);

        document.getElementById("alreadyVoted").style.display = "none";
        document.getElementById("notRegistered").style.display = "none";
        document.getElementById("candidatesSection").style.display = "none";
        document.getElementById("voteConfirm").style.display = "none";
        document.getElementById("nftSuccess").style.display = "none";

        if (!voterStatus.isRegistered) {
            document.getElementById("notRegistered").style.display = "block";
            document.getElementById("registrationStatus").textContent = "⛔ Not registered";
            document.getElementById("votedStatus").textContent = "—";
        } else if (voterStatus.hasVoted) {
            document.getElementById("alreadyVoted").style.display = "block";
            document.getElementById("registrationStatus").textContent = "✅ Registered";
            document.getElementById("votedStatus").textContent = "✅ Voted";
        } else {
            document.getElementById("registrationStatus").textContent = "✅ Registered";
            document.getElementById("votedStatus").textContent = "⏳ Not voted yet";

            if (isActive) {
                document.getElementById("candidatesSection").style.display = "block";
                renderCandidates(candidates);
            } else if (hasEnded) {
                showVoteAlert("error", "This election has ended. Voting is no longer possible.");
            } else {
                showVoteAlert("info", "This election has not started yet. Please check back later.");
            }
        }

        document.getElementById("electionDetails").style.display = "block";

    } catch (e) {
        console.error("Failed to load election details:", e);
    }
}

function renderCandidates(candidates) {
    const grid = document.getElementById("candidatesGrid");
    const emojis = ["👨‍💼", "👩‍💼", "🧑‍💼", "👨‍🎓", "👩‍🎓", "🧑‍🎓"];

    grid.innerHTML = candidates.map((c, i) => `
        <div class="candidate-card" id="candidate-${c.id}" onclick="selectCandidate(${c.id}, '${c.name}', '${c.position}')">
            <div class="candidate-avatar">${emojis[i % emojis.length]}</div>
            <div class="candidate-name">${c.name}</div>
            <div class="candidate-position">${c.position}</div>
        </div>
    `).join("");
}

function selectCandidate(id, name, position) {
    selectedCandidateId = id;

    document.querySelectorAll(".candidate-card").forEach(c => c.classList.remove("selected"));
    document.getElementById(`candidate-${id}`).classList.add("selected");

    document.getElementById("selectedCandidateName").textContent = name;
    document.getElementById("selectedCandidatePosition").textContent = position;
    document.getElementById("voteConfirm").style.display = "block";

    document.getElementById("voteConfirm").scrollIntoView({ behavior: "smooth" });
}

function clearSelection() {
    selectedCandidateId = null;
    document.querySelectorAll(".candidate-card").forEach(c => c.classList.remove("selected"));
    document.getElementById("voteConfirm").style.display = "none";
}

async function castVote() {
    if (!selectedCandidateId || !currentElectionId) return;

    try {
        const btn = document.getElementById("castVoteBtn");
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner"></span> Submitting vote...';

        const tx = await votingContract.castVote(currentElectionId, selectedCandidateId);
        showVoteAlert("info", "Transaction submitted. Waiting for confirmation...");
        const receipt = await tx.wait();

        document.getElementById("candidatesSection").style.display = "none";
        document.getElementById("voteConfirm").style.display = "none";
        document.getElementById("voteAlert").innerHTML = "";
        document.getElementById("nftSuccess").style.display = "block";
        document.getElementById("txHash").textContent = receipt.hash;

        document.getElementById("votedStatus").textContent = "✅ Voted";

    } catch (e) {
        showVoteAlert("error", "❌ " + (e.reason || e.message || "Transaction failed"));
        const btn = document.getElementById("castVoteBtn");
        btn.disabled = false;
        btn.innerHTML = "✅ Confirm Vote";
    }
}

function showVoteAlert(type, message) {
    document.getElementById("voteAlert").innerHTML = `<div class="alert alert-${type}">${message}</div>`;
}