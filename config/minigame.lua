Config = Config or {}

--- Overlay minigames for EMS patient care — one unique game + animation per scenario.
--- Tuned for relaxed pacing: wider windows, slower movement, more rounds.
Config.Minigame = {
    enabled = true,
    defaultKey = 'Space',
    testCommand = 'emsmgtest',
    maxMisses = 3,

    --- Items consumed when a care minigame succeeds or fails (not on cancel).
    careItems = {
        treat = 'bandage',
        repair = 'ifaks',
        revive = 'firstaid',
    },

    scenarios = {
        --- Vitals sequence — confirm each reading as it highlights (clipboard assessment).
        checkStatus = {
            type = 'sequence',
            label = 'Patient Assessment',
            subtitle = 'Confirm vitals on the monitor',
            instruction = 'Press SPACE when the highlighted vital matches the prompt',
            rounds = 6,
            useAnim = true,
            anim = {
                dict = 'missheistdockssetup1clipboard@base',
                clip = 'idle_a',
                flag = 49,
            },
            sequenceLabels = { 'Heart Rate', 'Blood Pressure', 'SpO2', 'Temperature' },
            flashMs = 3200,
        },

        --- Wound dressing — align bandage pack with each wound site on the body map.
        treat = {
            type = 'dress',
            label = 'Treat Wounds',
            subtitle = 'Dress each wound site',
            instruction = 'Press SPACE when the bandage pack lines up with the glowing wound',
            rounds = 3,
            sweepMs = 3400,
            windowSize = 0.24,
            woundSites = { 'Upper arm', 'Abdomen', 'Lower leg' },
            useAnim = true,
            anim = {
                dict = 'amb@medic@standing@kneel@base',
                clip = 'base',
                flag = 1,
            },
        },

        --- Breathing assist — press on alternating lung cycle (airway support).
        help = {
            type = 'breathe',
            label = 'Assist Patient',
            subtitle = 'Support breathing — match the active lung',
            instruction = 'Press SPACE when the glowing lung is active',
            rounds = 6,
            cycleMs = 2400,
            inhaleRatio = 0.72,
            useAnim = true,
            anim = {
                dict = 'amb@medic@standing@tendtodead@base',
                clip = 'base',
                flag = 1,
            },
        },

        --- Tension gauge — stop the needle in the stabilization window (trauma / IFAK).
        repair = {
            type = 'gauge',
            label = 'Trauma Stabilization',
            subtitle = 'Lock tension in the safe range',
            instruction = 'Press SPACE to lock the needle in the green zone',
            rounds = 5,
            speed = 0.55,
            window = 0.30,
            useAnim = true,
            anim = {
                dict = 'anim@gangops@facility@servers@bodysearch@',
                clip = 'player_search',
                flag = 1,
            },
        },

        --- CPR pulse timing — sliding marker rhythm (field revive).
        revive = {
            type = 'pulse',
            label = 'Field Revive',
            subtitle = 'CPR compressions — maintain rhythm',
            instruction = 'Press SPACE when the pulse hits the target zone',
            rounds = 6,
            speed = 0.55,
            window = 0.30,
            useAnim = true,
            anim = {
                dict = 'mini@cpr@char_a@cpr_str',
                clip = 'cpr_pumpchest',
                flag = 1,
            },
        },
    },
}
