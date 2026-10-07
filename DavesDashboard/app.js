function formatMoney(copper) {
    const isNeg = copper < 0;
    copper = Math.abs(copper);
    const g = Math.floor(copper / 10000);
    const s = Math.floor((copper % 10000) / 100);
    const c = copper % 100;
    let str = "";
    if (g > 0) str += `${g}g `;
    if (s > 0) str += `${s}s `;
    if (c > 0 || str === "") str += `${c}c`;
    return (isNeg ? "-" : "+") + str.trim();
}

function formatDuration(sec) {
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    return `${h}h ${m}m`;
}

// --- Profile Handling ---
let profileName = localStorage.getItem('profileName') || 'Dave The Farmer';
let profileAvatarUrl = localStorage.getItem('profileAvatarUrl') || 'https://api.dicebear.com/7.x/avataaars/svg?seed=Dave&backgroundColor=c0aede';
let selectedAvatarUrl = profileAvatarUrl;

function updateProfileUI() {
    const nameEl = document.getElementById('profile-name-text');
    const imgEl = document.getElementById('profile-avatar-img');
    if (nameEl) nameEl.textContent = profileName;
    if (imgEl) imgEl.src = profileAvatarUrl;
}

// Call initially
updateProfileUI();
// ------------------------

let savingsGoalGold = parseInt(localStorage.getItem('savingsGoal')) || 1000000;
let currentGoldCopper = 0;

function updateGoalUI() {
    const goalCopper = savingsGoalGold * 10000;
    const displayEl = document.getElementById('goal-amount-display');
    const progressEl = document.getElementById('goal-progress');
    
    if (displayEl) displayEl.textContent = savingsGoalGold.toLocaleString() + 'g';
    
    let progress = 0;
    if (goalCopper > 0) {
        progress = (currentGoldCopper / goalCopper) * 100;
    }
    if (progress > 100) progress = 100;
    if (progress < 0) progress = 0;
    
    if (progressEl) progressEl.style.width = `${progress}%`;
}

async function fetchData() {
    try {
        const res = await fetch('/api/wallet?t=' + new Date().getTime(), {
            headers: {
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache'
            }
        });
        if (!res.ok) throw new Error("API not available");
        const jsonRes = await res.json();
        
        const data = jsonRes.data.history || [];
        const currentGold = jsonRes.data.currentGold || 0;
        currentGoldCopper = currentGold;
        updateGoalUI();
        
        const modal = document.getElementById('setup-modal');
        // Only auto-show if we need setup and it's our first time noticing. 
        // We never auto-hide here anymore, because the user might have opened it manually via Settings.
        if (jsonRes.status === "needs_setup" && !window.hasPromptedSetup) {
            modal.classList.remove('hidden');
            window.hasPromptedSetup = true;
        }
        
        if (!data || data.length === 0) {
            document.getElementById('current-gold').textContent = formatMoney(currentGold);
            document.getElementById('net-profit').textContent = formatMoney(0);
            document.getElementById('best-session').textContent = formatMoney(0);
            document.getElementById('avg-gold').textContent = formatMoney(0);
            document.getElementById('chart-container').innerHTML = '<div class="loading">No WoW data found. Play the game to generate some!</div>';
            document.getElementById('income-list').innerHTML = '<div class="loading" style="position: static;">No income data...</div>';
            document.getElementById('expense-list').innerHTML = '<div class="loading" style="position: static;">No expense data...</div>';
            return;
        }

        let totalProfit = 0;
        let totalTime = 0;
        let bestSession = -999999999;
        let aggregatedBreakdown = {};

        data.forEach(session => {
            totalProfit += session.diff || 0;
            totalTime += session.duration || 0;
            if ((session.diff || 0) > bestSession) {
                bestSession = session.diff;
            }
            if (session.breakdown) {
                for (let [key, val] of Object.entries(session.breakdown)) {
                    aggregatedBreakdown[key] = (aggregatedBreakdown[key] || 0) + val;
                }
            }
        });
        
        if (bestSession === -999999999) bestSession = 0;

        const avgGold = totalTime > 0 ? (totalProfit / (totalTime / 3600)) : 0;

        document.getElementById('current-gold').textContent = formatMoney(currentGold);

        const npEl = document.getElementById('net-profit');
        npEl.textContent = formatMoney(totalProfit);
        npEl.className = 'stat-value ' + (totalProfit >= 0 ? 'positive' : 'negative');
        
        document.getElementById('best-session').textContent = formatMoney(bestSession);
        
        const avgEl = document.getElementById('avg-gold');
        avgEl.textContent = formatMoney(Math.floor(avgGold));
        avgEl.className = 'stat-value ' + (avgGold >= 0 ? 'positive' : 'negative');

        renderChart(data);
        renderBreakdown(aggregatedBreakdown);

    } catch (e) {
        console.error("Error fetching data:", e);
    }
}

