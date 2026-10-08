function animateValue(obj, start, end, duration) {
    let startTimestamp = null;
    const step = (timestamp) => {
        if (!startTimestamp) startTimestamp = timestamp;
        const progress = Math.min((timestamp - startTimestamp) / duration, 1);
        const current = Math.floor(progress * (end - start) + start);
        obj.textContent = formatMoney(current);
        if (progress < 1) {
            window.requestAnimationFrame(step);
        }
    };
    window.requestAnimationFrame(step);
}

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
let activeCharacter = localStorage.getItem('activeCharacter') || null;

function loadProfileForCharacter() {
    if (!activeCharacter) return;
    const defaultName = activeCharacter.split('-')[1] || 'Dave The Farmer';
    profileName = localStorage.getItem('profileName_' + activeCharacter) || defaultName;
    profileAvatarUrl = localStorage.getItem('profileAvatarUrl_' + activeCharacter) || 'https://api.dicebear.com/7.x/avataaars/svg?seed=' + defaultName + '&backgroundColor=c0aede';
    selectedAvatarUrl = profileAvatarUrl;
    
    savingsGoalGold = parseInt(localStorage.getItem('savingsGoal_' + activeCharacter)) || parseInt(localStorage.getItem('savingsGoal')) || 1000000;
    
    const nameEl = document.getElementById('profile-name-text');
    const imgEl = document.getElementById('profile-avatar-img');
    if (nameEl) nameEl.textContent = profileName;
    if (imgEl) imgEl.src = profileAvatarUrl;
}

// Global scope vars for profile
let profileName = 'Dave The Farmer';
let profileAvatarUrl = 'https://api.dicebear.com/7.x/avataaars/svg?seed=Dave&backgroundColor=c0aede';
let selectedAvatarUrl = profileAvatarUrl;

let savingsGoalGold = 1000000;
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
        
        const allData = jsonRes.data || {};
        const characters = Object.keys(allData);
        
        const selector = document.getElementById('character-selector');
        
        if (characters.length === 0) {
            selector.innerHTML = '<option value="">No characters found</option>';
            document.getElementById('chart-container').innerHTML = '<div class="loading">No WoW data found. Play the game to generate some!</div>';
            return;
        }
        
        if (!activeCharacter || !characters.includes(activeCharacter)) {
            activeCharacter = characters[0];
            localStorage.setItem('activeCharacter', activeCharacter);
        }
        
        let selectHtml = '';
        characters.forEach(c => {
            const parts = c.split('-');
            const display = parts.length > 1 ? `${parts[1]} (${parts[0]})` : c;
            selectHtml += `<option value="${c}" ${c === activeCharacter ? 'selected' : ''}>${display}</option>`;
        });
        selector.innerHTML = selectHtml;
        
        loadProfileForCharacter();

        const charData = allData[activeCharacter] || { history: [], currentGold: 0 };
        const data = charData.history || [];
        const currentGold = charData.currentGold || 0;
        
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

        animateValue(document.getElementById('current-gold'), 0, currentGold, 2000);

        const npEl = document.getElementById('net-profit');
        animateValue(npEl, 0, totalProfit, 1500);
        npEl.className = 'stat-value ' + (totalProfit >= 0 ? 'positive' : 'negative');
        
        animateValue(document.getElementById('best-session'), 0, bestSession, 1500);
        
        const avgEl = document.getElementById('avg-gold');
        animateValue(avgEl, 0, Math.floor(avgGold), 1500);
        avgEl.className = 'stat-value ' + (avgGold >= 0 ? 'positive' : 'negative');

        renderChart(data);
        renderLedger(data);
        renderBreakdown(aggregatedBreakdown);
        
        // Update gathering data
        if (jsonRes.gather) {
            globalGatheringData = jsonRes.gather;
            if (window.renderGatheringList) {
                window.renderGatheringList();
            }
        }

    } catch (e) {
        console.error("Error fetching data:", e);
    }
}

let wealthChartInstance = null;

function renderChart(data) {
    const canvas = document.getElementById('wealth-chart');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    
    // Calculate cumulative wealth over sessions
    let cumulative = [];
    let labels = [];
    let colors = [];
    
    // Determine starting gold before these sessions
    let runningTotal = 0;
    
    data.forEach(session => {
        runningTotal += (session.diff || 0);
        cumulative.push(runningTotal / 10000); // Store as gold for chart
        labels.push(session.date ? session.date.split('-')[2] : '?');
        colors.push(session.diff >= 0 ? '#2eea82' : '#c364fa');
    });

    if (wealthChartInstance) {
        wealthChartInstance.destroy();
    }

    wealthChartInstance = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Session Profit/Loss (Gold)',
                data: data.map(d => (d.diff || 0) / 10000),
                backgroundColor: colors,
                borderRadius: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false }
            },
            scales: {
                y: {
                    grid: { color: 'rgba(255,255,255,0.05)' },
                    ticks: { color: 'rgba(255,255,255,0.5)' }
                },
                x: {
                    grid: { display: false },
                    ticks: { color: 'rgba(255,255,255,0.5)' }
                }
            }
        }
    });
}

