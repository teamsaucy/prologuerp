let vehicles = [];
let outVehicles = [];
let elsewhereVehicles = [];
let impoundedVehicles = [];
let societyVehicles = [];
let garageList = [];
let activeIndex = null;
let retrievingPlate = null;
let activeTab = 'personal';
let hasSociety = false;
let isImpound = false;
let impoundFee = 250;
let transferDropdownPlate = null;

// ── NUI Message Handler ──

window.addEventListener('message', function(e) {
    var data = e.data;

    if (data.action === 'openGarage') {
        isImpound = false;
        vehicles = data.vehicles || [];
        outVehicles = data.outVehicles || [];
        elsewhereVehicles = data.elsewhereVehicles || [];
        impoundedVehicles = data.impoundedVehicles || [];
        societyVehicles = data.societyVehicles || [];
        garageList = data.garageList || [];
        hasSociety = societyVehicles.length > 0;
        activeTab = 'personal';
        activeIndex = vehicles.length > 0 ? 0 : null;
        retrievingPlate = null;
        transferDropdownPlate = null;

        document.getElementById('garage-label').textContent = data.label || 'Garage';
        document.getElementById('search-input').value = '';

        var tabBar = document.getElementById('tab-bar');
        if (hasSociety) {
            tabBar.classList.remove('hidden');
            updateTabButtons();
        } else {
            tabBar.classList.add('hidden');
        }

        render();
        document.getElementById('garage-container').classList.remove('hidden');
    }

    if (data.action === 'openImpound') {
        isImpound = true;
        impoundFee = data.fee || 250;
        vehicles = data.vehicles || [];
        outVehicles = [];
        elsewhereVehicles = [];
        impoundedVehicles = [];
        societyVehicles = [];
        garageList = [];
        hasSociety = false;
        activeTab = 'personal';
        activeIndex = vehicles.length > 0 ? 0 : null;
        retrievingPlate = null;
        transferDropdownPlate = null;

        document.getElementById('garage-label').textContent = data.label || 'Impound Lot';
        document.getElementById('search-input').value = '';
        document.getElementById('tab-bar').classList.add('hidden');

        renderImpound();
        document.getElementById('garage-container').classList.remove('hidden');
    }

    if (data.action === 'closeGarage') {
        document.getElementById('garage-container').classList.add('hidden');
        vehicles = []; outVehicles = []; elsewhereVehicles = []; impoundedVehicles = []; societyVehicles = []; garageList = [];
        activeIndex = null; retrievingPlate = null; activeTab = 'personal'; hasSociety = false; isImpound = false; transferDropdownPlate = null;
    }
});

// ── Tab Switching ──

function switchTab(tab) {
    activeTab = tab;
    activeIndex = null;
    retrievingPlate = null;
    transferDropdownPlate = null;
    document.getElementById('search-input').value = '';
    updateTabButtons();

    var list = (tab === 'personal') ? vehicles : societyVehicles;
    if (list.length > 0) activeIndex = 0;

    render();

    if (list.length > 0) {
        var id = (tab === 'personal') ? list[0].plate : list[0].model;
        fetch('https://prologue_garage/selectCard', {
            method: 'POST',
            body: JSON.stringify({ plate: id, society: (tab === 'society') })
        });
    }
}

function updateTabButtons() {
    var btns = document.querySelectorAll('.tab-btn');
    for (var i = 0; i < btns.length; i++) {
        if (btns[i].dataset.tab === activeTab) btns[i].classList.add('active');
        else btns[i].classList.remove('active');
    }
}

// ── Render ──

function render() {
    if (isImpound) renderImpound();
    else if (activeTab === 'personal') renderPersonal();
    else renderSociety();
}

