W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Radial = W2FAmbulance.Radial or {}

local Radial = W2FAmbulance.Radial
local UI = W2FAmbulance.UI
local Client = W2FAmbulance.Client

local lastStatusCode = '10-8'
local radialCfg = Config.Systems and Config.Systems.Radial or {}
local patientStatusCfg = radialCfg.PatientStatus or {}
local activePatientStatus

local EMS_STATUS_CODES = {
    { id = 'ems_status_108', code = '10-8', title = 'Available', description = 'Broadcast 10-8 · In Service' },
    { id = 'ems_status_176', code = '10-76', title = 'En Route', description = 'Broadcast 10-76 · En Route to call' },
    { id = 'ems_status_123', code = '10-23', title = 'On Scene', description = 'Broadcast 10-23 · On Scene' },
    { id = 'ems_status_transport', code = 'Code 2', title = 'Transporting', description = 'Broadcast Code 2 · Patient transport' },
    { id = 'ems_status_hospital', code = 'Code 3', title = 'At Hospital', description = 'Broadcast Code 3 · Arrived at hospital' },
    { id = 'ems_status_busy', code = '10-6', title = 'Busy', description = 'Broadcast 10-6 · Busy with patient' },
    { id = 'ems_status_oos', code = '10-7', title = 'Out of Service', description = 'Broadcast 10-7 · Out of service' },
}

local function bind(id, fn)
    UI.Radial.SetHandler(id, fn)
end

---@param permission? string
---@return boolean
local function isLocked(permission)
    return permission ~= nil and not Client.hasPermission(permission)
end

---@param id string
---@param title string
---@param icon string
---@param description string
---@param permission? string
---@param extra? table
---@return table
local function careOption(id, title, icon, description, permission, extra)
    local opt = {
        id = id,
        title = title,
        icon = icon,
        description = description,
    }
    if extra then
        for key, value in pairs(extra) do
            opt[key] = value
        end
    end
    if permission and isLocked(permission) then
        opt.locked = true
        opt.permission = permission
    end
    return opt
end

local function requireOnDuty()
    if Client.isEmsOnDuty() then return true end
    exports.qbx_core:Notify('You must be on duty to use EMS tools.', 'error')
    return false
end

---@param permission? string
---@param fn fun()
local function bindCare(permission, fn)
    return function()
        if permission and isLocked(permission) then
            Client.notifyRankDenied(permission)
            return
        end
        if not requireOnDuty() then return end
        fn()
    end
end

local function patientOptions()
    return {
        careOption(
            'ems_status_check',
            'Check Patient Status',
            'heart-pulse',
            'Triage assessment of nearest patient',
            'CheckPatientStatus'
        ),
        careOption('ems_treat', 'Quick Treat', 'bandage', 'Bandage nearest patient', 'TreatWounds'),
        careOption('ems_revive', 'Revive', 'briefcase-medical', 'Revive with first aid kit', 'RevivePatient'),
        careOption('ems_bed', 'Place in Bed', 'bed-pulse', 'Place nearest patient in closest open bed', 'PutPatientInBed'),
    }
end
local function mapTreatmentLabel(required)
    local map = { treat = 'Treat Wounds', repair = 'Stabilize Trauma', stabilize = 'Stabilize Trauma', help = 'Assist Breathing', revive = 'Start CPR', none = 'Further Assessment Required' }
    return map[required] or 'Further Assessment Required'
end

