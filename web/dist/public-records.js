(function () {
    'use strict';

    function $(id) { return document.getElementById(id); }
    function post(name, payload) {
        return fetch('https://' + GetParentResourceName() + '/' + name, {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload || {})
        }).then(function (r) { return r.json().catch(function () { return {}; }); });
    }

    function renderRows(rows) {
        if (!rows.length) {
            return '<p style="color:#8fb8b3">No public medical records found.</p>';
        }
        return rows.map(function (row) {
            return '<article class="stat-card" style="margin-bottom:10px">' +
                '<div class="form-row" style="justify-content:space-between;margin:0 0 6px">' +
                    '<strong>' + (row.visit_type || 'Visit') + '</strong>' +
                    '<small class="mono">' + (row.created_at || '') + '</small>' +
                '</div>' +
                '<p style="margin:0 0 6px;color:#ecfdf9">' + (row.summary || '') + '</p>' +
                '<small style="color:#8fb8b3">' + (row.provider_name || 'EMS') + ' · ' + (row.facility || 'Pillbox Hospital') + '</small>' +
            '</article>';
        }).join('');
    }

    window.addEventListener('message', function (event) {
        var msg = event.data || {};
        var panel = $('ems-public-records');
        if (msg.action === 'publicRecords:open') {
            var data = msg.data || {};
            if ($('pr-title')) $('pr-title').textContent = data.title || 'Public Medical Records';
            if ($('pr-subtitle')) $('pr-subtitle').textContent = data.subtitle || 'Pillbox Hospital';
            if ($('pr-results')) $('pr-results').innerHTML = renderRows(data.rows || []);
            if (panel) panel.hidden = false;
        } else if (msg.action === 'publicRecords:close' || msg.action === 'ui:reset') {
            if (panel) panel.hidden = true;
        }
    });

    var closeBtn = document.querySelectorAll('[data-action="pr-close"]');
    closeBtn.forEach(function (el) {
        el.addEventListener('click', function () { post('publicRecordsClose'); });
    });
})();
