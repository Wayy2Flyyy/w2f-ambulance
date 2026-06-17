(function () {
    'use strict';

    var root = null;
    var titleEl = null;
    var subtitleEl = null;
    var instructionEl = null;
    var roundEl = null;
    var triesEl = null;
    var bpmEl = null;
    var spo2El = null;
    var statusEl = null;
    var dotsEl = null;
    var actionBtn = null;

    var modes = {
        pulse: null,
        sequence: null,
        hold: null,
        breathe: null,
        gauge: null,
        dress: null
    };

    var state = {
        active: false,
        cancelled: false,
        scenario: null,
        round: 1,
        hits: 0,
        misses: 0,
        maxMisses: 3,
        bindData: null,
        restartRound: null,
        raf: null,
        lastTs: 0,
        onSpace: null,
        onKeyUp: null,
        tick: null
    };

    function $(id) { return document.getElementById(id); }

    function post(name, payload) {
        if (typeof GetParentResourceName !== 'function') return Promise.resolve({});
        return fetch('https://' + GetParentResourceName() + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {})
        }).then(function (r) { return r.json().catch(function () { return {}; }); }).catch(function () { return {}; });
    }

    function renderDots(total, current, failed) {
        if (!dotsEl) return;
        dotsEl.innerHTML = '';
        for (var i = 0; i < total; i++) {
            var dot = document.createElement('span');
            dot.className = 'ems-mg__dot';
            if (i < current) dot.classList.add('is-done');
            if (failed && i === current) dot.classList.add('is-fail');
            dotsEl.appendChild(dot);
        }
    }

    function setStatus(text, level) {
        if (!statusEl) return;
        statusEl.textContent = text || '';
        statusEl.className = 'ems-minigame__status' + (level ? ' is-' + level : '');
    }

    function setRoundLabel() {
        if (!roundEl || !state.scenario) return;
        roundEl.textContent = 'Round ' + state.round + ' / ' + state.scenario.rounds;
    }

    function setTriesLabel() {
        if (!triesEl) return;
        var left = Math.max(0, state.maxMisses - state.misses);
        triesEl.textContent = left + ' tr' + (left === 1 ? 'y' : 'ies') + ' left';
    }

    function retryCurrentRound() {
        renderDots(state.scenario.rounds, state.hits, false);
        if (state.restartRound) state.restartRound();
        setTriesLabel();
        setStatus('Try again…', '');
    }

    function hideModes() {
        Object.keys(modes).forEach(function (key) {
            if (modes[key]) modes[key].hidden = true;
        });
    }

    function showMode(name) {
        hideModes();
        if (modes[name]) modes[name].hidden = false;
    }

    function stopLoop() {
        if (state.raf) cancelAnimationFrame(state.raf);
        state.raf = null;
        state.tick = null;
        state.onSpace = null;
        state.onKeyUp = null;
    }

    function finish(success) {
        if (!state.active) return;
        state.active = false;
        stopLoop();
        if (root) root.hidden = true;
        post('minigameComplete', { success: !!success, cancelled: state.cancelled });
    }

    function failRound() {
        state.misses += 1;
        renderDots(state.scenario.rounds, state.hits, true);
        setTriesLabel();

        if (state.misses >= state.maxMisses) {
            setStatus('Too many mistakes — procedure failed', 'fail');
            window.setTimeout(function () { finish(false); }, 650);
            return;
        }

        var left = state.maxMisses - state.misses;
        setStatus('Missed — ' + left + ' tr' + (left === 1 ? 'y' : 'ies') + ' left', 'fail');
        window.setTimeout(retryCurrentRound, 650);
    }

    function completeRound() {
        state.hits += 1;
        renderDots(state.scenario.rounds, state.hits, false);
        if (state.hits >= state.scenario.rounds) {
            setStatus('Procedure complete', 'ok');
            window.setTimeout(function () { finish(true); }, 450);
            return true;
        }
        state.round += 1;
        setRoundLabel();
        setStatus('Good — continue', 'ok');
        return false;
    }

    function loopFrame(ts) {
        if (!state.active || !state.tick) return;
        if (!state.lastTs) state.lastTs = ts;
        var dt = (ts - state.lastTs) / 1000;
        state.lastTs = ts;
        state.tick(dt, ts);
        if (bpmEl && state.scenario) {
            bpmEl.textContent = Math.round(72 + (state.hits * 4) + (Math.sin(ts / 280) * 5));
        }
        if (spo2El && state.scenario) {
            spo2El.textContent = Math.round(86 + (state.hits / state.scenario.rounds) * 12) + '%';
        }
        state.raf = requestAnimationFrame(loopFrame);
    }

    function startLoop() {
        state.lastTs = 0;
        state.raf = requestAnimationFrame(loopFrame);
    }

    function bindPulse(data) {
        var trackEl = $('mg-track');
        var zoneEl = $('mg-zone');
        var markerEl = $('mg-marker');
        var ekgPath = $('mg-ekg-path');
        var pos = 0;
        var dir = 1;
        var zoneSize = data.window || 0.16;
        var zoneStart = 0.5 - (zoneSize / 2);
        var speed = data.speed || 1;

        function updateZone() {
            if (!zoneEl || !trackEl || !markerEl) return;
            var width = trackEl.clientWidth || 360;
            zoneEl.style.width = (width * zoneSize) + 'px';
            zoneEl.style.left = (width * zoneStart) + 'px';
            markerEl.style.left = (width * pos) + 'px';
        }

        function renderEkg(ts) {
            if (!ekgPath) return;
            var points = [];
            var width = 420;
            var mid = 24;
            for (var x = 0; x <= width; x += 4) {
                var t = (ts / 220) + (x * 0.04);
                var y = mid + Math.sin(t) * 3;
                if (Math.floor(t * 2.4) % 7 === 0) y -= 10;
                if (Math.floor(t * 2.4) % 7 === 1) y += 14;
                points.push((x === 0 ? 'M' : 'L') + x + ' ' + y);
            }
            ekgPath.setAttribute('d', points.join(' '));
        }

        updateZone();
        state.tick = function (dt, ts) {
            pos += dir * speed * dt;
            if (pos >= 1) { pos = 1; dir = -1; }
            if (pos <= 0) { pos = 0; dir = 1; }
            updateZone();
            renderEkg(ts);
        };

        state.onSpace = function () {
            var zoneEnd = zoneStart + zoneSize;
            if (pos >= zoneStart && pos <= zoneEnd) {
                if (completeRound()) return;
                speed = (data.speed || 1) * (1 + (state.hits * 0.02));
                setStatus('Keep rhythm', 'ok');
            } else {
                failRound();
            }
        };

        state.restartRound = function () {
            pos = 0.5;
            dir = 1;
            updateZone();
        };
    }

    function bindSequence(data) {
        var vitalsEl = $('mg-vitals');
        var promptEl = $('mg-sequence-prompt');
        var labels = data.sequenceLabels || ['Heart Rate', 'Blood Pressure', 'SpO2', 'Temperature'];
        var chips = [];
        var targetIdx = 0;
        var highlightIdx = 0;
        var stepMs = (data.flashMs || 1400) / labels.length;
        var elapsed = 0;

        vitalsEl.innerHTML = '';
        labels.forEach(function (label) {
            var chip = document.createElement('div');
            chip.className = 'mg-vital';
            chip.innerHTML = '<span class="mg-vital__label">' + label + '</span><strong class="mono">OK</strong>';
            vitalsEl.appendChild(chip);
            chips.push(chip);
        });

        function nextRoundSetup() {
            targetIdx = Math.floor(Math.random() * labels.length);
            highlightIdx = 0;
            elapsed = 0;
            if (promptEl) promptEl.textContent = 'Confirm: ' + labels[targetIdx];
            chips.forEach(function (chip) {
                chip.classList.remove('is-active', 'is-match');
            });
        }

        nextRoundSetup();

        state.tick = function (dt) {
            elapsed += dt * 1000;
            highlightIdx = Math.floor(elapsed / stepMs) % labels.length;
            chips.forEach(function (chip, idx) {
                chip.classList.toggle('is-active', idx === highlightIdx);
            });
        };

        state.onSpace = function () {
            if (highlightIdx === targetIdx) {
                chips[highlightIdx].classList.add('is-match');
                if (completeRound()) return;
                window.setTimeout(nextRoundSetup, 350);
            } else {
                failRound();
            }
        };

        state.restartRound = nextRoundSetup;
    }

    function bindHold(data) {
        var trackEl = $('mg-hold-track');
        var zoneEl = $('mg-hold-zone');
        var markerEl = $('mg-hold-marker');
        var fillEl = $('mg-hold-fill');
        var pos = 0.5;
        var dir = 1;
        var zoneSize = data.window || 0.22;
        var zoneStart = 0.5 - (zoneSize / 2);
        var speed = data.speed || 0.75;
        var holdMs = data.holdMs || 900;
        var holding = false;
        var holdElapsed = 0;
        var graceMs = 250;

        function updateZone() {
            if (!zoneEl || !trackEl || !markerEl) return;
            var width = trackEl.clientWidth || 360;
            zoneEl.style.width = (width * zoneSize) + 'px';
            zoneEl.style.left = (width * zoneStart) + 'px';
            markerEl.style.left = (width * pos) + 'px';
        }

        function inZone() {
            return pos >= (zoneStart - 0.01) && pos <= (zoneStart + zoneSize + 0.01);
        }

        function resetHoldAttempt(message) {
            holding = false;
            holdElapsed = 0;
            if (fillEl) fillEl.style.width = '0%';
            if (message) setStatus(message, '');
        }

        updateZone();

        state.tick = function (dt) {
            if (!holding) {
                pos += dir * speed * dt;
                if (pos >= 1) { pos = 1; dir = -1; }
                if (pos <= 0) { pos = 0; dir = 1; }
                updateZone();
                return;
            }

            holdElapsed += dt * 1000;
            if (fillEl) fillEl.style.width = Math.min(100, (holdElapsed / holdMs) * 100) + '%';
            if (holdElapsed >= holdMs) {
                resetHoldAttempt('');
                if (completeRound()) return;
                pos = 0.5;
                dir = 1;
                updateZone();
                setStatus('Next wound — hold when ready', 'ok');
            }
        };

        state.onSpace = function () {
            if (holding) return;
            if (!inZone()) {
                failRound();
                return;
            }
            holding = true;
            holdElapsed = 0;
            if (fillEl) fillEl.style.width = '0%';
            setStatus('Hold steady…', '');
        };

        state.onKeyUp = function () {
            if (!holding) return;
            if (holdElapsed + graceMs < holdMs) {
                resetHoldAttempt('');
                failRound();
            }
        };

        state.restartRound = function () {
            resetHoldAttempt('');
            pos = 0.5;
            dir = 1;
            updateZone();
        };
    }

    function bindDress(data) {
        var woundsEl = $('mg-dress-wounds');
        var stepEl = $('mg-dress-step');
        var windowEl = $('mg-dress-window');
        var packEl = $('mg-dress-pack');
        if (!woundsEl || !packEl) return;
        var railEl = packEl && packEl.parentElement;
        var sites = data.woundSites || ['Upper arm', 'Abdomen', 'Lower leg'];
        var placements = [
            { left: '28%', top: '38%' },
            { left: '50%', top: '52%' },
            { left: '62%', top: '78%' }
        ];
        var targets = [0.24, 0.52, 0.78];
        var sweepMs = data.sweepMs || 3400;
        var winStartCfg = data.windowStart != null ? data.windowStart : 0.26;
        var winEndCfg = data.windowEnd != null ? data.windowEnd : 0.74;
        var barSize = data.windowSize != null ? data.windowSize : (winEndCfg - winStartCfg);
        var pos = 0;
        var elapsed = 0;
        var woundEls = [];
        var activeIdx = 0;
        var alignTolerance = 0.06;

        woundsEl.innerHTML = '';
        sites.forEach(function (label, idx) {
            var dot = document.createElement('div');
            dot.className = 'mg-dress__wound';
            dot.title = label;
            var place = placements[idx] || { left: '50%', top: '50%' };
            dot.style.left = place.left;
            dot.style.top = place.top;
            woundsEl.appendChild(dot);
            woundEls.push(dot);
        });

        function currentTarget() {
            return targets[activeIdx] != null ? targets[activeIdx] : 0.5;
        }

        function getBarHeight(height) {
            return Math.max(44, height * barSize);
        }

        function getWindowTop(height, barHeight) {
            var target = currentTarget();
            var top = (target * height) - (barHeight / 2);
            return Math.max(0, Math.min(height - barHeight, top));
        }

        function getPackTop(height, barHeight) {
            var top = (pos * height) - (barHeight / 2);
            return Math.max(0, Math.min(height - barHeight, top));
        }

        function isAligned(height, barHeight) {
            var winTop = getWindowTop(height, barHeight);
            var packTop = getPackTop(height, barHeight);
            return Math.abs(packTop - winTop) <= (barHeight * alignTolerance);
        }

        function updateLayout() {
            if (!railEl || !windowEl || !packEl) return;
            var height = railEl.clientHeight || 180;
            var barHeight = getBarHeight(height);
            var winTop = getWindowTop(height, barHeight);
            var packTop = getPackTop(height, barHeight);

            windowEl.style.top = winTop + 'px';
            windowEl.style.height = barHeight + 'px';
            packEl.style.height = barHeight + 'px';
            packEl.style.top = packTop + 'px';
            packEl.classList.toggle('is-aligned', isAligned(height, barHeight));
        }

        function highlightWound() {
            woundEls.forEach(function (el, idx) {
                el.classList.toggle('is-active', idx === activeIdx && !el.classList.contains('is-dressed'));
            });
            if (stepEl) stepEl.textContent = 'Dress: ' + (sites[activeIdx] || ('Wound ' + (activeIdx + 1)));
        }

        function resetSweep() {
            pos = 0;
            elapsed = 0;
            updateLayout();
        }

        function setupRound() {
            activeIdx = state.hits;
            highlightWound();
            resetSweep();
            setStatus('Align bandage with ' + (sites[activeIdx] || 'wound'), '');
        }

        setupRound();

        state.tick = function (dt) {
            elapsed += dt * 1000;
            pos = (elapsed % sweepMs) / sweepMs;
            updateLayout();
        };

        state.onSpace = function () {
            var height = railEl.clientHeight || 180;
            var barHeight = getBarHeight(height);
            if (!isAligned(height, barHeight)) {
                failRound();
                return;
            }
            if (woundEls[activeIdx]) {
                woundEls[activeIdx].classList.remove('is-active');
                woundEls[activeIdx].classList.add('is-dressed');
            }
            if (completeRound()) return;
            setupRound();
            setStatus('Wound dressed — next site', 'ok');
        };

        state.restartRound = setupRound;
    }

    function bindBreathe(data) {
        var lungsEl = $('mg-lungs');
        var promptEl = $('mg-breathe-prompt');
        var sides = ['Left Lung', 'Right Lung'];
        var active = 0;
        var elapsed = 0;
        var cycleMs = data.cycleMs || 1100;
        var inhaleRatio = data.inhaleRatio || 0.55;
        var lungEls = [];

        lungsEl.innerHTML = '';
        sides.forEach(function (label) {
            var node = document.createElement('div');
            node.className = 'mg-lung';
            node.innerHTML = '<span class="mg-lung__icon">◐</span><span>' + label + '</span>';
            lungsEl.appendChild(node);
            lungEls.push(node);
        });

        state.tick = function (dt) {
            elapsed += dt * 1000;
            if (elapsed >= cycleMs) {
                elapsed = 0;
                active = (active + 1) % sides.length;
            }
            var inhale = elapsed < cycleMs * inhaleRatio;
            lungEls.forEach(function (el, idx) {
                el.classList.toggle('is-active', idx === active);
                el.classList.toggle('is-inhale', idx === active && inhale);
            });
            if (promptEl) {
                promptEl.textContent = inhale
                    ? ('Assist on inhale — ' + sides[active])
                    : ('Wait for inhale — ' + sides[active]);
            }
        };

        state.onSpace = function () {
            var inhale = elapsed < cycleMs * inhaleRatio;
            if (inhale) {
                if (completeRound()) return;
                elapsed = 0;
                active = (active + 1) % sides.length;
                setStatus('Breath assisted', 'ok');
            } else {
                failRound();
            }
        };

        state.restartRound = function () {
            elapsed = 0;
        };
    }

    function bindGauge(data) {
        var needleEl = $('mg-gauge-needle');
        var zoneEl = $('mg-gauge-zone');
        var pos = 0;
        var dir = 1;
        var zoneSize = data.window || 0.14;
        var zoneStart = 0.42 - (zoneSize / 2);
        var speed = data.speed || 1.35;

        function updateGauge() {
            if (!needleEl || !zoneEl) return;
            var height = 160;
            zoneEl.style.height = (height * zoneSize) + 'px';
            zoneEl.style.bottom = (height * zoneStart) + 'px';
            needleEl.style.bottom = (height * pos) + 'px';
        }

        updateGauge();

        state.tick = function (dt) {
            pos += dir * speed * dt;
            if (pos >= 1) { pos = 1; dir = -1; }
            if (pos <= 0) { pos = 0; dir = 1; }
            updateGauge();
        };

        state.onSpace = function () {
            var zoneEnd = zoneStart + zoneSize;
            if (pos >= zoneStart && pos <= zoneEnd) {
                if (completeRound()) return;
                speed = (data.speed || 1.35) * (1 + (state.hits * 0.02));
                setStatus('Tension locked', 'ok');
            } else {
                failRound();
            }
        };

        state.restartRound = function () {
            pos = 0.5;
            dir = 1;
            updateGauge();
        };
    }

    function bindMode(data) {
        stopLoop();
        state.bindData = data;
        state.restartRound = null;
        var type = data.type || 'pulse';
        showMode(type);

        if (type === 'pulse') bindPulse(data);
        else if (type === 'sequence') bindSequence(data);
        else if (type === 'hold') bindHold(data);
        else if (type === 'dress') bindDress(data);
        else if (type === 'breathe') bindBreathe(data);
        else if (type === 'gauge') bindGauge(data);
        else bindPulse(data);

        startLoop();
    }

    function startScenario(data) {
        root = $('ems-minigame');
        titleEl = $('mg-title');
        subtitleEl = $('mg-subtitle');
        instructionEl = $('mg-instruction');
        roundEl = $('mg-round');
        triesEl = $('mg-tries');
        bpmEl = $('mg-bpm');
        spo2El = $('mg-spo2');
        statusEl = $('mg-status');
        dotsEl = $('mg-dots');
        actionBtn = $('mg-action');

        modes.pulse = $('mg-mode-pulse');
        modes.sequence = $('mg-mode-sequence');
        modes.hold = $('mg-mode-hold');
        modes.breathe = $('mg-mode-breathe');
        modes.gauge = $('mg-mode-gauge');
        modes.dress = $('mg-mode-dress');

        if (!root || !data) return;

        state.active = true;
        state.cancelled = false;
        state.scenario = {
            rounds: data.rounds || 3,
            speed: data.speed || 1,
            window: data.window || 0.16,
            holdMs: data.holdMs || 900,
            cycleMs: data.cycleMs || 1100,
            flashMs: data.flashMs || 1400,
            inhaleRatio: data.inhaleRatio || 0.55,
            sweepMs: data.sweepMs || 3400,
            windowStart: data.windowStart != null ? data.windowStart : 0.26,
            windowEnd: data.windowEnd != null ? data.windowEnd : 0.74,
            windowSize: data.windowSize,
            woundSites: data.woundSites,
            sequenceLabels: data.sequenceLabels,
            maxMisses: data.maxMisses || 3
        };
        state.round = 1;
        state.hits = 0;
        state.misses = 0;
        state.maxMisses = data.maxMisses || 3;

        if (titleEl) titleEl.textContent = data.label || 'EMS Procedure';
        if (subtitleEl) subtitleEl.textContent = data.subtitle || '';
        if (instructionEl) instructionEl.textContent = data.instruction || 'Press SPACE to continue';
        if (actionBtn) {
            actionBtn.textContent = data.type === 'hold' ? 'Apply Pressure'
                : data.type === 'dress' ? 'Apply Bandage'
                : 'Confirm';
        }
        setRoundLabel();
        setTriesLabel();
        renderDots(state.scenario.rounds, 0, false);
        setStatus('Awaiting input…', '');
        root.hidden = false;

        bindMode(data);
    }

    function onAction() {
        if (!state.active || !state.onSpace) return;
        state.onSpace();
    }

    window.addEventListener('message', function (event) {
        var msg = event.data || {};
        if (msg.action === 'minigame:open') startScenario(msg.data || {});
        else if (msg.action === 'minigame:close' || msg.action === 'ui:reset') finish(false);
    });

    document.addEventListener('keydown', function (ev) {
        if (!state.active) return;
        if (ev.code === 'Space' || ev.key === ' ') {
            if (ev.repeat) return;
            ev.preventDefault();
            onAction();
        } else if (ev.key === 'Escape') {
            ev.preventDefault();
            state.cancelled = true;
            setStatus('Canceled', 'fail');
            finish(false);
        }
    });

    document.addEventListener('keyup', function (ev) {
        if (!state.active || !state.onKeyUp) return;
        if (ev.code === 'Space' || ev.key === ' ') {
            ev.preventDefault();
            state.onKeyUp();
        }
    });

    if ($('mg-action')) $('mg-action').addEventListener('click', onAction);
})();
