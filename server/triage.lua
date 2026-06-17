W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Triage = W2FAmbulance.Triage or {}

local Triage = W2FAmbulance.Triage
local sharedConfig = require 'medical.config.shared'
local triageConfig = require 'config.triage'
local medicalClientConfig = require 'medical.config.client'
local resource = GetCurrentResourceName()

local ASSESS_TTL = 300

---@type table<number, table<number, { treatment: string, label: string, assessedAt: integer }>>
local records = {}

local function treatmentLabel(treatment)
    local key = ('treatment.%s'):format(treatment)
    local label = locale(key)
    if label == key then return treatment end
    return label
end

local function getInjuries(state)
    local injuries = {}
    for bodyPartKey in pairs(sharedConfig.bodyParts) do
        injuries[bodyPartKey] = state[BODY_PART_STATE_BAG_PREFIX .. bodyPartKey]
    end
    return injuries
end

---@param weaponHash number?
---@return integer
local function getWeaponClass(weaponHash)
    if not weaponHash then
        return triageConfig.weaponClasses.NONE
    end
    return medicalClientConfig.weapons[weaponHash] or triageConfig.weaponClasses.OTHER
end

---@param classId integer?
---@return string
local function getCauseLabel(classId)
    local key = triageConfig.causeLocaleKeys[classId] or 'cause.none'
    local label = locale(key)
    if label == key then return locale('cause.none') end
    return label
end

---@param injuries table
---@return integer? dominantClass, integer maxSeverity, boolean hasInjury
local function analyzeInjuryCauses(injuries)
    local maxSeverity = 0
    local hasInjury = false
    local dominantClass
    local dominantPriority = -1

    for _, injury in pairs(injuries) do
        if injury then
            hasInjury = true
            local severity = injury.severity or 0
            maxSeverity = math.max(maxSeverity, severity)

            local class = getWeaponClass(injury.weaponHash)
            local priority = triageConfig.classPriority[class] or 0
            if priority >= dominantPriority then
                dominantPriority = priority
                dominantClass = class
            end
        end
    end

    return dominantClass, maxSeverity, hasInjury
end

---@param treatment string
---@param bleedLevel integer
---@param maxSeverity integer
---@return string
local function applySeverityModifiers(treatment, bleedLevel, maxSeverity)
    if treatment == 'help' or treatment == 'revive' or treatment == 'none' then
        return treatment
    end

    local upgrade = triageConfig.upgradeToRepair
    if treatment == 'treat'
        and (bleedLevel >= upgrade.minBleed or maxSeverity >= upgrade.minSeverity)
    then
        return 'repair'
    end

    local downgrade = triageConfig.downgradeToTreat
    if treatment == 'repair'
        and bleedLevel <= downgrade.maxBleed
        and maxSeverity <= downgrade.maxSeverity
    then
        return 'treat'
    end

    return treatment
end

---@param state StateBag
---@return string treatment, string label, integer? dominantClass, integer bleedLevel, integer maxSeverity
local function determineFromState(state)
    local deathState = state[DEATH_STATE_STATE_BAG] or sharedConfig.deathState.ALIVE
    local bleedLevel = state[BLEED_LEVEL_STATE_BAG] or 0
    local injuries = getInjuries(state)
    local dominantClass, maxSeverity, hasInjury = analyzeInjuryCauses(injuries)

    if deathState == sharedConfig.deathState.DEAD then
        return 'revive', treatmentLabel('revive'), dominantClass, bleedLevel, maxSeverity
    end

    if deathState == sharedConfig.deathState.LAST_STAND then
        if dominantClass == triageConfig.weaponClasses.SUFFOCATING then
            return 'help', treatmentLabel('help'), dominantClass, bleedLevel, maxSeverity
        end
        return 'help', treatmentLabel('help'), dominantClass, bleedLevel, maxSeverity
    end

    if not hasInjury and bleedLevel <= 0 then
        return 'none', treatmentLabel('none'), dominantClass, bleedLevel, maxSeverity
    end

    local treatment = triageConfig.weaponClassTreatment[dominantClass or triageConfig.weaponClasses.NONE] or 'treat'
    treatment = applySeverityModifiers(treatment, bleedLevel, maxSeverity)

    return treatment, treatmentLabel(treatment), dominantClass, bleedLevel, maxSeverity
end