function renderChart(data) {
    const container = document.getElementById('chart-container');
    container.innerHTML = '';
    
    // Only show last 15 sessions for cleaner UI
    const displayData = data.slice(-15);
    
    let maxDiff = 1;
    displayData.forEach(d => {
        if (Math.abs(d.diff) > maxDiff) maxDiff = Math.abs(d.diff);
    });

    displayData.forEach(session => {
        const wrapper = document.createElement('div');
        wrapper.className = 'bar-wrapper';
        
        const isLoss = session.diff < 0;
        const heightPct = (Math.abs(session.diff) / maxDiff) * 100;
        
        const bar = document.createElement('div');
        bar.className = 'bar' + (isLoss ? ' loss' : '');
        // Animate height shortly after rendering
        setTimeout(() => { bar.style.height = `${Math.max(5, heightPct)}%`; }, 50);

        const tooltip = document.createElement('div');
        tooltip.className = 'tooltip';
        tooltip.innerHTML = `
            <strong>${session.date || 'Unknown Date'}</strong><br>
            Time: ${session.startTimeStr || '?'} - ${session.endTimeStr || '?'}<br>
            Profit: <span style="color: ${isLoss ? 'var(--negative)' : 'var(--positive)'}">${formatMoney(session.diff)}</span><br>
            Duration: ${formatDuration(session.duration || 0)}
        `;

        const label = document.createElement('div');
        label.className = 'bar-label';
        // Show day of month
        label.textContent = session.date ? session.date.split('-')[2] : '?';

        wrapper.appendChild(tooltip);
        wrapper.appendChild(bar);
        wrapper.appendChild(label);
        container.appendChild(wrapper);
    });
}

function renderBreakdown(breakdownObj) {
    const incomes = [];
    const expenses = [];

    for (let [key, val] of Object.entries(breakdownObj)) {
        if (val > 0) incomes.push({key, val});
        else if (val < 0) expenses.push({key, val});
    }

    incomes.sort((a, b) => b.val - a.val);
    expenses.sort((a, b) => a.val - b.val); // Most negative first

    const incomeList = document.getElementById('income-list');
    const expenseList = document.getElementById('expense-list');

    incomeList.innerHTML = '';
    expenseList.innerHTML = '';

    if (incomes.length === 0) incomeList.innerHTML = '<div class="loading" style="position: static;">No income data...</div>';
    if (expenses.length === 0) expenseList.innerHTML = '<div class="loading" style="position: static;">No expense data...</div>';

    incomes.forEach(item => {
        incomeList.innerHTML += `
            <div class="list-item fade-in">
                <div class="list-item-left">
                    <div class="list-item-icon" style="background: rgba(46, 234, 130, 0.1); color: var(--positive);">↗</div>
                    <span class="list-item-name">${item.key}</span>
                </div>
                <span class="positive">+${formatMoney(item.val)}</span>
            </div>
        `;
    });

    expenses.forEach(item => {
        expenseList.innerHTML += `
            <div class="list-item fade-in">
                <div class="list-item-left">
                    <div class="list-item-icon" style="background: rgba(195, 100, 250, 0.1); color: var(--accent-primary);">↙</div>
                    <span class="list-item-name">${item.key}</span>
                </div>
                <span class="negative">${formatMoney(item.val)}</span>
            </div>
        `;
    });
}

