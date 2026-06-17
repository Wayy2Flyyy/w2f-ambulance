W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.TrainingDummy = W2FAmbulance.TrainingDummy or {}

local Dummy = W2FAmbulance.TrainingDummy
local medicalShared = require 'medical.config.shared'
local cfg = Config.TrainingDummy or {}

local ASSESS_TTL = 300
local TREATMENTS = { 'treat', 'help', 'repair', 'revive' }

---@type table<string, { treatment: string, status: table }>
local scenarios = {}

---@type table<number, table<string, { treatment: string, label: string, assessedAt: integer }>>
local records = {}

local function treatmentLabel(treatment)
    local key = ('treatment.%s'):format(treatment)
    local label = locale(key)
    if label == key then return treatment end
    return label
end

local function randomWeapon()
    local weapons = cfg.DamageWeapons or { `WEAPON_PISTOL` }
    return weapons[math.random(#weapons)]
end

local function buildInjuryLines(entries)
    local lines = {}
    for i = 1, #(entries or {}) do
        local row = entries[i]
        local part = medicalShared.bodyParts[row.part]
        local wound = medicalShared.woundLevels[row.severity]
        if part and wound then
            lines[#lines + 1] = part.label .. ' (' .. wound.label .. ')'
        end
    end
    return lines
end

local function buildStatus(scenarioCfg)
    local bleedLevel = scenarioCfg.bleedLevel or 0
    local injuries = buildInjuryLines(scenarioCfg.injuries)
    local damageCauses = {}

    if #injuries > 0 then
        damageCauses[randomWeapon()] = true
    end
    if bleedLevel >= 3 then
        damageCauses[randomWeapon()] = true
    end

    return {
        injuries = injuries,
        bleedLevel = bleedLevel,
        bleedState = medicalShared.bleedingStates[bleedLevel] or '',
        damageCauses = damageCauses,
    }
end

function Dummy.isDummyItem(itemName)
    return itemName == (cfg.ItemName or 'ems_training_dummy')
end

function Dummy.isTrainingDummy(objectId)
    return scenarios[objectId] ~= nil
end

function Dummy.init(objectId)
    Dummy.rollScenario(objectId)
end

function Dummy.clear(objectId)
    scenarios[objectId] = nil
    for medicSrc, rows in pairs(records) do
        rows[objectId] = nil
        if not next(rows) then records[medicSrc] = nil end
    end
end

function Dummy.rollScenario(objectId)
    local treatment = TREATMENTS[math.random(#TREATMENTS)]
    local template = (cfg.Scenarios or {})[treatment] or { bleedLevel = 0, injuries = {} }
    scenarios[objectId] = {
        treatment = treatment,
        status = buildStatus(template),
    }
    for medicSrc, rows in pairs(records) do
        rows[objectId] = nil
        if not next(rows) then records[medicSrc] = nil end
    end
    return scenarios[objectId]
end

function Dummy.getScenario(objectId)
    return scenarios[objectId]
end

function Dummy.getRequired(objectId)
    local row = scenarios[objectId]
    if not row then return 'none', treatmentLabel('none') end
    return row.treatment, treatmentLabel(row.treatment)
end

function Dummy.recordAssessment(medicSrc, objectId)
    local treatment, label = Dummy.getRequired(objectId)
    records[medicSrc] = records[medicSrc] or {}
    records[medicSrc][objectId] = {
        treatment = treatment,
        label = label,
        assessedAt = os.time(),
    }
    return treatment, label
end

function Dummy.hasAssessment(medicSrc, objectId)
    local row = records[medicSrc] and records[medicSrc][objectId]
    if not row then return false end
    return (os.time() - row.assessedAt) <= ASSESS_TTL
end

function Dummy.clearAssessment(medicSrc, objectId)
    if not records[medicSrc] then return end
    records[medicSrc][objectId] = nil
end

function Dummy.validate(medicSrc, objectId, attempted)
    if not Dummy.isTrainingDummy(objectId) then
        return false, 'missing_dummy', nil, nil
    end

    if not Dummy.hasAssessment(medicSrc, objectId) then
        return false, 'assessment_required', nil, nil
    end

    local needed, neededLabel = Dummy.getRequired(objectId)
    if needed == 'none' then
        Dummy.clearAssessment(medicSrc, objectId)
        return false, 'patient_now_stable', nil, nil
    end

    if needed ~= attempted then
        return false, 'wrong_treatment', needed, neededLabel
    end

    return true, nil, needed, neededLabel
end

function Dummy.notifyValidation(medicSrc, objectId, attempted)
    local ok, errKey, needed, neededLabel = Dummy.validate(medicSrc, objectId, attempted)
    if ok then return true end

    if errKey == 'assessment_required' then
        exports.qbx_core:Notify(medicSrc, locale('error.assessment_required'), 'error')
    elseif errKey == 'patient_now_stable' then
        exports.qbx_core:Notify(medicSrc, locale('error.patient_now_stable'), 'error')
    elseif errKey == 'wrong_treatment' then
        local hintKey = ('error.triage_wrong_%s'):format(attempted)
        local hint = locale(hintKey, neededLabel)
        if hint == hintKey then
            exports.qbx_core:Notify(medicSrc, locale('error.wrong_treatment', neededLabel), 'error')
        else
            exports.qbx_core:Notify(medicSrc, hint, 'error')
        end
    end

    return false
end

lib.callback.register('w2f-ambulance:cb:assessDummy', function(medicSrc, objectId)
    if type(objectId) ~= 'string' or not Dummy.isTrainingDummy(objectId) then
        return { ok = false }
    end

    local player = exports.qbx_core:GetPlayer(medicSrc)
    if not player or not W2FAmbulance.Core.isEmsOnDuty(player) then
        return { ok = false }
    end

    local treatment, label = Dummy.recordAssessment(medicSrc, objectId)
    local scenario = Dummy.getScenario(objectId)

    return {
        ok = true,
        treatment = treatment,
        label = label,
        status = scenario and scenario.status or nil,
    }
end)

lib.callback.register('w2f-ambulance:cb:validateDummyCare', function(medicSrc, objectId, attempted)
    local ok, errKey, needed, neededLabel = Dummy.validate(medicSrc, objectId, attempted)
    return {
        ok = ok,
        err = errKey,
        needed = needed,
        neededLabel = neededLabel,
    }
end)

RegisterNetEvent('w2f-ambulance:server:applyDummyCare', function(objectId, attempted)
    if GetInvokingResource() then return end
    local src = source
    if type(objectId) ~= 'string' or type(attempted) ~= 'string' then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player or not W2FAmbulance.Core.isEmsOnDuty(player) then return end

    if not Dummy.notifyValidation(src, objectId, attempted) then return end

    local item = W2FAmbulance.Care.getItem(attempted)
    if item and not W2FAmbulance.Care.consumeItem(src, attempted) then
        W2FAmbulance.Care.notifyMissingItem(src, item)
        return
    end

    Dummy.clearAssessment(src, objectId)
    Dummy.rollScenario(objectId)

    exports.qbx_core:Notify(src, locale('success.dummy_treated'), 'success')
    exports.qbx_core:Notify(src, locale('info.dummy_new_scenario'), 'inform', 7000)
end)
