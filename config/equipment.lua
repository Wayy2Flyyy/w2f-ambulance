Config = Config or {}

Config.EquipmentCategories = {
    { id = 'supplies', label = 'Field Supplies', icon = 'bandage' },
    { id = 'medical',  label = 'Medical Kits',   icon = 'briefcase-medical' },
    { id = 'tools',    label = 'Tools',          icon = 'screwdriver-wrench' },
    { id = 'command',  label = 'Command',        icon = 'tablet' },
}

Config.MedCabinetCategories = {
    { id = 'prescriptions', label = 'Prescription Pads', icon = 'file-prescription' },
    { id = 'painkillers',   label = 'Pain Relief',       icon = 'pills' },
    { id = 'controlled',    label = 'Controlled Meds',   icon = 'capsules' },
}

--- Grade-gated armory, med cabinet, ground garage, and air garage catalogs.
Config.Equipment = {
    armory = {
        { id = 'radio',                   name = 'radio',                   label = 'Radio',                   category = 'tools',    amount = 1, minRank = 0 },
        { id = 'bandage',                 name = 'bandage',                 label = 'Bandage',                 category = 'supplies', amount = 3, minRank = 0 },
        { id = 'firstaid',                name = 'firstaid',                label = 'First Aid Kit',           category = 'medical',  amount = 1, minRank = 1 },
        { id = 'ifaks',                   name = 'ifaks',                   label = 'IFAK',                    category = 'medical',  amount = 1, minRank = 1 },
        { id = 'weapon_flashlight',       name = 'weapon_flashlight',       label = 'Flashlight',              category = 'tools',    amount = 1, minRank = 4 },
        { id = 'weapon_fireextinguisher', name = 'weapon_fireextinguisher', label = 'Fire Extinguisher',       category = 'tools',    amount = 1, minRank = 4 },
        { id = 'ems_command_tablet',      name = 'ems_command_tablet',      label = 'EMS Command Tablet',      category = 'command',  amount = 1, minRank = 7 },
        { id = 'ems_training_dummy',      name = 'ems_training_dummy',      label = 'CPR Training Dummy (Freddy)', category = 'command', amount = 1, minRank = 7 },
    },

    --- Trusted rank only (see UseMedCabinet). Prescription pads + painkillers + pharmacy stock.
    medCabinet = {
        { id = 'medical_prescription', name = 'medical_prescription', label = 'Prescription Pad', category = 'prescriptions', amount = 1, minRank = 0 },
        { id = 'painkillers',          name = 'painkillers',          label = 'Painkillers',      category = 'painkillers',   amount = 3, minRank = 0 },
        { id = 'haveitol',             name = 'haveitol',             label = 'Haveitol',         category = 'controlled',    amount = 2, minRank = 0 },
        { id = 'dead_tired',           name = 'dead_tired',           label = 'Dead Tired',       category = 'controlled',    amount = 2, minRank = 0 },
        { id = 'wakey_wakey',          name = 'wakey_wakey',          label = 'Wakey Wakey',      category = 'controlled',    amount = 2, minRank = 0 },
        { id = 'oxycodone',            name = 'oxycodone',            label = 'Oxycodone',        category = 'controlled',    amount = 1, minRank = 0 },
        { id = 'fentanyl',             name = 'fentanyl',             label = 'Fentanyl',         category = 'controlled',    amount = 1, minRank = 0 },
    },

    --- Every vanilla GTA V ambulance variant (single `ambulance` model, three agency liveries).
    garage = {
        { id = 'ambulance_lsmc', model = 'ambulance', label = 'LSMC Ambulance', minRank = 0, livery = 0 },
        { id = 'ambulance_mrsa', model = 'ambulance', label = 'MRSA Ambulance', minRank = 0, livery = 1 },
        { id = 'ambulance_lsfd', model = 'ambulance', label = 'LSFD Ambulance', minRank = 1, livery = 2 },
    },

    air = {
        { id = 'polmav', model = 'polmav', label = 'Air Medical Unit', minRank = 5, livery = 1 },
    },
}