function renderPersonal() {
    var list = document.getElementById('vehicle-list');
    var empty = document.getElementById('empty-state');
    var count = document.getElementById('vehicle-count');
    var totalItems = vehicles.length + outVehicles.length + elsewhereVehicles.length + impoundedVehicles.length;

    if (totalItems === 0) {
        list.classList.add('hidden'); list.innerHTML = '';
        empty.classList.remove('hidden');
        count.textContent = '0 vehicles';
        return;
    }

    list.classList.remove('hidden');
    empty.classList.add('hidden');
    var html = '';

    // IN GARAGE
    for (var i = 0; i < vehicles.length; i++) {
        var v = vehicles[i];
        var isActive = (i === activeIndex);
        var isRetrieving = (retrievingPlate === v.plate);
        var displayName = v.nickname || v.name || 'Unknown';

        var btnLabel = isRetrieving ? '<i class="fas fa-spinner fa-spin"></i> Retrieving...' : '<i class="fas fa-right-from-bracket"></i> Take Out';
        var disabled = isRetrieving ? ' disabled' : '';

        html += '<div class="vehicle-card ' + (isActive ? 'active' : '') + '" onclick="toggleCard(' + i + ')">' +
            '<div class="card-header">' +
                '<span class="card-name">' + escapeHtml(displayName) + '</span>' +
                '<span class="location-tag tag-here"><i class="fas fa-location-dot"></i> In Garage</span>' +
                '<i class="fas fa-chevron-down card-chevron"></i>' +
            '</div>' +
            '<div class="card-body"><div class="card-content">' +
                '<div class="card-rename">' +
                    '<label><i class="fas fa-pen"></i></label>' +
                    '<input class="rename-input" type="text" value="' + escapeAttr(displayName) + '" onclick="event.stopPropagation()" onkeydown="if(event.key===\'Enter\'){renameVehicle(\'' + escapeAttr(v.plate) + '\',this.value);this.blur()}" placeholder="Vehicle nickname">' +
                    '<button class="rename-btn" onclick="event.stopPropagation();renameVehicle(\'' + escapeAttr(v.plate) + '\',this.previousElementSibling.value)"><i class="fas fa-check"></i></button>' +
                '</div>' +
                renderStatBars(v) +
                '<div class="card-plate"><span class="plate-badge"><span class="plate-month">MAY</span>' + escapeHtml(v.plate || '???') + '</span></div>' +
                '<div class="card-actions"><button class="btn-spawn"' + disabled + ' onclick="event.stopPropagation();takeOut(\'' + escapeAttr(v.plate) + '\')">' + btnLabel + '</button></div>' +
            '</div></div>' +
        '</div>';
    }

    // ON ROAD
    for (var o = 0; o < outVehicles.length; o++) {
        var ov = outVehicles[o];
        var oIdx = vehicles.length + o;
        var oActive = (oIdx === activeIndex);

        html += '<div class="vehicle-card out-garage ' + (oActive ? 'active' : '') + '" onclick="toggleOut(' + o + ')">' +
            '<div class="card-header">' +
                '<span class="card-name">' + escapeHtml(ov.name || 'Unknown') + '</span>' +
                '<span class="location-tag tag-out"><i class="fas fa-road"></i> On Road</span>' +
                '<i class="fas fa-chevron-down card-chevron"></i>' +
            '</div>' +
            '<div class="card-body"><div class="card-content">' +
                renderStatBars(ov) +
                '<div class="card-plate"><span class="plate-badge"><span class="plate-month">MAY</span>' + escapeHtml(ov.plate || '???') + '</span></div>' +
                '<div class="card-actions"><button class="btn-locate" onclick="event.stopPropagation();locateVehicle(\'' + escapeAttr(ov.plate) + '\')"><i class="fas fa-location-dot"></i> Locate on GPS</button></div>' +
            '</div></div>' +
        '</div>';
    }

    // ELSEWHERE
    for (var j = 0; j < elsewhereVehicles.length; j++) {
        var ev = elsewhereVehicles[j];
        var eIdx = vehicles.length + outVehicles.length + j;
        var eActive = (eIdx === activeIndex);
        var showDropdown = (transferDropdownPlate === ev.plate);

        var dropdownHtml = '';
        if (showDropdown && garageList.length > 0) {
            dropdownHtml = '<div class="transfer-dropdown" onclick="event.stopPropagation()">';
            for (var g = 0; g < garageList.length; g++) {
                dropdownHtml += '<div class="transfer-dropdown-item" onclick="event.stopPropagation();transferToGarage(\'' + escapeAttr(ev.plate) + '\',\'' + escapeAttr(garageList[g]) + '\')">' +
                    '<i class="fas fa-warehouse"></i> ' + escapeHtml(garageList[g]) +
                '</div>';
            }
            dropdownHtml += '</div>';
        }

        html += '<div class="vehicle-card elsewhere-card ' + (eActive ? 'active' : '') + '" onclick="toggleElsewhere(' + j + ')">' +
            '<div class="card-header">' +
                '<span class="card-name">' + escapeHtml(ev.name || 'Unknown') + '</span>' +
                '<span class="location-tag tag-elsewhere"><i class="fas fa-warehouse"></i> ' + escapeHtml(ev.atGarage) + '</span>' +
                '<i class="fas fa-chevron-down card-chevron"></i>' +
            '</div>' +
            '<div class="card-body"><div class="card-content">' +
                '<div class="card-plate"><span class="plate-badge"><span class="plate-month">MAY</span>' + escapeHtml(ev.plate || '???') + '</span></div>' +
                '<div class="card-actions">' +
                    '<button class="btn-transfer" onclick="event.stopPropagation();transferVehicle(\'' + escapeAttr(ev.plate) + '\')"><i class="fas fa-truck-arrow-right"></i> Transfer Here</button>' +
                    '<button class="btn-transfer-to" onclick="event.stopPropagation();toggleTransferDropdown(\'' + escapeAttr(ev.plate) + '\')"><i class="fas fa-list"></i> Transfer to...</button>' +
                '</div>' +
                dropdownHtml +
            '</div></div>' +
        '</div>';
    }

    // IMPOUNDED
    for (var k = 0; k < impoundedVehicles.length; k++) {
        var iv = impoundedVehicles[k];
        var iIdx = vehicles.length + outVehicles.length + elsewhereVehicles.length + k;
        var iActive = (iIdx === activeIndex);

        html += '<div class="vehicle-card impound-card ' + (iActive ? 'active' : '') + '" onclick="toggleImpounded(' + k + ')">' +
            '<div class="card-header">' +
                '<span class="card-name">' + escapeHtml(iv.name || 'Unknown') + '</span>' +
                '<span class="location-tag tag-impound"><i class="fas fa-car-burst"></i> Impounded</span>' +
                '<i class="fas fa-chevron-down card-chevron"></i>' +
            '</div>' +
            '<div class="card-body"><div class="card-content">' +
                '<div class="card-plate"><span class="plate-badge"><span class="plate-month">MAY</span>' + escapeHtml(iv.plate || '???') + '</span></div>' +
                '<div class="card-actions"><button class="btn-impound-info" disabled><i class="fas fa-circle-info"></i> Retrieve at Impound Lot</button></div>' +
            '</div></div>' +
        '</div>';
    }

    list.innerHTML = html;
    count.textContent = totalItems + ' vehicle' + (totalItems !== 1 ? 's' : '');
}

