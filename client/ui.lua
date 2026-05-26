W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.UI = W2FAmbulance.UI or {}

local UI = W2FAmbulance.UI
UI.Radial = UI.Radial or {}
UI.Equipment = UI.Equipment or {}
UI.Garage = UI.Garage or {}
UI.Tablet = UI.Tablet or {}
UI.Minigame = UI.Minigame or {}
UI.PublicRecords = UI.PublicRecords or {}

local radialMenus = {}
local radialHandlers = {}
local radialStack = {}
local radialIdentity = {}
local radialState = { open = false, root = nil, current = nil }
local radialPatientStatus = nil
local equipmentOpen = false
local equipmentKind = 'armory'
local garageOpen = false
local tabletOpen = false
local minigameOpen = false
local publicRecordsOpen = false
local garageCoords = nil
local garageKind = 'garage'

local function sendNUI(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function setFocus(focus, cursor, keepInput)
    SetNuiFocus(focus and true or false, cursor and true or false)
    SetNuiFocusKeepInput(keepInput and true or false)
end

local function stopTabletAnim()
    local animations = W2FAmbulance.Animations
    if animations and animations.StopTablet then
        animations.StopTablet()
    end
end

function UI.resetAll()
    equipmentOpen = false
    garageOpen = false
    tabletOpen = false
    if minigameOpen and W2FAmbulance.Minigame and W2FAmbulance.Minigame.forceStop then
        W2FAmbulance.Minigame.forceStop()
    end
    minigameOpen = false
    publicRecordsOpen = false
    radialState.open = false
    radialStack = {}
    stopTabletAnim()
    setFocus(false, false, false)
    sendNUI('ui:reset')
end

function UI.Radial.Register(id, menu)
    radialMenus[id] = menu
end

function UI.Radial.SetHandler(id, fn)
    radialHandlers[id] = fn
end

function UI.Radial.Open(rootId, opts)
    local menu = radialMenus[rootId]
    if not menu then return end
    radialStack = {}
    radialState.open = true
    radialState.root = rootId
    radialState.current = rootId
    radialPatientStatus = nil
    setFocus(true, true, true)
    sendNUI('radial:open', { menu = menu, root = rootId })
    local onDuty = W2FAmbulance.Client.isEmsOnDuty()
    local statusCode = opts and opts.statusCode or '10-8'
    radialIdentity = {
        dept = 'EMS',
        deptLabel = 'Emergency Medical Services',
        callsign = W2FAmbulance.Ranks.GetShort(W2FAmbulance.Client.getGrade()),
        rankLabel = W2FAmbulance.Client.getRankLabel(),
        statusCode = statusCode,
        statusLabel = onDuty and (statusCode .. ' · ON DUTY') or 'OFF DUTY',
        statusLevel = onDuty and 'active' or 'idle',
    }
    sendNUI('radial:identity', radialIdentity)
end

function UI.Radial.Close()
    if not radialState.open then return end
    radialState.open = false
    radialPatientStatus = nil
    radialStack = {}
    setFocus(false, false, false)
    sendNUI('radial:close')
end

function UI.Radial.OpenPatientStatus(patientStatus, menu)
    radialPatientStatus = patientStatus
    sendNUI('radial:patientStatusOpen', {
        patientStatus = patientStatus,
        menu = menu,
        identity = radialIdentity
    })
end

function UI.Radial.UpdatePatientStatus(patientStatus)
    radialPatientStatus = patientStatus
    sendNUI('radial:patientStatusUpdate', { patientStatus = patientStatus })
end

function UI.Radial.ClearPatientStatus()
    radialPatientStatus = nil
    sendNUI('radial:patientStatusClear')
end

function UI.Radial.MarkPatientTreated(result)
    sendNUI('radial:patientStatusTreated', result or {})
end

function UI.Radial.Navigate(menuId, skipStack)
    local menu = radialMenus[menuId]
    if not menu then return end
    if not skipStack and radialState.current and radialState.current ~= menuId then
        radialStack[#radialStack + 1] = radialState.current
    end
    radialState.current = menuId
    sendNUI('radial:navigate', { menu = menu, id = menuId, depth = #radialStack })
end

function UI.Radial.Back()
    if not radialState.open then return end
    local parentId = table.remove(radialStack)
    if not parentId then
        UI.Radial.Close()
        return
    end
    UI.Radial.Navigate(parentId, true)
end

function UI.Radial.IsOpen()
    return radialState.open == true
end

function UI.Radial.refreshIdentity(opts)
    if not radialState.open then return end
    local onDuty = W2FAmbulance.Client.isEmsOnDuty()
    local statusCode = (opts and opts.statusCode) or radialIdentity.statusCode or '10-8'
    radialIdentity.rankLabel = W2FAmbulance.Client.getRankLabel()
    radialIdentity.callsign = W2FAmbulance.Ranks.GetShort(W2FAmbulance.Client.getGrade())
    radialIdentity.statusCode = statusCode
    radialIdentity.statusLabel = onDuty and (statusCode .. ' · ON DUTY') or 'OFF DUTY'
    radialIdentity.statusLevel = onDuty and 'active' or 'idle'
    sendNUI('radial:identity', radialIdentity)
end

function UI.Equipment.Open(catalog, kind)
    equipmentOpen = true
    equipmentKind = kind or 'armory'
    setFocus(true, true, false)
    sendNUI('equipment:open', catalog)
end

function UI.Equipment.Close()
    if not equipmentOpen then return end
    equipmentOpen = false
    if not garageOpen and not tabletOpen and not radialState.open then setFocus(false, false, false) end
    sendNUI('equipment:close')
end

function UI.Garage.Open(catalog, coords, kind)
    garageOpen = true
    garageCoords = coords
    garageKind = kind or 'garage'
    setFocus(true, true, false)
    sendNUI('garage:open', catalog)
end

function UI.Garage.Close(releaseFocus)
    if not garageOpen then return end
    garageOpen = false
    garageCoords = nil
    if releaseFocus ~= false
        and not equipmentOpen
        and not tabletOpen
        and not radialState.open
    then
        setFocus(false, false, false)
    end
    sendNUI('garage:close')
end

function UI.Tablet.Open(dashboard)
    tabletOpen = true
    setFocus(true, true, false)
    sendNUI('tablet:open', dashboard)
end

function UI.Tablet.Close()
    if not tabletOpen then return end
    tabletOpen = false
    stopTabletAnim()
    if not equipmentOpen and not garageOpen and not radialState.open and not minigameOpen and not publicRecordsOpen then
        setFocus(false, false, false)
    end
    sendNUI('tablet:close')
end

function UI.PublicRecords.Open(payload)
    publicRecordsOpen = true
    setFocus(true, true, false)
    sendNUI('publicRecords:open', payload)
end

function UI.PublicRecords.Close()
    if not publicRecordsOpen then return end
    publicRecordsOpen = false
    if not equipmentOpen and not garageOpen and not tabletOpen and not radialState.open and not minigameOpen then
        setFocus(false, false, false)
    end
    sendNUI('publicRecords:close')
end

function UI.Minigame.Open(payload)
    minigameOpen = true
    setFocus(true, true, false)
    sendNUI('minigame:open', payload)
end

function UI.Minigame.Close()
    if not minigameOpen then return end
    minigameOpen = false
    if not equipmentOpen and not garageOpen and not tabletOpen and not radialState.open and not publicRecordsOpen then
        setFocus(false, false, false)
    end
    sendNUI('minigame:close')
end

RegisterNUICallback('equipmentClose', function(_, cb)
    UI.Equipment.Close()
    cb({ ok = true })
end)

RegisterNUICallback('equipmentTake', function(data, cb)
    local callback = equipmentKind == 'medCabinet'
        and W2FAmbulance.Constants.Callbacks.TakeMedCabinetItem
        or W2FAmbulance.Constants.Callbacks.TakeArmoryItem
    local result = lib.callback.await(callback, false, data and data.id)
    cb(result or { ok = false })
end)

RegisterNUICallback('garageClose', function(_, cb)
    UI.Garage.Close()
    cb({ ok = true })
end)

RegisterNUICallback('garagePreview', function(data, cb)
    local ok = false
    if W2FAmbulance.GaragePreview and W2FAmbulance.GaragePreview.StartPreview then
        ok = W2FAmbulance.GaragePreview.StartPreview(data and (data.id or data.model)) == true
    end
    if ok then
        UI.Garage.Close()
    end
    cb({ ok = ok })
end)

RegisterNUICallback('garageSpawn', function(data, cb)
    local ok = false
    if W2FAmbulance.GaragePreview and W2FAmbulance.GaragePreview.StartPreview then
        ok = W2FAmbulance.GaragePreview.StartPreview(data and (data.id or data.model)) == true
    end
    if ok then
        UI.Garage.Close()
    end
    cb({ ok = ok })
end)

RegisterNUICallback('tabletClose', function(_, cb)
    W2FAmbulance.TabletClient.close()
    cb({ ok = true })
end)

RegisterNUICallback('tabletRefresh', function(_, cb)
    local dashboard = lib.callback.await(W2FAmbulance.Constants.Callbacks.GetTabletDashboard, false)
    cb({ ok = dashboard ~= nil, data = dashboard })
end)

RegisterNUICallback('tabletHire', function(data, cb)
    local ok = lib.callback.await(W2FAmbulance.Constants.Callbacks.TabletHire, false, data)
    cb({ ok = ok == true })
end)

RegisterNUICallback('tabletFire', function(data, cb)
    local ok = lib.callback.await(W2FAmbulance.Constants.Callbacks.TabletFire, false, data)
    cb({ ok = ok == true })
end)

RegisterNUICallback('tabletSetGrade', function(data, cb)
    local ok = lib.callback.await(W2FAmbulance.Constants.Callbacks.TabletSetGrade, false, data)
    cb({ ok = ok == true })
end)

RegisterNUICallback('tabletAnnouncement', function(data, cb)
    local ok = lib.callback.await(W2FAmbulance.Constants.Callbacks.TabletPostAnnouncement, false, data)
    cb({ ok = ok == true })
end)

RegisterNUICallback('tabletSearchRecords', function(data, cb)
    local rows = lib.callback.await(W2FAmbulance.Constants.Callbacks.SearchRecords, false, data and (data.query or data.citizenid))
    cb(rows or { rows = {} })
end)

RegisterNUICallback('uiRadialSelect', function(data, cb)
    if data and data.locked then
        if data.permission then
            W2FAmbulance.Client.notifyRankDenied(data.permission)
        end
        cb({ ok = true })
        return
    end
    local id = data and data.id
    if id and radialHandlers[id] then radialHandlers[id]() end
    cb({ ok = true })
end)

RegisterNUICallback('uiRadialNavigate', function(data, cb)
    if data and data.id then UI.Radial.Navigate(data.id) end
    cb({ ok = true })
end)

RegisterNUICallback('uiRadialBack', function(_, cb)
    UI.Radial.Back()
    cb({ ok = true })
end)

RegisterNUICallback('tabletSearchPublicRecords', function(data, cb)
    local rows = lib.callback.await(W2FAmbulance.Constants.Callbacks.SearchPublicRecords, false, data and (data.query or data.citizenid))
    cb(rows or { rows = {} })
end)

RegisterNUICallback('tabletSearchCitizens', function(data, cb)
    local rows = lib.callback.await(W2FAmbulance.Constants.Callbacks.SearchCitizens, false, data or {})
    cb({ ok = true, rows = rows or {} })
end)

RegisterNUICallback('tabletGetLogs', function(data, cb)
    local rows = lib.callback.await(W2FAmbulance.Constants.Callbacks.GetAuditLogs, false, data or {})
    cb(rows or { rows = {} })
end)

RegisterNUICallback('tabletGetPatientFile', function(data, cb)
    local file = lib.callback.await(W2FAmbulance.Constants.Callbacks.GetPatientFile, false, data and data.citizenid)
    cb({ ok = file ~= nil, file = file })
end)

RegisterNUICallback('tabletAddClinicalNote', function(data, cb)
    local ok = lib.callback.await(W2FAmbulance.Constants.Callbacks.AddClinicalNote, false, data)
    cb({ ok = ok == true })
end)

RegisterNUICallback('tabletPublishPublicRecord', function(data, cb)
    local ok = lib.callback.await(W2FAmbulance.Constants.Callbacks.PublishPublicRecord, false, data)
    cb({ ok = ok == true })
end)

RegisterNUICallback('publicRecordsClose', function(_, cb)
    UI.PublicRecords.Close()
    cb({ ok = true })
end)

RegisterNUICallback('uiClose', function(_, cb)
    UI.resetAll()
    cb({ ok = true })
end)

RegisterNUICallback('uiEscape', function(_, cb)
    if radialState.open then
        UI.Radial.Back()
    else
        UI.resetAll()
    end
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if radialState.open or minigameOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 200, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

W2FAmbulance.UI = UI
