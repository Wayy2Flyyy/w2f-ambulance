(function () {
    'use strict';

    var radialState = { menu: null, stack: [], depth: 0, visible: false };

    function post(name, payload) {
        if (typeof GetParentResourceName !== 'function') return Promise.resolve({});
        return fetch('https://' + GetParentResourceName() + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {})
        }).then(function (r) { return r.json().catch(function () { return {}; }); }).catch(function () { return {}; });
    }

    function $(id) { return document.getElementById(id); }

    function polarToCartesian(cx, cy, r, angle) {
        var rad = (angle - 90) * Math.PI / 180;
        return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) };
    }

    function describeSlice(cx, cy, r1, r2, startAngle, endAngle) {
        var start = polarToCartesian(cx, cy, r2, endAngle);
        var end = polarToCartesian(cx, cy, r2, startAngle);
        var innerStart = polarToCartesian(cx, cy, r1, endAngle);
        var innerEnd = polarToCartesian(cx, cy, r1, startAngle);
        var large = endAngle - startAngle <= 180 ? 0 : 1;
        return [
            'M', start.x, start.y,
            'A', r2, r2, 0, large, 0, end.x, end.y,
            'L', innerEnd.x, innerEnd.y,
            'A', r1, r1, 0, large, 1, innerStart.x, innerStart.y,
            'Z'
        ].join(' ');
    }

    function radialBack() {
        post('uiRadialBack');
    }

    function updateCenter(menu) {
        var center = $('ems-radial-center');
        var title = $('ems-radial-title');
        var hint = $('ems-radial-hint');
        var inSubmenu = radialState.depth > 0;
        if (title) title.textContent = (menu && menu.title) || 'EMS Operations';
        if (center) {
            center.setAttribute('data-action', 'radial-back');
            center.setAttribute('title', inSubmenu ? 'Back one menu' : 'Close radial menu');
        }
        if (hint) hint.textContent = inSubmenu ? 'BACK' : 'CLOSE';
    }

    function renderRadial(menu, depth) {
        radialState.menu = menu;
        radialState.depth = typeof depth === 'number' ? depth : radialState.depth;
        var svg = $('ems-radial-svg');
        if (!svg || !menu) return;
        svg.innerHTML = '';
        updateCenter(menu);

        var options = menu.options || [];
        if (!options.length) return;
        var step = 360 / options.length;
        var cx = 0, cy = 0, r1 = 78, r2 = 230;

        options.forEach(function (opt, index) {
            var start = index * step;
            var end = (index + 1) * step;
            var locked = opt.locked === true;
            var path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            path.setAttribute('d', describeSlice(cx, cy, r1, r2, start, end));
            var classes = ['ems-radial__slice'];
            if (opt.color === 'danger') classes.push('is-danger');
            if (locked) classes.push('is-locked');
            path.setAttribute('class', classes.join(' '));
            path.dataset.id = opt.id;
            if (opt.submenu) path.dataset.submenu = opt.submenu;
            path.addEventListener('click', function (ev) {
                ev.stopPropagation();
                if (opt.submenu) {
                    post('uiRadialNavigate', { id: opt.submenu });
                    return;
                }
                post('uiRadialSelect', {
                    id: opt.id,
                    locked: locked,
                    permission: opt.permission || null
                });
            });
            svg.appendChild(path);

            var mid = start + step / 2;
            var labelPos = polarToCartesian(cx, cy, 165, mid);
            var text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
            text.setAttribute('x', labelPos.x);
            text.setAttribute('y', labelPos.y);
            text.setAttribute('text-anchor', 'middle');
            text.setAttribute('class', 'ems-radial__slice-label' + (locked ? ' is-locked' : ''));
            text.textContent = locked ? (opt.title + ' · Locked') : (opt.title || opt.id);
            svg.appendChild(text);
        });
    }

    function setRadialVisible(visible) {
        radialState.visible = visible;
        var root = $('ems-radial');
        if (!root) return;
        root.hidden = !visible;
    }

    window.addEventListener('message', function (event) {
        var msg = event.data || {};
        if (msg.action === 'radial:open') {
            radialState.stack = [];
            radialState.depth = 0;
            setRadialVisible(true);
            renderRadial(msg.data && msg.data.menu, 0);
        } else if (msg.action === 'radial:navigate') {
            var payload = msg.data || {};
            renderRadial(payload.menu, payload.depth || 0);
        } else if (msg.action === 'radial:identity') {
            var d = msg.data || {};
            if ($('ems-radial-rank')) $('ems-radial-rank').textContent = d.rankLabel || 'EMS';
            if ($('ems-radial-status')) $('ems-radial-status').textContent = d.statusLabel || 'ON DUTY';
        } else if (msg.action === 'radial:close' || msg.action === 'ui:reset') {
            radialState.stack = [];
            radialState.depth = 0;
            setRadialVisible(false);
        }
    });

    document.addEventListener('keydown', function (ev) {
        if (!radialState.visible) return;

        if (ev.key === 'Escape' || ev.key === 'Backspace') {
            ev.preventDefault();
            radialBack();
        }
    });

    document.querySelectorAll('[data-action="close"]').forEach(function (el) {
        el.addEventListener('click', function () { post('uiClose'); });
    });

    document.addEventListener('click', function (ev) {
        var target = ev.target && ev.target.closest ? ev.target.closest('[data-action]') : null;
        if (!target) return;
        var action = target.getAttribute('data-action');
        if (action === 'radial-back') {
            ev.stopPropagation();
            radialBack();
        }
    });
})();
