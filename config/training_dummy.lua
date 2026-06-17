Config = Config or {}

--- Simulated patient scenarios for the Freddy training dummy.
--- Each entry mirrors real GetPlayerStatus output for that required treatment.
Config.TrainingDummy = {
    ItemName = 'ems_training_dummy',
    PropModel = 'dummy',

    --- Weapon hashes shown in status (display only).
    DamageWeapons = {
        `WEAPON_PISTOL`,
        `WEAPON_KNIFE`,
        `WEAPON_BAT`,
        `WEAPON_FALL`,
    },

    Scenarios = {
        treat = {
            bleedLevel = 2,
            injuries = {
                { part = 'LARM', severity = 2 },
                { part = 'LOWER_BODY', severity = 1 },
            },
        },
        help = {
            bleedLevel = 1,
            injuries = {
                { part = 'UPPER_BODY', severity = 2 },
                { part = 'NECK', severity = 1 },
            },
        },
        repair = {
            bleedLevel = 4,
            injuries = {
                { part = 'SPINE', severity = 4 },
                { part = 'HEAD', severity = 3 },
                { part = 'LLEG', severity = 3 },
            },
        },
        revive = {
            bleedLevel = 0,
            injuries = {},
        },
    },
}