function renderImpound() {
    var list = document.getElementById('vehicle-list');
    var empty = document.getElementById('empty-state');
    var count = document.getElementById('vehicle-count');

    count.textContent = vehicles.length + ' impounded';

    if (!vehicles || vehicles.length === 0) {
        list.classList.add('hidden'); list.innerHTML = '';
        empty.classList.remove('hidden');
        return;
    }

    list.classList.remove('hidden');
    empty.classList.add('hidden');
    var html = '';

    for (var i = 0; i < vehicles.length; i++) {
        var v = vehicles[i];
        var isActive = (i === activeIndex);
        var isRetrieving = (retrievingPlate === v.plate);
        var btnLabel = isRetrieving ? '<i class="fas fa-spinner fa-spin"></i> Retrieving...' : '<i class="fas fa-right-from-bracket"></i> Retrieve — $' + impoundFee;
        var disabled = isRetrieving ? ' disabled' : '';

        html += '<div class="vehicle-card ' + (isActive ? 'active' : '') + '" onclick="toggleImpoundCard(' + i + ')">' +
            '<div class="card-header">' +
                '<span class="card-name">' + escapeHtml(v.name || 'Unknown') + '</span>' +
                '<span class="location-tag tag-impound"><i class="fas fa-car-burst"></i> Impounded</span>' +
                '<i class="fas fa-chevron-down card-chevron"></i>' +
            '</div>' +
            '<div class="card-body"><div class="card-content">' +
                renderStatBars(v) +
                '<div class="card-plate"><span class="plate-badge"><span class="plate-month">MAY</span>' + escapeHtml(v.plate || '???') + '</span></div>' +
                '<div class="card-actions"><button class="btn-impound-retrieve"' + disabled + ' onclick="event.stopPropagation();retrieveImpound(\'' + escapeAttr(v.plate) + '\')">' + btnLabel + '</button></div>' +
            '</div></div>' +
        '</div>';
    }

    list.innerHTML = html;
}