function renderLedger(data) {
    const tbody = document.getElementById('ledger-list-body');
    if (!tbody) return;
    
    tbody.innerHTML = '';
    
    if (data.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" class="loading">No sessions found...</td></tr>';
        return;
    }
    
    // Show newest first
    const reversedData = [...data].reverse();
    
    reversedData.forEach(session => {
        let topIncome = "-";
        let topExpense = "-";
        
        if (session.breakdown) {
            let maxIn = 0;
            let maxOut = 0;
            for (let [k, v] of Object.entries(session.breakdown)) {
                if (v > maxIn) { maxIn = v; topIncome = k; }
                if (v < maxOut) { maxOut = v; topExpense = k; }
            }
        }
        
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${session.date} <span style="color:var(--text-secondary); font-size: 0.85em;">(${session.startTimeStr} - ${session.endTimeStr})</span></td>
            <td>${formatDuration(session.duration || 0)}</td>
            <td style="font-weight: 600; color: ${session.diff >= 0 ? 'var(--positive)' : 'var(--negative)'}">${formatMoney(session.diff)}</td>
            <td>${topIncome}</td>
            <td>${topExpense}</td>
        `;
        tbody.appendChild(tr);
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
    if (newGoal && newGoal > 0 && activeCharacter) {
        savingsGoalGold = newGoal;
        localStorage.setItem('savingsGoal_' + activeCharacter, savingsGoalGold);
        document.getElementById('goal-modal').classList.add('hidden');
        updateGoalUI();
    }
});

document.getElementById('character-selector').addEventListener('change', (e) => {
    activeCharacter = e.target.value;
    localStorage.setItem('activeCharacter', activeCharacter);
    fetchData(); // instantly update UI for new char
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
    if (newName && activeCharacter) {
        profileName = newName;
        profileAvatarUrl = selectedAvatarUrl;
        
        localStorage.setItem('profileName_' + activeCharacter, profileName);
        localStorage.setItem('profileAvatarUrl_' + activeCharacter, profileAvatarUrl);
        
        loadProfileForCharacter();
        document.getElementById('profile-modal').classList.add('hidden');
    }
});

// Fetch on load and poll every 5 seconds
fetchData();
setInterval(fetchData, 5000);

// ==========================================
// Navigation & Views
// ==========================================
const navDashboard = document.getElementById('nav-dashboard');
const navLedger = document.getElementById('nav-ledger');
const navMap = document.getElementById('nav-map');

const viewDashboard = document.getElementById('view-dashboard');
const viewLedger = document.getElementById('view-ledger');
const viewMap = document.getElementById('view-map');
const pageTitle = document.getElementById('page-title');

function switchView(viewId) {
    [viewDashboard, viewLedger, viewMap].forEach(v => {
        if (v) {
            v.classList.add('hidden');
            v.classList.remove('active');
        }
    });
    [navDashboard, navLedger, navMap].forEach(n => {
        if (n) n.classList.remove('active');
    });
    
    if (viewId === 'dashboard') {
        viewDashboard.classList.remove('hidden');
        viewDashboard.classList.add('active');
        navDashboard.classList.add('active');
        pageTitle.textContent = "Dashboard";
    } else if (viewId === 'ledger') {
        viewLedger.classList.remove('hidden');
        viewLedger.classList.add('active');
        navLedger.classList.add('active');
        pageTitle.textContent = "Session Ledger";
    } else if (viewId === 'map') {
        viewMap.classList.remove('hidden');
        viewMap.classList.add('active');
        navMap.classList.add('active');
        pageTitle.textContent = "Gathering List";
    }
}

navDashboard.addEventListener('click', (e) => { e.preventDefault(); switchView('dashboard'); });
navLedger.addEventListener('click', (e) => { e.preventDefault(); switchView('ledger'); });
navMap.addEventListener('click', (e) => { e.preventDefault(); switchView('map'); });

// ==========================================
// Daves Gather - List Initialization
// ==========================================
// Global gathering data so it can be updated by fetchData
let globalGatheringData = [];

function initGatheringList() {
    const listBody = document.getElementById('gathering-list-body');
    const searchInput = document.getElementById('gathering-search');
    
    const filterName = document.getElementById('filter-name');
    const filterType = document.getElementById('filter-type');
    const filterLocation = document.getElementById('filter-location');

    let sortCol = '';
    let sortAsc = true;

    document.querySelectorAll('.sort-header').forEach(th => {
        th.addEventListener('click', (e) => {
            if (e.target.tagName.toLowerCase() === 'select' || e.target.tagName.toLowerCase() === 'option') return;
            
            const col = th.getAttribute('data-sort');
            if (sortCol === col) {
                sortAsc = !sortAsc;
            } else {
                sortCol = col;
                sortAsc = true;
            }
            window.renderGatheringList();
        });
    });

    window.renderGatheringList = function() {
        listBody.innerHTML = "";
        
        // Populate Dropdowns dynamically if needed
        const uniqueNames = [...new Set(globalGatheringData.map(d => d.name))].sort();
        const uniqueTypes = [...new Set(globalGatheringData.map(d => d.type))].sort();
        
        const allLocs = new Set();
        globalGatheringData.forEach(d => {
            d.locations.split(',').forEach(l => allLocs.add(l.trim()));
        });
        const uniqueLocations = [...allLocs].sort();

        // Save current selection
        const currName = filterName.value;
        const currType = filterType.value;
        const currLoc = filterLocation.value;

        filterName.innerHTML = '<option value="">All</option>';
        filterType.innerHTML = '<option value="">All</option>';
        filterLocation.innerHTML = '<option value="">All</option>';

        uniqueNames.forEach(n => filterName.add(new Option(n, n, false, n===currName)));
        uniqueTypes.forEach(t => filterType.add(new Option(t, t, false, t===currType)));
        uniqueLocations.forEach(l => filterLocation.add(new Option(l, l, false, l===currLoc)));

        const qSearch = searchInput.value.toLowerCase();
        const qName = filterName.value;
        const qType = filterType.value;
        const qLoc = filterLocation.value;

        let filtered = globalGatheringData.filter(item => {
            // Check text search
            const matchesSearch = item.name.toLowerCase().includes(qSearch) || 
                                  item.locations.toLowerCase().includes(qSearch) ||
                                  item.type.toLowerCase().includes(qSearch);
            if (!matchesSearch) return false;

            // Check dropdowns
            if (qName && item.name !== qName) return false;
            if (qType && item.type !== qType) return false;
            if (qLoc && !item.locations.split(',').map(l=>l.trim()).includes(qLoc)) return false;

            return true;
        });

        // Apply sorting
        if (sortCol) {
            filtered.sort((a, b) => {
                let valA = a[sortCol];
                let valB = b[sortCol];
                
                if (typeof valA === 'string') {
                    valA = valA.toLowerCase();
                    valB = valB.toLowerCase();
                    if (valA < valB) return sortAsc ? -1 : 1;
                    if (valA > valB) return sortAsc ? 1 : -1;
                    return 0;
                } else {
                    return sortAsc ? (valA - valB) : (valB - valA);
                }
            });
        }

        if (filtered.length === 0) {
            listBody.innerHTML = '<tr><td colspan="5" class="loading">No items found matching criteria.</td></tr>';
            return;
        }

        filtered.forEach(item => {
            const tr = document.createElement('tr');
            
            // Icon styling based on type
            let iconColor = "rgba(255,255,255,0.1)";
            if (item.type === "Mining") iconColor = "rgba(255, 87, 34, 0.2)";
            if (item.type === "Herbalism") iconColor = "rgba(76, 175, 80, 0.2)";

            tr.innerHTML = `
                <td>
                    <div style="display: flex; align-items: center; gap: 10px;">
                        <div style="width: 32px; height: 32px; border-radius: 8px; background: ${iconColor}; display: flex; align-items: center; justify-content: center;">📦</div>
                        <span style="font-weight: 500;">${item.name}</span>
                    </div>
                </td>
                <td style="color: var(--text-secondary);">${item.type}</td>
                <td style="color: var(--text-secondary);">${item.locations}</td>
                <td>${formatMoney(item.vendor)}</td>
                <td style="font-weight: 600; color: var(--positive);">${formatMoney(item.auction)}</td>
            `;
            listBody.appendChild(tr);
        });
    }

    searchInput.addEventListener('input', window.renderGatheringList);
    filterName.addEventListener('change', window.renderGatheringList);
    filterType.addEventListener('change', window.renderGatheringList);
    filterLocation.addEventListener('change', window.renderGatheringList);

    // Initial render
    window.renderGatheringList();
}

// Initialize list on script load
initGatheringList();