function Radial.BuildPatientStatusMenu(patientStatus)
    local required = patientStatus and patientStatus.requiredTreatment or 'treat'
    local menus = {
        treat = {
            careOption('ems_ps_treat', 'Treat Wounds', 'bandage', 'Treat wounds and minor trauma', 'TreatWounds'),
            careOption('ems_ps_bandage', 'Bandage Patient', 'kit-medical', 'Apply bandages to stop bleeding', 'TreatWounds'),
            careOption('ems_ps_rx', 'Issue Prescription', 'file-prescription', 'Provide medication prescription', 'IssuePrescription'),
        },
        repair = {
            careOption('ems_ps_stabilize', 'Stabilize Trauma', 'kit-medical', 'Advanced trauma stabilization', 'TreatWounds'),
            careOption('ems_ps_ifak', 'Apply IFAK', 'briefcase-medical', 'Use IFAK kit for major trauma', 'TreatWounds'),
            careOption('ems_ps_load', 'Load Into Ambulance', 'truck-medical', 'Prepare transport', 'PutPatientInBed'),
        },
        help = {
            careOption('ems_ps_assist', 'Assist Breathing', 'lungs', 'Provide breathing support', 'TreatWounds'),
            careOption('ems_ps_support', 'Support Patient', 'hand-holding-medical', 'Support care on-scene', 'TreatWounds'),
            careOption('ems_ps_transport', 'Transport Patient', 'truck-medical', 'Transport recommended', 'PutPatientInBed'),
        },
        revive = {
            careOption('ems_ps_cpr', 'Start CPR', 'heart-pulse', 'Begin CPR immediately', 'RevivePatient'),
            careOption('ems_ps_revive', 'Revive Patient', 'briefcase-medical', 'Use first aid to revive', 'RevivePatient'),
            careOption('ems_ps_stabilize_revive', 'Stabilize Before Transport', 'kit-medical', 'Stabilize critical trauma', 'TreatWounds'),
        },
    }
    local options = menus[required] or menus.treat
    options[#options + 1] = { id = 'ems_ps_back', title = 'Back', icon = 'arrow-rotate-left', description = 'Return to patient care', submenu = 'ems_patient' }
    return { id = 'ems_patient_status', title = 'Patient Status', back = 'ems_patient', options = options }
end

function Radial.ClearPatientStatus()
    activePatientStatus = nil
    UI.Radial.ClearPatientStatus()
end

function Radial.OnTreatmentComplete(result)
    if not activePatientStatus then return end
    if result and result.success then
        activePatientStatus.treated = true
        UI.Radial.MarkPatientTreated(result)
        if patientStatusCfg.AutoReturnAfterTreatment ~= false then
            CreateThread(function()
                Wait(patientStatusCfg.ReturnDelayMs or 1500)
                Radial.ClearPatientStatus()
                UI.Radial.Navigate('ems_patient', true)
            end)
        end
    else
        SendNUIMessage({ action = 'radial:patientStatusError', data = { message = (result and result.reason) or 'Treatment Failed' } })
    end
end

local function statusOptions()
    local opts = {}
    for i = 1, #EMS_STATUS_CODES do
        local entry = EMS_STATUS_CODES[i]
        opts[#opts + 1] = {
            id = entry.id,
            title = entry.title,
            icon = 'tower-broadcast',
            description = entry.description,
            keepOpen = true,
        }
    end
    return opts
end

local function dispatchOptions()
    local distress = {
        id = 'ems_distress',
        title = 'Unit Distress',
        icon = 'siren',
        description = 'Broadcast medic-down alert to all EMS',
        color = 'danger',
    }
    if isLocked('EmergencyBroadcast') then
        distress.locked = true
        distress.permission = 'EmergencyBroadcast'
    end
    return {
        { id = 'ems_status_menu', title = 'Unit Status', icon = 'tower-broadcast', description = 'Broadcast availability codes', submenu = 'ems_status' },
        distress,
        { id = 'ems_duty', title = 'Toggle Duty', icon = 'user-clock', description = 'Clock on or off duty' },
    }
end

local function broadcastStatus(code)
    TriggerServerEvent('w2f-ambulance:server:statusBroadcast', code)
    lastStatusCode = code
    if UI.Radial.IsOpen() then
        CreateThread(function()
            Wait(50)
            UI.Radial.refreshIdentity({ statusCode = code })
        end)
    end
end

function Radial.Register()
    UI.Radial.Register('ems_root', {
        id = 'ems_root',
        title = 'EMS Operations',
        options = {
            { id = 'ems_patient_menu', title = 'Patient Care', icon = 'heart-pulse', description = 'Assess, treat, and transport patients', submenu = 'ems_patient' },
            { id = 'ems_dispatch_menu', title = 'Dispatch', icon = 'tower-broadcast', description = 'Status codes, distress, and duty', submenu = 'ems_dispatch' },
        },
    })

    UI.Radial.Register('ems_patient', {
        id = 'ems_patient',
        title = 'Patient Care',
        back = 'ems_root',
        options = patientOptions(),
    })

    UI.Radial.Register('ems_dispatch', {
        id = 'ems_dispatch',
        title = 'Dispatch',
        back = 'ems_root',
        options = dispatchOptions(),
    })

    UI.Radial.Register('ems_status', {
        id = 'ems_status',
        title = 'Unit Status',
        back = 'ems_dispatch',
        options = statusOptions(),
    })

    function Radial.CheckPatientStatus()
        if patientStatusCfg.Enabled == false then
            TriggerEvent('hospital:client:CheckStatus')
            return
        end
        local player = lib.getClosestPlayer(GetEntityCoords(cache.ped), patientStatusCfg.PatientScanDistance or 3.0, false)
        if not player then
            SendNUIMessage({ action = 'radial:patientStatusError', data = { message = 'No Patient Found. Move closer to a patient.' } })
            return
        end
        local patientServerId = GetPlayerServerId(player)
        local result = lib.callback.await('w2f-ambulance:cb:radialPatientStatus', false, patientServerId)
        if not result or not result.ok then
            SendNUIMessage({ action = 'radial:patientStatusError', data = { message = result and result.message or 'Unable to scan patient.' } })
            return
        end
        local p = result.patientStatus or {}
        p.active = true
        p.patientName = (patientStatusCfg.ShowPatientName == false and 'Unknown Patient') or p.patientName or 'Unknown Patient'
        p.recommendedTreatment = p.recommendedTreatment or mapTreatmentLabel(p.requiredTreatment)
        activePatientStatus = p
        local menu = Radial.BuildPatientStatusMenu(p)
        UI.Radial.Register('ems_patient_status', menu)
        UI.Radial.Navigate('ems_patient_status')
        UI.Radial.OpenPatientStatus(p, menu)
    end

    bind('ems_status_check', bindCare('CheckPatientStatus', function() Radial.CheckPatientStatus() end))

    bind('ems_treat', bindCare('TreatWounds', function()
        TriggerEvent('hospital:client:TreatWounds')
    end))

    bind('ems_stabilize', bindCare('TreatWounds', function() TriggerEvent('hospital:client:StabilizePatient') end))
    bind('ems_assist', bindCare('TreatWounds', function() TriggerEvent('hospital:client:AssistPatient') end))

    bind('ems_revive', bindCare('RevivePatient', function()
        TriggerEvent('hospital:client:RevivePlayer')
    end))

    bind('ems_rx', bindCare('IssuePrescription', function()
        if not Client.hasPrescriptionPad() then
            exports.qbx_core:Notify('You need a prescription pad to issue prescriptions.', 'error')
            return
        end
        TriggerEvent('w2f-ambulance:client:issuePrescriptionNearest')
    end))

    bind('ems_bed', bindCare('PutPatientInBed', function()
        if W2FAmbulance.HospitalClient and W2FAmbulance.HospitalClient.putNearestPatientInBed then
            W2FAmbulance.HospitalClient.putNearestPatientInBed()
        end
    end))
    bind('ems_ps_treat', bindCare('TreatWounds', function() TriggerEvent('hospital:client:TreatWounds') end))
    bind('ems_ps_bandage', bindCare('TreatWounds', function() TriggerEvent('hospital:client:TreatWounds') end))
    bind('ems_ps_rx', bindCare('IssuePrescription', function() TriggerEvent('w2f-ambulance:client:issuePrescriptionNearest') end))
    bind('ems_ps_stabilize', bindCare('TreatWounds', function() TriggerEvent('hospital:client:StabilizePatient') end))
    bind('ems_ps_ifak', bindCare('TreatWounds', function() TriggerEvent('hospital:client:StabilizePatient') end))
    bind('ems_ps_assist', bindCare('TreatWounds', function() TriggerEvent('hospital:client:AssistPatient') end))
    bind('ems_ps_support', bindCare('TreatWounds', function() TriggerEvent('hospital:client:AssistPatient') end))
    bind('ems_ps_cpr', bindCare('RevivePatient', function() TriggerEvent('hospital:client:RevivePlayer') end))
    bind('ems_ps_revive', bindCare('RevivePatient', function() TriggerEvent('hospital:client:RevivePlayer') end))
    bind('ems_ps_stabilize_revive', bindCare('TreatWounds', function() TriggerEvent('hospital:client:StabilizePatient') end))

    for i = 1, #EMS_STATUS_CODES do
        local entry = EMS_STATUS_CODES[i]
        bind(entry.id, bindCare(nil, function()
            broadcastStatus(entry.code)
        end))
    end

    bind('ems_distress', bindCare('EmergencyBroadcast', function()
        TriggerServerEvent('hospital:server:emergencyAlert')
    end))

    bind('ems_duty', function()
        TriggerServerEvent('QBCore:ToggleDuty')
        TriggerServerEvent(W2FAmbulance.Constants.Events.RefreshDutyBlips)
        CreateThread(function()
            Wait(350)
            UI.Radial.refreshIdentity()
        end)
    end)
end

function Radial.Open()
    if not QBX or not QBX.PlayerData or QBX.PlayerData.job.type ~= 'ems' then
        exports.qbx_core:Notify(locale('error.not_ems'), 'error')
        return
    end
    if UI.Radial.IsOpen() then
        UI.Radial.Close()
        return
    end
    UI.Radial.Open('ems_root', {
        statusCode = lastStatusCode,
    })
end

RegisterNetEvent('w2f-ambulance:client:statusUpdate', function(payload)
    if not payload then return end
    if payload.from == cache.serverId then return end
    exports.qbx_core:Notify(
        ('%s — %s [%s]'):format(payload.callsign or '?', payload.label or '', payload.code or ''),
        'inform'
    )
end)

RegisterNetEvent('w2f-ambulance:client:patientTreatmentResult', function(result)
    Radial.OnTreatmentComplete(result or {})
end)

CreateThread(function()
    Wait(1500)
    Radial.Register()
end)

RegisterNetEvent(W2FAmbulance.Constants.Events.OpenRadial, function()
    Radial.Open()
end)

local cmd = radialCfg.Command or 'emsradial'
RegisterCommand(cmd, function() Radial.Open() end, false)
RegisterKeyMapping(cmd, 'Open EMS radial menu', 'keyboard', radialCfg.Key or 'F6')

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    Wait(250)
    Radial.Register()
end)

RegisterNetEvent('QBCore:Client:SetDuty', function()
    Wait(250)
    Radial.Register()
end)
