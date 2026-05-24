Config = Config or {}

--- Civilian-facing medical visit registry (separate from internal EMS clinical notes).
Config.PublicRecords = {
    facility = 'Pillbox Hospital',
    autoPublish = true,

    visitTypes = {
        checkup = 'Medical Assessment',
        treatment = 'Wound Treatment',
        revive = 'Emergency Revive',
        prescription = 'Prescription Issued',
        hospital = 'Hospital Care',
        stabilization = 'Trauma Stabilization',
        manual = 'Medical Visit',
    },

    kiosks = {
        {
            label = 'Public Medical Records',
            coords = vec3(307.42, -595.08, 43.29),
            size = vec3(1.2, 1.2, 2.0),
            rotation = 340,
            blip = {
                enabled = true,
                sprite = 408,
                colour = 2,
                scale = 0.65,
                label = 'Public Medical Records',
            },
        },
    },
}