---@param treatment string
---@param bleedLevel integer
---@param maxSeverity integer
---@return integer durationMs, string progressKey
local function getCheckInProgress(treatment, bleedLevel, maxSeverity)
    local base = triageConfig.checkInDuration[treatment] or triageConfig.checkInDuration.treat
    local severityBonus = math.max(0, maxSeverity - 1) * triageConfig.severityDurationBonus
    local bleedBonus = bleedLevel * triageConfig.bleedDurationBonus
    local duration = base + severityBonus + bleedBonus

    local progressKey = ('progress.checkin_%s'):format(treatment)
    if locale(progressKey) == progressKey then
        progressKey = 'progress.checking_in'
    end

    return duration, progressKey
end

---@param targetSrc number
---@return string treatment, string label
function Triage.determineRequired(targetSrc)
    local treatment, label = determineFromState(Player(targetSrc).state)
    return treatment, label
end

---@param targetSrc number
---@return table
function Triage.getPatientSummary(targetSrc)
    local treatment, label, dominantClass, bleedLevel, maxSeverity = determineFromState(Player(targetSrc).state)
    local duration, progressKey = getCheckInProgress(treatment, bleedLevel, maxSeverity)

    return {
        treatment = treatment,
        label = label,
        dominantClass = dominantClass,
        causeLabel = getCauseLabel(dominantClass),
        bleedLevel = bleedLevel,
        maxSeverity = maxSeverity,
        checkInDuration = duration,
        checkInProgressKey = progressKey,
    }
end

---@param medicSrc number
---@param patientSrc number
---@return string treatment, string label
function Triage.record(medicSrc, patientSrc)
    local treatment, label = Triage.determineRequired(patientSrc)
    records[medicSrc] = records[medicSrc] or {}
    records[medicSrc][patientSrc] = {
        treatment = treatment,
        label = label,
        assessedAt = os.time(),
    }
    return treatment, label
end

---@param medicSrc number
---@param patientSrc number
function Triage.clear(medicSrc, patientSrc)
    if not records[medicSrc] then return end
    records[medicSrc][patientSrc] = nil
end

---@param medicSrc number
---@param patientSrc number
---@return boolean
function Triage.hasRecentAssessment(medicSrc, patientSrc)
    local row = records[medicSrc] and records[medicSrc][patientSrc]
    if not row then return false end
    return (os.time() - row.assessedAt) <= ASSESS_TTL
end

---@param medicSrc number
---@param patientSrc number
---@param attempted string
---@return boolean ok, string? errKey, string? needed, string? neededLabel
function Triage.validate(medicSrc, patientSrc, attempted)
    if not Triage.hasRecentAssessment(medicSrc, patientSrc) then
        return false, 'assessment_required', nil, nil
    end

    local needed, neededLabel = Triage.determineRequired(patientSrc)

    if needed == 'none' then
        Triage.clear(medicSrc, patientSrc)
        return false, 'patient_now_stable', nil, nil
    end

    if needed ~= attempted then
        return false, 'wrong_treatment', needed, neededLabel
    end

    return true, nil, needed, neededLabel
end

---@param medicSrc number
---@param patientSrc number
---@param attempted string
---@return boolean
function Triage.notifyValidation(medicSrc, patientSrc, attempted)
    local ok, errKey, needed, neededLabel = Triage.validate(medicSrc, patientSrc, attempted)
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

lib.callback.register('w2f-ambulance:cb:assessPatient', function(medicSrc, patientSrc)
    if not exports.qbx_core:GetPlayer(patientSrc) then
        return { ok = false }
    end

    local treatment, label = Triage.record(medicSrc, patientSrc)
    local status = exports[resource]:GetPlayerStatus(patientSrc)
    local summary = Triage.getPatientSummary(patientSrc)

    return {
        ok = true,
        treatment = treatment,
        label = label,
        status = status,
        cause = summary.dominantClass,
        causeLabel = summary.causeLabel,
    }
end)

lib.callback.register('w2f-ambulance:cb:validateCare', function(medicSrc, patientSrc, attempted)
    local ok, errKey, needed, neededLabel = Triage.validate(medicSrc, patientSrc, attempted)
    return {
        ok = ok,
        err = errKey,
        needed = needed,
        neededLabel = neededLabel,
    }
end)

lib.callback.register('w2f-ambulance:cb:getCheckInDetails', function(_, hospitalName)
    local src = source
    local summary = Triage.getPatientSummary(src)
    return {
        treatment = summary.treatment,
        label = summary.label,
        causeLabel = summary.causeLabel,
        duration = summary.checkInDuration,
        progressKey = summary.checkInProgressKey,
        bleedLevel = summary.bleedLevel,
        maxSeverity = summary.maxSeverity,
        hospitalName = hospitalName,
    }
end)
