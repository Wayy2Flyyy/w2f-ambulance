(function () {
    'use strict';

    var state = {
        data: null,
        tab: 'overview',
        roster: { filter: 'all' },
        patients: { query: '', results: [], selectedCid: null, file: null },
        logs: { logType: '', rows: [], loading: false },
    };

    function $(id) { return document.getElementById(id); }

    function post(name, payload) {
        return fetch('https://' + GetParentResourceName() + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload || {})
        }).then(function (r) { return r.json().catch(function () { return {}; }); });
    }

    function esc(text) {
        return String(text == null ? '' : text)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function badge(text, type) {
        return '<span class="tb-badge tb-badge--' + (type || 'muted') + '">' + esc(text) + '</span>';
    }

    function fmtDate(dt) {
        if (!dt) return '—';
        var d = String(dt);
        var m = d.match(/(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})/);
        if (m) return m[3] + '/' + m[2] + ' ' + m[4] + ':' + m[5];
        return d.slice(0, 16);
    }

    var visitOptions = [
        ['manual', 'Medical Visit'],
        ['checkup', 'Medical Assessment'],
        ['treatment', 'Wound Treatment'],
        ['revive', 'Emergency Revive'],
        ['prescription', 'Prescription Issued'],
        ['hospital', 'Hospital Care'],
        ['stabilization', 'Trauma Stabilization']
    ];

    var TABS = [
        { id: 'overview',  label: 'Overview'    },
        { id: 'roster',    label: 'Staff Roster' },
        { id: 'patients',  label: 'Patients'     },
        { id: 'logs',      label: 'Audit Logs'   },
        { id: 'bulletins', label: 'Bulletins'    },
    ];

    var LOG_TYPES = {
        '':             'All Types',
        'personnel':    'Personnel',
        'patient':      'Patient',
        'access':       'Access',
        'announcement': 'Announcement',
    };

    var ACTION_BADGE = {
        hire: 'success', fire: 'danger', grade_change: 'warning',
        clinical_note: 'info', public_record: 'info',
        tablet_open: 'muted', tablet_close: 'muted',
        post: 'accent',
    };

    var LOG_TYPE_BADGE = {
        personnel: 'warning', patient: 'info', access: 'muted', announcement: 'accent',
    };

    // ── Tabs ──────────────────────────────────────────────────────────────────

    function renderTabs() {
        var nav = $('tb-tabs');
        if (!nav) return;
        nav.innerHTML = '';
        TABS.forEach(function (t) {
            var btn = document.createElement('button');
            btn.className = 'tb-tab' + (state.tab === t.id ? ' is-active' : '');
            btn.textContent = t.label;
            btn.onclick = function () { switchTab(t.id); };
            nav.appendChild(btn);
        });
    }

    function switchTab(id) {
        state.tab = id;
        render();
    }

    // ── Overview ──────────────────────────────────────────────────────────────

    function kpi(label, value, sub, type) {
        return '<div class="kpi-card kpi--' + (type || 'muted') + '">' +
            '<span class="kpi-label">' + esc(label) + '</span>' +
            '<strong class="kpi-value">' + esc(String(value)) + '</strong>' +
            '<span class="kpi-sub">' + esc(sub || '') + '</span>' +
        '</div>';
    }

    function renderOverview() {
        var stats = state.data.stats || {};
        var recentLogs = state.data.recentLogs || [];
        var onDutyPct = stats.roster > 0 ? Math.round(stats.onDuty / stats.roster * 100) : 0;

        var recentRows = recentLogs.map(function (r) {
            return '<tr>' +
                '<td class="mono">' + fmtDate(r.created_at) + '</td>' +
                '<td>' + badge(r.log_type || '', LOG_TYPE_BADGE[r.log_type] || 'muted') + '</td>' +
                '<td>' + badge(r.action || '', ACTION_BADGE[r.action] || 'muted') + '</td>' +
                '<td>' + esc(r.actor_name || '—') + '</td>' +
                '<td>' + esc(r.target_name || '—') + '</td>' +
                '<td class="tb-trunc">' + esc(r.message || '') + '</td>' +
            '</tr>';
        }).join('');

        return '' +
            '<div class="kpi-row">' +
                kpi('On Duty', stats.onDuty || 0, onDutyPct + '% of roster', 'success') +
                kpi('Total Roster', stats.roster || 0, 'all personnel', 'accent') +
                kpi('Bulletins', stats.announcements || 0, 'posted', 'muted') +
                kpi('Log Events', stats.logCount || 0, 'today', 'muted') +
            '</div>' +
            '<div class="ov-actions">' +
                '<button class="ov-btn" id="ov-goto-roster">Staff Roster</button>' +
                '<button class="ov-btn" id="ov-goto-patients">Patient Search</button>' +
                '<button class="ov-btn" id="ov-goto-logs">Audit Logs</button>' +
                '<button class="ov-btn" id="ov-goto-bulletins">Bulletins</button>' +
            '</div>' +
            '<div class="tb-panel">' +
                '<div class="tb-panel-head"><span class="tb-panel-title">Recent Activity</span></div>' +
                '<div class="table-wrap">' +
                '<table>' +
                    '<thead><tr><th>Time</th><th>Type</th><th>Action</th><th>Actor</th><th>Target</th><th>Message</th></tr></thead>' +
                    '<tbody>' + (recentRows || '<tr><td colspan="6" class="tb-empty-row">No recent activity.</td></tr>') + '</tbody>' +
                '</table>' +
                '</div>' +
            '</div>';
    }

    function bindOverviewEvents() {
        var map = {
            'ov-goto-roster':   function () { switchTab('roster'); },
            'ov-goto-patients': function () { switchTab('patients'); },
            'ov-goto-logs':     function () { switchTab('logs'); loadLogs(); },
            'ov-goto-bulletins': function () { switchTab('bulletins'); },
        };
        Object.keys(map).forEach(function (id) {
            var el = $(id);
            if (el) el.onclick = map[id];
        });
    }

    // ── Roster ────────────────────────────────────────────────────────────────

    function renderRoster() {
        var rows = state.data.personnel || [];
        var ranks = state.data.ranks || [];
        var filter = state.roster.filter;

        var filtered = rows.filter(function (r) {
            if (filter === 'online')  return r.online;
            if (filter === 'offline') return !r.online;
            if (filter === 'duty')    return r.onduty;
            if (filter === 'offduty') return !r.onduty;
            return true;
        });

        var onlineCount = rows.filter(function (r) { return r.online; }).length;
        var onDutyCount = rows.filter(function (r) { return r.onduty; }).length;

        var rankOptions = ranks.map(function (r) {
            return '<option value="' + r.grade + '">' + esc(r.label) + '</option>';
        }).join('');

        var FILTERS = [
            ['all', 'All'], ['online', 'Online'], ['offline', 'Offline'],
            ['duty', 'On Duty'], ['offduty', 'Off Duty'],
        ];
        var filterBtns = FILTERS.map(function (f) {
            return '<button class="tb-filter-btn' + (filter === f[0] ? ' is-active' : '') +
                '" data-filter="' + f[0] + '">' + f[1] + '</button>';
        }).join('');

        var tableRows = filtered.map(function (row) {
            var dutyBadge   = row.onduty ? badge('On Duty', 'success') : badge('Off Duty', 'muted');
            var onlineBadge = row.online ? badge('Online', 'accent')   : badge('Offline', 'muted');
            return '<tr>' +
                '<td>' +
                    '<span class="tb-name">' + esc(row.name) + '</span>' +
                    '<span class="tb-sub mono">' + esc(row.citizenid) + '</span>' +
                '</td>' +
                '<td>' + badge(row.rankLabel, 'accent') + '</td>' +
                '<td>' + dutyBadge + '</td>' +
                '<td>' + onlineBadge + '</td>' +
                '<td class="tb-actions-cell">' +
                    '<select class="tb-select tb-grade" data-cid="' + esc(row.citizenid) + '">' + rankOptions + '</select>' +
                    '<button class="tb-btn tb-set-grade" data-cid="' + esc(row.citizenid) + '">Set</button>' +
                    '<button class="tb-btn tb-btn--danger tb-fire" data-cid="' + esc(row.citizenid) + '" data-name="' + esc(row.name) + '">Remove</button>' +
                '</td>' +
            '</tr>';
        }).join('');

        return '' +
            '<div class="tb-panel">' +
                '<div class="tb-panel-head"><span class="tb-panel-title">Hire Personnel</span></div>' +
                '<div class="tb-panel-body">' +
                    '<div class="tb-row">' +
                        '<input id="tb-hire-query" class="tb-input" placeholder="Search citizen by name or citizen ID" />' +
                        '<button class="tb-btn" id="tb-hire-search">Search</button>' +
                        '<select id="tb-hire-grade" class="tb-select">' + rankOptions + '</select>' +
                        '<button class="tb-btn tb-btn--primary" id="tb-hire-btn">Hire</button>' +
                    '</div>' +
                    '<div id="tb-hire-results" class="tb-picker"></div>' +
                '</div>' +
            '</div>' +
            '<div class="tb-panel">' +
                '<div class="tb-panel-head">' +
                    '<span class="tb-panel-title">Active Roster</span>' +
                    '<span class="tb-panel-meta">' + onlineCount + ' online &middot; ' + onDutyCount + ' on duty</span>' +
                    '<div class="tb-filter-row">' + filterBtns + '</div>' +
                '</div>' +
                '<div class="table-wrap">' +
                '<table>' +
                    '<thead><tr><th>Name</th><th>Rank</th><th>Duty</th><th>Online</th><th>Actions</th></tr></thead>' +
                    '<tbody>' +
                    (tableRows || '<tr><td colspan="5" class="tb-empty-row">No personnel match this filter.</td></tr>') +
                    '</tbody>' +
                '</table>' +
                '</div>' +
            '</div>';
    }

    function bindRosterEvents() {
        var selectedHire = { citizenid: null, query: '' };

        var hireSearch = $('tb-hire-search');
        if (hireSearch) hireSearch.onclick = function () {
            var query = $('tb-hire-query').value;
            selectedHire.query = query;
            selectedHire.citizenid = null;
            post('tabletSearchCitizens', { query: query }).then(function (res) {
                renderPicker('tb-hire-results', res.rows || [], function (cid, name) {
                    $('tb-hire-query').value = name;
                    selectedHire.citizenid = cid;
                    selectedHire.query = name;
                });
            });
        };

        var hireQueryEl = $('tb-hire-query');
        if (hireQueryEl) hireQueryEl.oninput = function () { selectedHire.citizenid = null; };

        var hireBtn = $('tb-hire-btn');
        if (hireBtn) hireBtn.onclick = function () {
            post('tabletHire', {
                citizenid: selectedHire.citizenid || null,
                query: ($('tb-hire-query') && $('tb-hire-query').value) || selectedHire.query,
                grade: parseInt(($('tb-hire-grade') && $('tb-hire-grade').value) || '0', 10) || 0
            }).then(refresh);
        };

        document.querySelectorAll('.tb-grade').forEach(function (select) {
            var row = (state.data.personnel || []).find(function (p) { return p.citizenid === select.dataset.cid; });
            if (row) select.value = String(row.grade);
        });

        document.querySelectorAll('.tb-set-grade').forEach(function (btn) {
            btn.onclick = function () {
                var cid = btn.dataset.cid;
                var select = document.querySelector('.tb-grade[data-cid="' + cid + '"]');
                if (!select) return;
                post('tabletSetGrade', { citizenid: cid, grade: parseInt(select.value, 10) || 0 }).then(refresh);
            };
        });

        document.querySelectorAll('.tb-fire').forEach(function (btn) {
            btn.onclick = function () {
                post('tabletFire', { citizenid: btn.dataset.cid }).then(refresh);
            };
        });

        document.querySelectorAll('.tb-filter-btn').forEach(function (btn) {
            btn.onclick = function () {
                state.roster.filter = btn.dataset.filter;
                var content = $('tb-content');
                if (content) { content.innerHTML = renderRoster(); bindRosterEvents(); }
            };
        });
    }

    // ── Patients ──────────────────────────────────────────────────────────────

    function renderPatientList() {
        var rows = state.patients.results || [];
        if (!rows.length) {
            return '<tr><td colspan="5" class="tb-empty-row">No matching citizens found.</td></tr>';
        }
        return rows.map(function (row) {
            var sel = state.patients.selectedCid === row.citizenid ? ' is-selected' : '';
            return '<tr class="tb-patient-row' + sel + '" data-cid="' + esc(row.citizenid) + '">' +
                '<td><span class="tb-name">' + esc(row.name) + '</span></td>' +
                '<td class="mono">' + esc(row.citizenid) + '</td>' +
                '<td>' + esc(row.phone || '—') + '</td>' +
                '<td>' + (row.online ? badge('Online', 'accent') : badge('Offline', 'muted')) + '</td>' +
                '<td><button type="button" class="tb-btn tb-patient-open" data-cid="' + esc(row.citizenid) + '">Open</button></td>' +
            '</tr>';
        }).join('');
    }

    function renderClinicalTable(rows) {
        if (!rows || !rows.length) return '<p class="tb-empty">No clinical notes on file.</p>';
        var body = rows.map(function (r) {
            return '<tr><td>' + esc(r.author_name || r.author) + '</td><td>' + esc(r.notes) + '</td>' +
                '<td class="mono">' + fmtDate(r.created_at) + '</td></tr>';
        }).join('');
        return '<div class="table-wrap"><table><thead><tr><th>Author</th><th>Notes</th><th>Date</th></tr></thead><tbody>' + body + '</tbody></table></div>';
    }

    function renderPublicTable(rows) {
        if (!rows || !rows.length) return '<p class="tb-empty">No public registry entries.</p>';
        var body = rows.map(function (r) {
            return '<tr><td>' + badge(r.visit_type || '', 'info') + '</td><td>' + esc(r.summary || '') + '</td>' +
                '<td>' + esc(r.provider_name || '') + '</td><td class="mono">' + fmtDate(r.created_at) + '</td></tr>';
        }).join('');
        return '<div class="table-wrap"><table><thead><tr><th>Type</th><th>Summary</th><th>Provider</th><th>Date</th></tr></thead><tbody>' + body + '</tbody></table></div>';
    }

    function renderPatientFile() {
        var file = state.patients.file;
        if (!file || !file.profile) {
            return '<p class="tb-empty">Select a patient above to view their file.</p>';
        }
        var p = file.profile;
        var visitSelect = visitOptions.map(function (pair) {
            return '<option value="' + pair[0] + '">' + pair[1] + '</option>';
        }).join('');

        return '' +
            '<div class="pat-hdr">' +
                '<div>' +
                    '<span class="pat-name">' + esc(p.name) + '</span>' +
                    '<span class="pat-cid mono">' + esc(p.citizenid) + '</span>' +
                '</div>' +
                '<div class="pat-meta">' +
                    (p.online ? badge('Online', 'accent') : badge('Offline', 'muted')) +
                    (p.phone ? ' <span class="tb-sub">' + esc(p.phone) + '</span>' : '') +
                    (p.dob   ? ' <span class="tb-sub">DOB ' + esc(p.dob) + '</span>' : '') +
                '</div>' +
            '</div>' +
            '<div class="tb-panel">' +
                '<div class="tb-panel-head">' +
                    '<span class="tb-panel-title">Clinical Notes</span>' +
                    '<span class="tb-panel-meta">Internal — not visible to patient</span>' +
                '</div>' +
                '<div class="tb-panel-body">' +
                    renderClinicalTable(file.clinical || []) +
                    '<textarea id="tb-note-text" class="tb-textarea" rows="3" placeholder="Enter internal clinical note..."></textarea>' +
                    '<button class="tb-btn tb-btn--primary" id="tb-note-add">Save Note</button>' +
                '</div>' +
            '</div>' +
            '<div class="tb-panel">' +
                '<div class="tb-panel-head">' +
                    '<span class="tb-panel-title">Public Registry</span>' +
                    '<span class="tb-panel-meta">Visible to patient</span>' +
                '</div>' +
                '<div class="tb-panel-body">' +
                    renderPublicTable(file.public || []) +
                    '<div class="tb-row tb-row--tight">' +
                        '<select id="tb-pub-type" class="tb-select">' + visitSelect + '</select>' +
                    '</div>' +
                    '<textarea id="tb-pub-summary" class="tb-textarea" rows="3" placeholder="Public visit summary..."></textarea>' +
                    '<button class="tb-btn tb-btn--primary" id="tb-pub-publish">Publish Entry</button>' +
                '</div>' +
            '</div>';
    }

    function renderPatients() {
        return '' +
            '<div class="tb-panel">' +
                '<div class="tb-panel-head"><span class="tb-panel-title">Citizen Search</span></div>' +
                '<div class="tb-panel-body">' +
                    '<div class="tb-row">' +
                        '<input id="tb-pat-query" class="tb-input" placeholder="Name, citizen ID, or phone" value="' + esc(state.patients.query) + '" />' +
                        '<button class="tb-btn" id="tb-pat-search">Search</button>' +
                    '</div>' +
                    '<div class="table-wrap" id="tb-pat-results">' +
                        '<table><thead><tr><th>Name</th><th>Citizen ID</th><th>Phone</th><th>Status</th><th></th></tr></thead>' +
                        '<tbody>' + renderPatientList() + '</tbody></table>' +
                    '</div>' +
                '</div>' +
            '</div>' +
            '<div class="tb-panel">' +
                '<div class="tb-panel-head"><span class="tb-panel-title">Patient File</span></div>' +
                '<div class="tb-panel-body" id="tb-pat-file">' + renderPatientFile() + '</div>' +
            '</div>';
    }

    function bindPatientListEvents() {
        document.querySelectorAll('.tb-patient-open').forEach(function (btn) {
            btn.onclick = function () { openPatientFile(btn.dataset.cid); };
        });
        document.querySelectorAll('.tb-patient-row').forEach(function (row) {
            row.onclick = function (evt) {
                if (evt.target.closest('.tb-patient-open')) return;
                openPatientFile(row.dataset.cid);
            };
        });
    }

    function bindPatientFileEvents() {
        var noteAdd = $('tb-note-add');
        if (noteAdd) noteAdd.onclick = function () {
            var cid = state.patients.selectedCid;
            var txt = $('tb-note-text');
            if (!txt || !txt.value.trim()) return;
            post('tabletAddClinicalNote', { citizenid: cid, notes: txt.value }).then(function (res) {
                if (res && res.ok) { txt.value = ''; openPatientFile(cid); }
            });
        };

        var pubPublish = $('tb-pub-publish');
        if (pubPublish) pubPublish.onclick = function () {
            var cid = state.patients.selectedCid;
            var sumEl = $('tb-pub-summary');
            if (!sumEl || !sumEl.value.trim()) return;
            post('tabletPublishPublicRecord', {
                citizenid: cid,
                visitType: $('tb-pub-type') && $('tb-pub-type').value,
                summary: sumEl.value
            }).then(function (res) {
                if (res && res.ok) { sumEl.value = ''; openPatientFile(cid); }
            });
        };
    }

    function searchPatients(query) {
        state.patients.query = query || '';
        return post('tabletSearchCitizens', { query: state.patients.query }).then(function (res) {
            state.patients.results = (res && res.rows) || [];
            var tbody = document.querySelector('#tb-pat-results tbody');
            if (tbody) { tbody.innerHTML = renderPatientList(); bindPatientListEvents(); }
        });
    }

    function openPatientFile(citizenid) {
        if (!citizenid) return Promise.resolve();
        state.patients.selectedCid = citizenid;
        return post('tabletGetPatientFile', { citizenid: citizenid }).then(function (res) {
            state.patients.file = (res && res.ok && res.file) ? res.file : null;
            var fileEl = $('tb-pat-file');
            if (fileEl) { fileEl.innerHTML = renderPatientFile(); bindPatientFileEvents(); }
            var tbody = document.querySelector('#tb-pat-results tbody');
            if (tbody) { tbody.innerHTML = renderPatientList(); bindPatientListEvents(); }
        });
    }

    // ── Logs ──────────────────────────────────────────────────────────────────

    function renderLogs() {
        var rows    = state.logs.rows || [];
        var logType = state.logs.logType;
        var loading = state.logs.loading;

        var filterBtns = Object.keys(LOG_TYPES).map(function (k) {
            return '<button class="tb-filter-btn' + (logType === k ? ' is-active' : '') +
                '" data-logtype="' + k + '">' + LOG_TYPES[k] + '</button>';
        }).join('');

        var tableRows;
        if (loading) {
            tableRows = '<tr><td colspan="6" class="tb-empty-row">Loading&hellip;</td></tr>';
        } else if (!rows.length) {
            tableRows = '<tr><td colspan="6" class="tb-empty-row">No log entries found.</td></tr>';
        } else {
            tableRows = rows.map(function (r) {
                return '<tr>' +
                    '<td class="mono">' + fmtDate(r.created_at) + '</td>' +
                    '<td>' + badge(r.log_type || '', LOG_TYPE_BADGE[r.log_type] || 'muted') + '</td>' +
                    '<td>' + badge(r.action || '', ACTION_BADGE[r.action] || 'muted') + '</td>' +
                    '<td>' + esc(r.actor_name || '—') + '</td>' +
                    '<td>' + esc(r.target_name || '—') + '</td>' +
                    '<td class="tb-trunc">' + esc(r.message || '') + '</td>' +
                '</tr>';
            }).join('');
        }

        return '' +
            '<div class="tb-panel">' +
                '<div class="tb-panel-head">' +
                    '<span class="tb-panel-title">Audit Log</span>' +
                    '<div class="tb-filter-row">' + filterBtns + '</div>' +
                    '<button class="tb-btn" id="tb-logs-reload">Reload</button>' +
                '</div>' +
                '<div class="table-wrap">' +
                '<table>' +
                    '<thead><tr><th>Time</th><th>Type</th><th>Action</th><th>Actor</th><th>Target</th><th>Message</th></tr></thead>' +
                    '<tbody>' + tableRows + '</tbody>' +
                '</table>' +
                '</div>' +
            '</div>';
    }

    function loadLogs() {
        state.logs.loading = true;
        var content = $('tb-content');
        if (content && state.tab === 'logs') { content.innerHTML = renderLogs(); bindLogEvents(); }
        post('tabletGetLogs', { logType: state.logs.logType, limit: 100 }).then(function (res) {
            state.logs.rows    = (res && res.rows) || [];
            state.logs.loading = false;
            if (state.tab === 'logs') {
                var el = $('tb-content');
                if (el) { el.innerHTML = renderLogs(); bindLogEvents(); }
            }
        });
    }

    function bindLogEvents() {
        document.querySelectorAll('.tb-filter-btn[data-logtype]').forEach(function (btn) {
            btn.onclick = function () { state.logs.logType = btn.dataset.logtype; loadLogs(); };
        });
        var reload = $('tb-logs-reload');
        if (reload) reload.onclick = loadLogs;
    }

    // ── Bulletins ─────────────────────────────────────────────────────────────

    function renderBulletins() {
        var items = (state.data.announcements || []).map(function (a) {
            return '<tr>' +
                '<td>' + esc(a.author) + '</td>' +
                '<td>' + esc(a.message) + '</td>' +
                '<td class="mono">' + fmtDate(a.created_at || a.at) + '</td>' +
            '</tr>';
        }).join('');

        return '' +
            '<div class="tb-panel">' +
                '<div class="tb-panel-head"><span class="tb-panel-title">Post Bulletin</span></div>' +
                '<div class="tb-panel-body">' +
                    '<textarea id="tb-announce-text" class="tb-textarea" rows="4" placeholder="Broadcast to all EMS staff on duty..."></textarea>' +
                    '<button class="tb-btn tb-btn--primary" id="tb-announce-send">Publish Bulletin</button>' +
                '</div>' +
            '</div>' +
            '<div class="tb-panel">' +
                '<div class="tb-panel-head"><span class="tb-panel-title">Bulletin History</span></div>' +
                '<div class="table-wrap">' +
                '<table>' +
                    '<thead><tr><th>Author</th><th>Message</th><th>Posted</th></tr></thead>' +
                    '<tbody>' + (items || '<tr><td colspan="3" class="tb-empty-row">No bulletins posted yet.</td></tr>') + '</tbody>' +
                '</table>' +
                '</div>' +
            '</div>';
    }

    function bindBulletinEvents() {
        var send = $('tb-announce-send');
        if (send) send.onclick = function () {
            var txt = $('tb-announce-text');
            if (!txt || !txt.value.trim()) return;
            post('tabletAnnouncement', { message: txt.value }).then(function (res) {
                if (res && res.ok) { txt.value = ''; refresh(); }
            });
        };
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function renderPicker(containerId, rows, onPick) {
        var wrap = $(containerId);
        if (!wrap) return;
        if (!rows || !rows.length) {
            wrap.innerHTML = '<p class="tb-empty">No matching citizens found.</p>';
            return;
        }
        wrap.innerHTML = rows.map(function (row) {
            return '<button type="button" class="tb-pick" data-cid="' + esc(row.citizenid) + '" data-name="' + esc(row.name) + '">' +
                '<span>' + esc(row.name) + '</span>' +
                (row.online ? badge('Online', 'accent') : badge('Offline', 'muted')) +
            '</button>';
        }).join('');
        wrap.querySelectorAll('.tb-pick').forEach(function (btn) {
            btn.onclick = function () {
                onPick(btn.dataset.cid, btn.dataset.name);
                wrap.innerHTML = '<p class="tb-empty">Selected: <strong>' + esc(btn.dataset.name) + '</strong></p>';
            };
        });
    }

    function refresh() {
        return post('tabletRefresh').then(function (res) {
            if (res && res.data) { state.data = res.data; render(); }
        });
    }

    // ── Main render ───────────────────────────────────────────────────────────

    function render() {
        renderTabs();
        var content = $('tb-content');
        if (!content) return;

        if (state.tab === 'overview') {
            content.innerHTML = renderOverview();
            bindOverviewEvents();

        } else if (state.tab === 'roster') {
            content.innerHTML = renderRoster();
            bindRosterEvents();

        } else if (state.tab === 'patients') {
            content.innerHTML = renderPatients();
            bindPatientListEvents();
            bindPatientFileEvents();
            searchPatients(state.patients.query).then(function () {
                if (state.patients.selectedCid) openPatientFile(state.patients.selectedCid);
            });
            var patSearch = $('tb-pat-search');
            if (patSearch) patSearch.onclick = function () { searchPatients($('tb-pat-query').value); };
            var patQuery = $('tb-pat-query');
            if (patQuery) patQuery.onkeydown = function (e) { if (e.key === 'Enter') searchPatients(patQuery.value); };

        } else if (state.tab === 'logs') {
            content.innerHTML = renderLogs();
            bindLogEvents();
            loadLogs();

        } else if (state.tab === 'bulletins') {
            content.innerHTML = renderBulletins();
            bindBulletinEvents();
        }

        var officer = state.data.officer || {};
        var tbOfficer = $('tb-officer');
        var tbRank    = $('tb-rank');
        if (tbOfficer) tbOfficer.textContent = officer.name || '—';
        if (tbRank)    tbRank.textContent    = officer.rankLabel || '—';
    }

    // ── Message bridge ────────────────────────────────────────────────────────

    window.addEventListener('message', function (event) {
        var msg   = event.data || {};
        var panel = $('ems-tablet');
        if (msg.action === 'tablet:open') {
            state.data     = msg.data || {};
            state.tab      = 'overview';
            state.roster   = { filter: 'all' };
            state.patients = { query: '', results: [], selectedCid: null, file: null };
            state.logs     = { logType: '', rows: [], loading: false };
            if (panel) panel.hidden = false;
            render();
        } else if (msg.action === 'tablet:close' || msg.action === 'ui:reset') {
            if (panel) panel.hidden = true;
        }
    });

    var tbClose = document.querySelector('[data-action="tb-close"]');
    if (tbClose) tbClose.addEventListener('click', function () { post('tabletClose'); });
})();
