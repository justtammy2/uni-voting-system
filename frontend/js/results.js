let refreshInterval = null;

async function handleConnect() {
    const connected = await connectWallet();
    if (!connected) return;
    const address = await signer.getAddress();
    const btn = document.getElementById("connectBtn");
    btn.textContent = "✅ " + shortenAddress(address);
    btn.classList.add("wallet-connected");
}

async function init() {
    try {
        if (typeof window.ethereum !== "undefined") {
            await getReadOnlyContracts();
            await loadElectionDropdown();
        }
    } catch (e) {
        console.error("Init failed:", e);
    }
}

async function loadElectionDropdown() {
    try {
        const count = await votingContract.getElectionCount();
        const select = document.getElementById("electionSelect");
        select.innerHTML = '<option value="">-- Select an election --</option>';

        if (count == 0) {
            document.getElementById("emptyState").style.display = "block";
            return;
        }

        for (let i = 1; i <= count; i++) {
            const e = await votingContract.getElection(i);
            const now = Math.floor(Date.now() / 1000);
            const isActive = now >= Number(e.startTime) && now <= Number(e.endTime);
            select.innerHTML += `<option value="${e.id}">${e.title} ${isActive ? '🟢' : ''}</option>`;
        }

        // auto load first election
        select.selectedIndex = 1;
        await loadResults();

    } catch (e) {
        console.error("Failed to load elections:", e);
    }
}

async function loadResults() {
    const electionId = document.getElementById("electionSelect").value;
    if (!electionId) {
        document.getElementById("resultsContent").style.display = "none";
        return;
    }

    try {
        const election = await votingContract.getElection(electionId);
        const candidates = await votingContract.getCandidates(electionId);
        const now = Math.floor(Date.now() / 1000);
        const isActive = now >= Number(election.startTime) && now <= Number(election.endTime);
        const hasEnded = now > Number(election.endTime);

        // stats
        let totalVotes = 0;
        candidates.forEach(c => totalVotes += Number(c.voteCount));
        const voterCount = Number(election.voterCount);
        const turnout = voterCount > 0 ? Math.round((totalVotes / voterCount) * 100) : 0;

        document.getElementById("statTotalVotes").textContent = totalVotes;
        document.getElementById("statRegistered").textContent = voterCount;
        document.getElementById("statTurnout").textContent = turnout + "%";
        document.getElementById("statCandidates").textContent = candidates.length;

        // status badge
        const statusBadge = document.getElementById("electionStatusBadge");
        if (isActive) {
            statusBadge.textContent = "Active";
            statusBadge.className = "badge badge-success";
            document.getElementById("liveIndicator").style.display = "inline-flex";
            document.getElementById("autoRefreshNote").style.display = "inline";
            startAutoRefresh();
        } else if (hasEnded) {
            statusBadge.textContent = "Ended";
            statusBadge.className = "badge badge-danger";
            document.getElementById("liveIndicator").style.display = "none";
            document.getElementById("autoRefreshNote").style.display = "none";
            stopAutoRefresh();
        } else {
            statusBadge.textContent = "Upcoming";
            statusBadge.className = "badge badge-warning";
            document.getElementById("liveIndicator").style.display = "none";
            stopAutoRefresh();
        }

        // winner
        if (hasEnded && totalVotes > 0) {
            try {
                const winner = await votingContract.getWinner(electionId);
                document.getElementById("winnerName").textContent = winner.name;
                document.getElementById("winnerPosition").textContent = winner.position;
                document.getElementById("winnerVotes").textContent = `${winner.voteCount} votes`;
                document.getElementById("winnerCard").style.display = "block";
            } catch (e) {
                document.getElementById("winnerCard").style.display = "none";
            }
        } else {
            document.getElementById("winnerCard").style.display = "none";
        }

        // standings
        const sorted = [...candidates].sort((a, b) => Number(b.voteCount) - Number(a.voteCount));
        const maxVotes = sorted.length > 0 ? Number(sorted[0].voteCount) : 1;

        const colors = ["var(--primary)", "var(--secondary)", "var(--warning)", "var(--danger)"];

        document.getElementById("standingsList").innerHTML = sorted.map((c, i) => {
            const votes = Number(c.voteCount);
            const percentage = totalVotes > 0 ? Math.round((votes / totalVotes) * 100) : 0;
            const barWidth = maxVotes > 0 ? Math.round((votes / maxVotes) * 100) : 0;
            const isWinner = hasEnded && i === 0 && votes > 0;

            return `
                <div class="candidate-result">
                    <div class="candidate-result-header">
                        <div style="display: flex; align-items: center; gap: 0.75rem;">
                            <span style="font-size: 1.2rem;">${i === 0 ? '🥇' : i === 1 ? '🥈' : i === 2 ? '🥉' : `#${i + 1}`}</span>
                            <div>
                                <div class="candidate-result-name">
                                    ${c.name}
                                    ${isWinner ? '<span class="badge badge-success" style="margin-left: 0.5rem;">Winner</span>' : ''}
                                </div>
                                <div style="font-size: 0.8rem; color: var(--text-muted);">${c.position}</div>
                            </div>
                        </div>
                        <div style="text-align: right;">
                            <div style="font-weight: 700; font-size: 1.1rem;">${votes}</div>
                            <div class="candidate-result-votes">${percentage}%</div>
                        </div>
                    </div>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: ${barWidth}%; background: ${colors[i % colors.length]};"></div>
                    </div>
                </div>
            `;
        }).join("");

        document.getElementById("lastUpdated").textContent = new Date().toLocaleTimeString();
        document.getElementById("resultsContent").style.display = "block";

    } catch (e) {
        console.error("Failed to load results:", e);
    }
}

function startAutoRefresh() {
    if (refreshInterval) return;
    refreshInterval = setInterval(loadResults, 15000);
}

function stopAutoRefresh() {
    if (refreshInterval) {
        clearInterval(refreshInterval);
        refreshInterval = null;
    }
}

init();