document.getElementById('save-path-btn').addEventListener('click', async () => {
    const pathInput = document.getElementById('wow-path').value;
    if (!pathInput) return;
    
    try {
        const res = await fetch('/api/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ path: pathInput })
        });
        if (res.ok) {
            document.getElementById('setup-modal').classList.add('hidden');
            alert("Success! Your DavesWallet.lua file was linked and saved permanently.");
            fetchData();
        } else {
            alert("Error: The server couldn't validate that file. Make sure it is the correct DavesWallet.lua!");
        }
    } catch (e) {
        console.error("Error saving config:", e);
        alert("A network error occurred while trying to save.");
    }
});

document.getElementById('settings-btn').addEventListener('click', () => {
    document.getElementById('setup-modal').classList.remove('hidden');
});

document.getElementById('close-modal-btn').addEventListener('click', () => {
    document.getElementById('setup-modal').classList.add('hidden');
});

document.getElementById('browse-btn').addEventListener('click', async () => {
    try {
        const res = await fetch('/api/browse');
        if (res.ok) {
            const data = await res.json();
            if (data.path) {
                document.getElementById('wow-path').value = data.path;
            }
        }
    } catch (e) {
        console.error("Error opening file browser:", e);
    }
});

// Goal Modal Handlers
document.getElementById('set-goal-nav-btn').addEventListener('click', (e) => {
    e.preventDefault();
    document.getElementById('goal-input').value = savingsGoalGold;
    document.getElementById('goal-modal').classList.remove('hidden');
});

document.getElementById('close-goal-btn').addEventListener('click', () => {
    document.getElementById('goal-modal').classList.add('hidden');
});

document.getElementById('save-goal-btn').addEventListener('click', () => {
    const newGoal = parseInt(document.getElementById('goal-input').value);
    if (newGoal && newGoal > 0) {
        savingsGoalGold = newGoal;
        localStorage.setItem('savingsGoal', savingsGoalGold);
        document.getElementById('goal-modal').classList.add('hidden');
        updateGoalUI();
    }
});

// Profile Modal Handlers
const premadeAvatars = document.querySelectorAll('.premade-avatar');

function updatePremadeAvatarSelection() {
    premadeAvatars.forEach(img => {
        if (img.getAttribute('data-src') === selectedAvatarUrl) {
            img.classList.add('selected');
        } else {
            img.classList.remove('selected');
        }
    });
}

document.getElementById('edit-profile-trigger').addEventListener('click', () => {
    document.getElementById('profile-name-input').value = profileName;
    selectedAvatarUrl = profileAvatarUrl;
    updatePremadeAvatarSelection();
    document.getElementById('profile-modal').classList.remove('hidden');
});

document.getElementById('close-profile-btn').addEventListener('click', () => {
    document.getElementById('profile-modal').classList.add('hidden');
});

premadeAvatars.forEach(img => {
    img.addEventListener('click', () => {
        selectedAvatarUrl = img.getAttribute('data-src');
        updatePremadeAvatarSelection();
    });
});

document.getElementById('avatar-upload').addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (file) {
        const reader = new FileReader();
        reader.onload = function(event) {
            selectedAvatarUrl = event.target.result;
            // Deselect premade avatars when a file is uploaded
            premadeAvatars.forEach(img => img.classList.remove('selected'));
        };
        reader.readAsDataURL(file);
    }
});

document.getElementById('save-profile-btn').addEventListener('click', () => {
    const newName = document.getElementById('profile-name-input').value.trim();
    if (newName) {
        profileName = newName;
        profileAvatarUrl = selectedAvatarUrl;
        
        localStorage.setItem('profileName', profileName);
        localStorage.setItem('profileAvatarUrl', profileAvatarUrl);
        
        updateProfileUI();
        document.getElementById('profile-modal').classList.add('hidden');
    }
});

// Fetch on load and poll every 5 seconds
fetchData();
setInterval(fetchData, 5000);