function renderStatBars(v) {
    return '<div class="stat-row"><i class="fas fa-gas-pump stat-icon fuel"></i><div class="stat-bar-bg"><div class="stat-bar fuel" style="width:' + Math.round(v.fuel || 0) + '%"></div></div><span class="stat-value">' + Math.round(v.fuel || 0) + '</span></div>' +
        '<div class="stat-row"><i class="fas fa-gears stat-icon engine"></i><div class="stat-bar-bg"><div class="stat-bar engine" style="width:' + Math.round(v.engine || 100) + '%"></div></div><span class="stat-value">' + Math.round(v.engine || 100) + '</span></div>' +
        '<div class="stat-row"><i class="fas fa-car-burst stat-icon body"></i><div class="stat-bar-bg"><div class="stat-bar body" style="width:' + Math.round(v.body || 100) + '%"></div></div><span class="stat-value">' + Math.round(v.body || 100) + '</span></div>' +
        '<div class="stat-row"><i class="fas fa-oil-can stat-icon oil"></i><div class="stat-bar-bg"><div class="stat-bar oil" style="width:' + Math.round(v.oil || 100) + '%"></div></div><span class="stat-value">' + Math.round(v.oil || 100) + '</span></div>';
}

function renderSociety() {
    var list = document.getElementById('vehicle-list');
    var empty = document.getElementById('empty-state');
    var count = document.getElementById('vehicle-count');

    count.textContent = societyVehicles.length + ' society vehicle' + (societyVehicles.length !== 1 ? 's' : '');

    if (!societyVehicles || societyVehicles.length === 0) {
        list.classList.add('hidden'); list.innerHTML = '';
        empty.classList.remove('hidden');
        return;
    }

    list.classList.remove('hidden');
    empty.classList.add('hidden');
    var html = '';

    for (var i = 0; i < societyVehicles.length; i++) {
        var v = societyVehicles[i];
        var isActive = (i === activeIndex);
        var isRetrieving = (retrievingPlate === v.model);
        var actions = '';
        var statusTag = '<span class="society-badge"><i class="fas fa-briefcase"></i> Society</span>';

        if (v.checkedOut) {
            statusTag = '<span class="location-tag tag-out"><i class="fas fa-road"></i> Checked Out</span>';
            actions = '<button class="btn-spawn" disabled><i class="fas fa-ban"></i> Already Out</button>';
        } else {
            var btnLabel = isRetrieving ? '<i class="fas fa-spinner fa-spin"></i> Spawning...' : '<i class="fas fa-right-from-bracket"></i> Deploy';
            var disabled = isRetrieving ? ' disabled' : '';
            actions = '<button class="btn-spawn"' + disabled + ' onclick="event.stopPropagation();takeOutSociety(\'' + escapeAttr(v.model) + '\')">' + btnLabel + '</button>';
        }

        html += '<div class="vehicle-card ' + (isActive ? 'active' : '') + '" onclick="toggleSocietyCard(' + i + ')">' +
            '<div class="card-header">' +
                '<span class="card-name">' + escapeHtml(v.label || v.model) + '</span>' +
                statusTag +
                '<i class="fas fa-chevron-down card-chevron"></i>' +
            '</div>' +
            '<div class="card-body"><div class="card-content">' +
                '<div style="display:flex;justify-content:center;margin-bottom:10px;"><span class="plate-badge">' + escapeHtml(v.plate || v.model) + '</span></div>' +
                '<div class="card-actions">' + actions + '</div>' +
            '</div></div>' +
        '</div>';
    }

    list.innerHTML = html;
}

// ── Card Toggles ──

function toggleCard(index) {
    activeIndex = (activeIndex === index) ? null : index;
    transferDropdownPlate = null;
    render();
    if (activeIndex !== null && vehicles[activeIndex] && vehicles[activeIndex].stored) {
        fetch('https://prologue_garage/selectCard', { method: 'POST', body: JSON.stringify({ plate: vehicles[activeIndex].plate, society: false }) });
    }
}

function toggleOut(outIdx) {
    var realIdx = vehicles.length + outIdx;
    activeIndex = (activeIndex === realIdx) ? null : realIdx;
    transferDropdownPlate = null;
    render();
}

function toggleElsewhere(elseIdx) {
    var realIdx = vehicles.length + outVehicles.length + elseIdx;
    activeIndex = (activeIndex === realIdx) ? null : realIdx;
    transferDropdownPlate = null;
    render();
}

function toggleImpounded(impIdx) {
    var realIdx = vehicles.length + outVehicles.length + elsewhereVehicles.length + impIdx;
    activeIndex = (activeIndex === realIdx) ? null : realIdx;
    transferDropdownPlate = null;
    render();
}

