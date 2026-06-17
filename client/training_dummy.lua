W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.TrainingDummyClient = W2FAmbulance.TrainingDummyClient or {}

local DummyClient = W2FAmbulance.TrainingDummyClient
local cfg = Config.TrainingDummy or {}

local function notifyDenied(permission)
    W2FAmbulance.Client.notifyRankDenied(permission)
end

function DummyClient.validateCare(objectId, attempted)
    local result = lib.callback.await('w2f-ambulance:cb:validateDummyCare', false, objectId, attempted)
    if not result or result.ok then return true end

    if result.err == 'assessment_required' then
        exports.qbx_core:Notify(locale('error.assessment_required'), 'error')
    elseif result.err == 'patient_now_stable' then
        exports.qbx_core:Notify(locale('error.patient_now_stable'), 'error')
    elseif result.err == 'wrong_treatment' then
        local hintKey = ('error.triage_wrong_%s'):format(attempted)
        local hint = locale(hintKey, result.neededLabel or '')
        if hint == hintKey then
            exports.qbx_core:Notify(locale('error.wrong_treatment', result.neededLabel or ''), 'error')
        else
            exports.qbx_core:Notify(hint, 'error')
        end
    end

    return false
end

function DummyClient.showAssessment(objectId)
    local result = lib.callback.await('w2f-ambulance:cb:assessDummy', false, objectId)
    if not result or not result.ok then
        exports.qbx_core:Notify(locale('error.dummy_unavailable'), 'error')
        return
    end

    W2FAmbulance.TriageClient.printStatusDetails(result.status)

    if result.treatment == 'none' then
        exports.qbx_core:Notify(locale('success.healthy_player'), 'success')
        return
    end

    exports.qbx_core:Notify(locale('info.triage_required', result.label), 'inform', 9000)
    TriggerEvent('chat:addMessage', {
        color = { 45, 212, 191 },
        multiline = false,
        args = { locale('info.status'), locale('info.triage_order', result.label) }
    })
end

local function runMinigame(scenarioId, itemName)
    local success, cancelled = W2FAmbulance.Minigame.run(scenarioId, { useAnim = true })
    if success then return true end
    W2FAmbulance.CareClient.handleMinigameResult(scenarioId, success, cancelled, itemName)
    if cancelled then
        exports.qbx_core:Notify(locale('error.canceled'), 'error')
    else
        exports.qbx_core:Notify(locale('error.minigame_failed'), 'error')
    end
    return false
end

local function performDummyCare(objectId, scenarioId, permission, itemName)
    if not W2FAmbulance.Client.hasPermission(permission) then
        notifyDenied(permission)
        return
    end

    if itemName and exports.ox_inventory:Search('count', itemName) <= 0 then
        local errKey = itemName == 'ifaks' and 'error.no_ifaks' or ('error.no_' .. itemName)
        exports.qbx_core:Notify(locale(errKey), 'error')
        return
    end

    if not DummyClient.validateCare(objectId, scenarioId) then return end
    if not runMinigame(scenarioId, itemName) then return end

    TriggerServerEvent('w2f-ambulance:server:applyDummyCare', objectId, scenarioId)
end

local function checkDummyStatus(objectId)
    if not W2FAmbulance.Client.hasPermission('CheckPatientStatus') then
        notifyDenied('CheckPatientStatus')
        return
    end

    if not runMinigame('checkStatus') then return end
    DummyClient.showAssessment(objectId)
end

local function canInteractEms()
    return QBX
        and QBX.PlayerData
        and QBX.PlayerData.job
        and QBX.PlayerData.job.type == 'ems'
        and QBX.PlayerData.job.onduty
end

local function buildOptions(objectId, pickupEnabled)
    local options = {
        {
            name = 'w2f_dummy_status_' .. objectId,
            icon = 'fa-solid fa-heart-pulse',
            label = locale('target.dummy_check_status'),
            distance = 2.5,
            groups = 'ambulance',
            canInteract = canInteractEms,
            onSelect = function() checkDummyStatus(objectId) end,
        },
        {
            name = 'w2f_dummy_treat_' .. objectId,
            icon = 'fa-solid fa-bandage',
            label = locale('target.dummy_treat'),
            distance = 2.5,
            groups = 'ambulance',
            canInteract = canInteractEms,
            onSelect = function() performDummyCare(objectId, 'treat', 'TreatWounds', 'bandage') end,
        },
        {
            name = 'w2f_dummy_repair_' .. objectId,
            icon = 'fa-solid fa-kit-medical',
            label = locale('target.dummy_stabilize'),
            distance = 2.5,
            groups = 'ambulance',
            canInteract = canInteractEms,
            onSelect = function() performDummyCare(objectId, 'repair', 'TreatWounds', 'ifaks') end,
        },
        {
            name = 'w2f_dummy_help_' .. objectId,
            icon = 'fa-solid fa-hand-holding-medical',
            label = locale('target.dummy_assist'),
            distance = 2.5,
            groups = 'ambulance',
            canInteract = canInteractEms,
            onSelect = function() performDummyCare(objectId, 'help', 'TreatWounds') end,
        },
        {
            name = 'w2f_dummy_revive_' .. objectId,
            icon = 'fa-solid fa-briefcase-medical',
            label = locale('target.dummy_revive'),
            distance = 2.5,
            groups = 'ambulance',
            canInteract = canInteractEms,
            onSelect = function() performDummyCare(objectId, 'revive', 'RevivePatient', 'firstaid') end,
        },
    }

    if pickupEnabled ~= false then
        options[#options + 1] = {
            name = 'w2f_ambulance_pickup_' .. objectId,
            icon = 'fa-solid fa-hand',
            label = locale('target.dummy_pickup'),
            distance = 2.5,
            groups = 'ambulance',
            canInteract = canInteractEms,
            onSelect = function()
                TriggerServerEvent('w2f-ambulance:server:pickupObject', objectId)
            end,
        }
    end

    return options
end

function DummyClient.attachTarget(entity, payload)
    if not entity or entity == 0 or not payload or payload.item ~= (cfg.ItemName or 'ems_training_dummy') then
        return
    end

    exports.ox_target:addLocalEntity(entity, buildOptions(payload.id, payload.pickupEnabled))
end

function DummyClient.detachTarget(entity, objectId)
    if not entity or entity == 0 then return end
    pcall(function()
        exports.ox_target:removeLocalEntity(entity, {
            'w2f_dummy_status_' .. objectId,
            'w2f_dummy_treat_' .. objectId,
            'w2f_dummy_repair_' .. objectId,
            'w2f_dummy_help_' .. objectId,
            'w2f_dummy_revive_' .. objectId,
            'w2f_ambulance_pickup_' .. objectId,
        })
    end)
end

function DummyClient.sphereOptions(objectId, pickupEnabled)
    return buildOptions(objectId, pickupEnabled)
end
