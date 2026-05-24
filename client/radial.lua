W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Radial = W2FAmbulance.Radial or {}

local Radial = W2FAmbulance.Radial
local UI = W2FAmbulance.UI
local Client = W2FAmbulance.Client

local lastStatusCode = '10-8'

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
            'Check Status',
            'heart-pulse',
            'Triage assessment of nearest patient',
            'CheckPatientStatus'
        ),
        careOption('ems_treat', 'Treat Wounds', 'bandage', 'Bandage nearest patient', 'TreatWounds'),
        careOption('ems_stabilize', 'Stabilize', 'kit-medical', 'IFAK trauma stabilization', 'TreatWounds'),
        careOption('ems_assist', 'Assist', 'hand-holding-medical', 'Field assist nearest patient', 'TreatWounds'),
        careOption('ems_revive', 'Revive', 'briefcase-medical', 'Revive with first aid kit', 'RevivePatient'),
        careOption('ems_rx', 'Issue Rx', 'file-prescription', 'Write prescription for nearest patient', 'IssuePrescription'),
        careOption('ems_bed', 'Place in Bed', 'bed-pulse', 'Place nearest patient in closest open bed', 'PutPatientInBed'),
    }
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

    bind('ems_status_check', bindCare('CheckPatientStatus', function()
        TriggerEvent('hospital:client:CheckStatus')
    end))

    bind('ems_treat', bindCare('TreatWounds', function()
        TriggerEvent('hospital:client:TreatWounds')
    end))

    bind('ems_stabilize', bindCare('TreatWounds', function()
        TriggerEvent('hospital:client:StabilizePatient')
    end))

    bind('ems_assist', bindCare('TreatWounds', function()
        TriggerEvent('hospital:client:AssistPatient')
    end))

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

CreateThread(function()
    Wait(1500)
    Radial.Register()
end)

RegisterNetEvent(W2FAmbulance.Constants.Events.OpenRadial, function()
    Radial.Open()
end)

local radialCfg = Config.Systems and Config.Systems.Radial or {}
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
