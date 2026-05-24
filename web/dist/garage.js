(function () {
    'use strict';

    var spawning = false;
    var state = { open: false, catalog: null };

    function $(id) { return document.getElementById(id); }

    function post(name, payload) {
        return fetch('https://' + GetParentResourceName() + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {})
        }).then(function (res) { return res.json().catch(function () { return {}; }); })
          .catch(function () { return { ok: false }; });
    }

    function previewVehicle(veh, card, btn) {
        if (spawning || !veh || !(veh.id || veh.model) || veh.authorized === false) return;
        spawning = true;
        if (btn) { btn.disabled = true; btn.textContent = 'Loading…'; }
        post('garagePreview', { id: veh.id || veh.model, model: veh.model }).then(function (res) {
            spawning = false;
            if (btn) { btn.disabled = false; btn.textContent = 'Spawn/Preview'; }
            if (res && res.ok) {
                closeCatalog();
            } else if (card) {
                card.classList.add('is-error');
                setTimeout(function () { card.classList.remove('is-error'); }, 650);
            }
        });
    }

    function render() {
        var grid = $('gr-grid');
        if (!grid || !state.catalog) return;
        grid.innerHTML = '';
        (state.catalog.vehicles || []).forEach(function (veh) {
            var locked = veh.authorized === false;
            var card = document.createElement('article');
            card.className = 'gr-card' + (locked ? ' is-locked' : '');
            card.innerHTML =
                '<h3>' + (veh.label || veh.model) + '</h3>' +
                '<p>' + (locked ? ('Locked · ' + (veh.rankRequired || 'rank')) : 'Authorized for deployment') + '</p>' +
                '<button class="ems-btn"' + (locked ? ' disabled' : '') + '>' +
                    (locked ? 'Locked' : 'Spawn/Preview') +
                '</button>';
            var btn = card.querySelector('button');
            if (!locked) {
                btn.onclick = function () { previewVehicle(veh, card, btn); };
            }
            grid.appendChild(card);
        });
        if ($('gr-title')) $('gr-title').textContent = state.catalog.title || 'EMS Fleet';
        if ($('gr-subtitle')) $('gr-subtitle').textContent = state.catalog.subtitle || 'Motor Pool';
        if ($('gr-rank')) $('gr-rank').textContent = (state.catalog.rankLabel || 'EMS') + ' · Grade ' + (state.catalog.grade || 0);
    }

    function openCatalog(catalog) {
        state.open = true;
        state.catalog = catalog || {};
        spawning = false;
        var panel = $('ems-garage');
        if (panel) panel.hidden = false;
        render();
    }

    function closeCatalog() {
        if (!state.open) return;
        state.open = false;
        state.catalog = null;
        spawning = false;
        var panel = $('ems-garage');
        if (panel) panel.hidden = true;
        post('garageClose', {});
    }

    window.addEventListener('message', function (event) {
        var msg = event.data || {};
        if (msg.action === 'garage:open') {
            openCatalog(msg.data || {});
        } else if (msg.action === 'garage:close' || msg.action === 'ui:reset') {
            state.open = false;
            state.catalog = null;
            var panel = $('ems-garage');
            if (panel) panel.hidden = true;
        }
    });

    document.addEventListener('keydown', function (ev) {
        if (!state.open) return;
        if (ev.key === 'Escape') {
            ev.preventDefault();
            closeCatalog();
        }
    }, true);

    var grClose = document.querySelectorAll('[data-action="gr-close"]');
    grClose.forEach(function (el) {
        el.addEventListener('click', function () { closeCatalog(); });
    });
})();
