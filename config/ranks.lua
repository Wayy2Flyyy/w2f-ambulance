Config = Config or {}

---@param label string
---@param shortName string
---@param payGrade number
---@param supervisor? boolean
---@param command? boolean
---@param highCommand? boolean
local function rank(label, shortName, payGrade, supervisor, command, highCommand)
    return {
        label = label,
        shortName = shortName,
        payGrade = payGrade,
        supervisor = supervisor or false,
        command = command or false,
        highCommand = highCommand or false,
    }
end

--- EMS rank ladder (grades 0–8). Mirror these names/payments in qbx_core/shared/jobs.lua.
Config.Ranks = {
    [0] = rank('Trainee EMT',       'EMT-T', 1800),
    [1] = rank('EMT Basic',        'EMT',   2400),
    [2] = rank('Advanced EMT',     'AEMT',  3000),
    [3] = rank('Paramedic',        'PM',    3600),
    [4] = rank('Senior Paramedic', 'SR.PM', 4200, true),
    [5] = rank('Flight Medic',     'F/L',   4800, true),
    [6] = rank('Physician',        'MD',    5500, true, true),
    [7] = rank('Medical Director', 'M.DIR', 6500, true, true, true),
    [8] = rank('Chief of EMS',     'CHIEF', 7800, true, true, true),
}

--- Minimum grade required for each capability.
Config.RankPermissions = {
    GoOnDuty           = 0,
    UseStash           = 0,
    UseArmory          = 0,
    UseMedCabinet      = 2, --- Trusted rank (Advanced EMT+) — prescriptions & controlled meds
    UseGarage          = 0,
    CheckPatientStatus = 0,
    TreatWounds        = 0,
    RevivePatient      = 1,
    IssuePrescription  = 2,
    PutPatientInBed    = 3,
    EmergencyBroadcast = 4,
    UseAirGarage       = 5,
    ManagePersonnel    = 6,
    ManageDepartment   = 7,
    HighCommandAccess  = 7,
}

Config.JobName = 'ambulance'
