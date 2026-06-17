--- Cause-based triage rules and hospital check-in timing.

local weaponClasses = {
    SMALL_CALIBER = 1,
    MEDIUM_CALIBER = 2,
    HIGH_CALIBER = 3,
    SHOTGUN = 4,
    CUTTING = 5,
    LIGHT_IMPACT = 6,
    HEAVY_IMPACT = 7,
    EXPLOSIVE = 8,
    FIRE = 9,
    SUFFOCATING = 10,
    OTHER = 11,
    WILDLIFE = 12,
    NONE = 13,
}

return {
    weaponClasses = weaponClasses,

    --- Base treatment for each weapon class when the patient is alive with injuries.
    --- Severity and bleed can upgrade/downgrade the final result.
    weaponClassTreatment = {
        [weaponClasses.SMALL_CALIBER] = 'treat',
        [weaponClasses.MEDIUM_CALIBER] = 'treat',
        [weaponClasses.HIGH_CALIBER] = 'repair',
        [weaponClasses.SHOTGUN] = 'repair',
        [weaponClasses.CUTTING] = 'treat',
        [weaponClasses.LIGHT_IMPACT] = 'treat',
        [weaponClasses.HEAVY_IMPACT] = 'repair',
        [weaponClasses.EXPLOSIVE] = 'repair',
        [weaponClasses.FIRE] = 'repair',
        [weaponClasses.SUFFOCATING] = 'help',
        [weaponClasses.OTHER] = 'treat',
        [weaponClasses.WILDLIFE] = 'treat',
        [weaponClasses.NONE] = 'treat',
    },

    --- When multiple injury causes exist, higher priority wins for triage.
    classPriority = {
        [weaponClasses.EXPLOSIVE] = 100,
        [weaponClasses.FIRE] = 90,
        [weaponClasses.HEAVY_IMPACT] = 80,
        [weaponClasses.HIGH_CALIBER] = 70,
        [weaponClasses.SHOTGUN] = 65,
        [weaponClasses.SUFFOCATING] = 60,
        [weaponClasses.MEDIUM_CALIBER] = 40,
        [weaponClasses.SMALL_CALIBER] = 35,
        [weaponClasses.CUTTING] = 30,
        [weaponClasses.WILDLIFE] = 25,
        [weaponClasses.LIGHT_IMPACT] = 20,
        [weaponClasses.OTHER] = 15,
        [weaponClasses.NONE] = 10,
    },

    --- Upgrade minor wound care to trauma stabilization.
    upgradeToRepair = {
        minBleed = 3,
        minSeverity = 3,
    },

    --- Downgrade trauma care to wound dressing for very minor cases.
    downgradeToTreat = {
        maxBleed = 1,
        maxSeverity = 1,
    },

    --- Base check-in review duration (ms) by required treatment type.
    checkInDuration = {
        none = 4000,
        treat = 7000,
        repair = 11000,
        help = 13000,
        revive = 16000,
    },

    --- Extra review time per injury severity level above 1 (ms).
    severityDurationBonus = 1500,

    --- Extra review time per bleed level (ms).
    bleedDurationBonus = 2000,

    --- Locale keys for weapon class cause labels (shown during EMS assessment).
    causeLocaleKeys = {
        [1] = 'cause.small_caliber',
        [2] = 'cause.medium_caliber',
        [3] = 'cause.high_caliber',
        [4] = 'cause.shotgun',
        [5] = 'cause.cutting',
        [6] = 'cause.light_impact',
        [7] = 'cause.heavy_impact',
        [8] = 'cause.explosive',
        [9] = 'cause.fire',
        [10] = 'cause.suffocating',
        [11] = 'cause.other',
        [12] = 'cause.wildlife',
        [13] = 'cause.none',
    },

    --- Bedside doctor that treats the patient while they lie in a hospital bed.
    bedDoctor = {
        model = `s_m_m_doctor_01`,
        --- Offset from patient ped while lying in bed (right side, slightly toward feet).
        offset = { x = 0.9, y = 0.2, z = -0.95 },
        --- Floor height relative to bed coords (interiors ignore ground probes).
        zCorrection = -0.92,
        anims = {
            none = {
                dict = 'amb@medic@standing@tendtodead@base',
                clip = 'base',
                flag = 49,
            },
            treat = {
                dict = 'amb@medic@standing@tendtodead@base',
                clip = 'base',
                flag = 49,
            },
            repair = {
                dict = 'anim@gangops@facility@servers@bodysearch@',
                clip = 'player_search',
                flag = 49,
            },
            help = {
                dict = 'amb@medic@standing@tendtodead@base',
                clip = 'base',
                flag = 49,
            },
            revive = {
                dict = 'mini@cpr@char_a@cpr_str',
                clip = 'cpr_pumpchest',
                flag = 1,
            },
        },
    },
}
