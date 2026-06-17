(function () {
    'use strict';

    var state = { catalog: null, category: 'all', query: '' };

    function $(id) { return document.getElementById(id); }
    function post(name, payload) {
        return fetch('https://' + GetParentResourceName() + '/' + name, {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload || {})
        }).then(function (r) { return r.json().catch(function () { return {}; }); });
    }

    function renderCategories() {
        var nav = $('eq-categories');
        if (!nav) return;
        nav.innerHTML = '';
        var allBtn = document.createElement('button');
        allBtn.className = 'eq-nav' + (state.category === 'all' ? ' is-active' : '');
        allBtn.textContent = 'All Supplies';
        allBtn.onclick = function () { state.category = 'all'; render(); };
        nav.appendChild(allBtn);
        (state.catalog.categories || []).forEach(function (cat) {
            var btn = document.createElement('button');
            btn.className = 'eq-nav' + (state.category === cat.id ? ' is-active' : '');
            btn.textContent = cat.label || cat.id;
            btn.onclick = function () { state.category = cat.id; render(); };
            nav.appendChild(btn);
        });
    }

    function filteredItems() {
        var q = state.query.trim().toLowerCase();
        return (state.catalog.items || []).filter(function (item) {
            if (state.category !== 'all' && item.category !== state.category) return false;
            if (!q) return true;
            return (item.label || '').toLowerCase().indexOf(q) !== -1;
        });
    }

    function renderGrid() {
        var grid = $('eq-grid');
        if (!grid) return;
        grid.innerHTML = '';
        filteredItems().forEach(function (item) {
            var card = document.createElement('article');
            card.className = 'eq-card' + (item.authorized ? '' : ' is-locked');
            card.innerHTML =
                '<img src="' + (item.image || '') + '" alt="" />' +
                '<h3>' + (item.label || item.item) + '</h3>' +
                '<p>' + (item.authorized ? 'Ready to issue' : ('Requires ' + (item.rankRequired || 'rank'))) + '</p>' +
                '<button class="ems-btn"' + (item.authorized ? '' : ' disabled') + '>Issue</button>';
            var btn = card.querySelector('button');
            btn.onclick = function () {
                post('equipmentTake', { id: item.id }).then(function (res) {
                    if (res && res.ok) card.style.borderColor = '#2dd4bf';
                });
            };
            grid.appendChild(card);
        });
    }

    function render() {
        renderCategories();
        renderGrid();
        if ($('eq-title')) $('eq-title').textContent = state.catalog.title || 'Medical Supply Locker';
        if ($('eq-subtitle')) $('eq-subtitle').textContent = state.catalog.subtitle || 'Pillbox Hospital';
        if ($('eq-rank')) $('eq-rank').textContent = (state.catalog.rankLabel || 'EMS') + ' · Grade ' + (state.catalog.grade || 0);
    }

    window.addEventListener('message', function (event) {
        var msg = event.data || {};
        var panel = $('ems-equipment');
        if (msg.action === 'equipment:open') {
            state.catalog = msg.data || {};
            state.category = 'all';
            state.query = '';
            if ($('eq-search')) $('eq-search').value = '';
            if (panel) panel.hidden = false;
            render();
        } else if (msg.action === 'equipment:close' || msg.action === 'ui:reset') {
            if (panel) panel.hidden = true;
        }
    });

    var eqClose = document.querySelectorAll('[data-action="eq-close"]');
    eqClose.forEach(function (el) {
        el.addEventListener('click', function () { post('equipmentClose'); });
    });
    var eqSearch = $('eq-search');
    if (eqSearch) eqSearch.addEventListener('input', function (ev) {
        state.query = ev.target.value || '';
        renderGrid();
    });
})();