function toggleImpoundCard(index) {
    activeIndex = (activeIndex === index) ? null : index;
    render();
    if (activeIndex !== null && vehicles[activeIndex]) {
        fetch('https://prologue_garage/impoundPreview', { method: 'POST', body: JSON.stringify({ plate: vehicles[activeIndex].plate }) });
    }
}

function toggleSocietyCard(index) {
    activeIndex = (activeIndex === index) ? null : index;
    render();
    if (activeIndex !== null && societyVehicles[activeIndex]) {
        fetch('https://prologue_garage/selectCard', { method: 'POST', body: JSON.stringify({ plate: societyVehicles[activeIndex].model, society: true }) });
    }
}

// ── Transfer Dropdown ──

function toggleTransferDropdown(plate) {
    transferDropdownPlate = (transferDropdownPlate === plate) ? null : plate;
    render();
}

function transferToGarage(plate, garageName) {
    transferDropdownPlate = null;
    var btns = document.querySelectorAll('.btn-transfer, .btn-transfer-to');
    btns.forEach(function(b) { b.disabled = true; });

    fetch('https://prologue_garage/transferToGarage', {
        method: 'POST',
        body: JSON.stringify({ plate: plate, garage: garageName })
    });
}

// ── Actions ──

function takeOut(plate) {
    if (retrievingPlate) return;
    retrievingPlate = plate;
    render();
    fetch('https://prologue_garage/takeOut', { method: 'POST', body: JSON.stringify({ plate: plate }) })
    .then(function(r) { return r.json(); })
    .then(function(resp) { if (!resp || !resp.success) { retrievingPlate = null; render(); } })
    .catch(function() { retrievingPlate = null; render(); });
}

function takeOutSociety(model) {
    if (retrievingPlate) return;
    retrievingPlate = model;
    render();
    fetch('https://prologue_garage/takeOutSociety', { method: 'POST', body: JSON.stringify({ model: model }) })
    .then(function(r) { return r.json(); })
    .then(function(resp) { if (!resp || !resp.success) { retrievingPlate = null; render(); } })
    .catch(function() { retrievingPlate = null; render(); });
}

function retrieveImpound(plate) {
    if (retrievingPlate) return;
    retrievingPlate = plate;
    render();
    fetch('https://prologue_garage/retrieveImpound', { method: 'POST', body: JSON.stringify({ plate: plate }) })
    .then(function(r) { return r.json(); })
    .then(function(resp) { if (!resp || !resp.success) { retrievingPlate = null; render(); } })
    .catch(function() { retrievingPlate = null; render(); });
}

function locateVehicle(plate) {
    fetch('https://prologue_garage/locate', { method: 'POST', body: JSON.stringify({ plate: plate }) });
}

function transferVehicle(plate) {
    var btns = document.querySelectorAll('.btn-transfer');
    btns.forEach(function(b) { b.disabled = true; });
    fetch('https://prologue_garage/transfer', { method: 'POST', body: JSON.stringify({ plate: plate }) });
}

function renameVehicle(plate, newName) {
    if (!newName || !newName.trim()) return;
    newName = newName.trim();
    for (var i = 0; i < vehicles.length; i++) {
        if (vehicles[i].plate === plate) { vehicles[i].nickname = newName; break; }
    }
    render();
    fetch('https://prologue_garage/rename', { method: 'POST', body: JSON.stringify({ plate: plate, name: newName }) });
}

// ── Close ──

function closeMenu() {
    if (isImpound) fetch('https://prologue_garage/closeImpound', { method: 'POST', body: '{}' });
    else fetch('https://prologue_garage/close', { method: 'POST', body: '{}' });
}

// ── Search ──

function filterVehicles() {
    var q = document.getElementById('search-input').value.toLowerCase();
    var cards = document.querySelectorAll('.vehicle-card');
    for (var i = 0; i < cards.length; i++) {
        var name = (cards[i].querySelector('.card-name') || {}).textContent || '';
        var plate = (cards[i].querySelector('.plate-badge') || {}).textContent || '';
        cards[i].style.display = (name.toLowerCase().indexOf(q) !== -1 || plate.toLowerCase().indexOf(q) !== -1) ? '' : 'none';
    }
}

// ── ESC ──

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') closeMenu();
});

// ── Util ──

function escapeHtml(str) { var d = document.createElement('div'); d.textContent = str; return d.innerHTML; }
function escapeAttr(str) { return str.replace(/'/g, "\\'").replace(/"/g, '&quot;'); }
