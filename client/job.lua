local config = require 'config.client'
local sharedConfig = require 'config.shared'

---Configures and spawns a vehicle and teleports player to the driver seat.
---@param data { vehicleName: string, coords: vector4}
local function takeOutVehicle(data)
    local netId = lib.callback.await('qbx_ambulancejob:server:spawnVehicle', false, data.vehicleName, data.coords)

    local veh = lib.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(netId) then
            return NetToVeh(netId)
        end
    end)

    SetVehicleEngineOn(veh, true, true, true)

    local settings = config.vehicleSettings[data.vehicleName]
    if not settings then return end

    if settings.extras then
        qbx.setVehicleExtras(veh, settings.extras)
    end

    if settings.livery then
        SetVehicleLivery(veh, settings.livery)
    end
end

---@param scenarioId string
---@param opts? { useAnim?: boolean }
---@return boolean success, boolean cancelled
local function runCareMinigame(scenarioId, opts)
    return W2FAmbulance.Minigame.run(scenarioId, opts)
end

---@param scenarioId string
---@param opts? { useAnim?: boolean, patientId?: number, onSuccess: fun() }
local function performPatientCare(scenarioId, opts)
    if opts.patientId and not W2FAmbulance.TriageClient.validateCare(opts.patientId, scenarioId) then
        return false
    end

    local success, cancelled = runCareMinigame(scenarioId, opts)
    if success then
        opts.onSuccess()
        return true
    end

    W2FAmbulance.CareClient.handleMinigameResult(scenarioId, success, cancelled, opts.item)

    if cancelled then
        exports.qbx_core:Notify(locale('error.canceled'), 'error')
    else
        exports.qbx_core:Notify(locale('error.minigame_failed'), 'error')
    end
    return false
end

---Show the garage spawn menu
---@param kind 'garage'|'air'
---@param coords vector4
local function showGarageMenu(kind, coords)
    W2FAmbulance.CatalogClient.openGarage(kind, coords)
end

---Check status of nearest player and recommend required care.
RegisterNetEvent('hospital:client:CheckStatus', function()
    if not W2FAmbulance.Client.hasPermission('CheckPatientStatus') then
        W2FAmbulance.Client.notifyRankDenied('CheckPatientStatus')
        return
    end

    local player = GetClosestPlayer()
    if not player then
        exports.qbx_core:Notify(locale('error.no_player'), 'error')
        return
    end

    local success, cancelled = runCareMinigame('checkStatus')
    if not success then
        if cancelled then
            exports.qbx_core:Notify(locale('error.canceled'), 'error')
        else
            exports.qbx_core:Notify(locale('error.minigame_failed'), 'error')
        end
        return
    end

    W2FAmbulance.TriageClient.showAssessment(GetPlayerServerId(player))
end)

---Use first aid on nearest player to revive them.
RegisterNetEvent('hospital:client:RevivePlayer', function()
    if not W2FAmbulance.Client.hasPermission('RevivePatient') then
        W2FAmbulance.Client.notifyRankDenied('RevivePatient')
        return
    end

    if exports.ox_inventory:Search('count', 'firstaid') <= 0 then
        exports.qbx_core:Notify(locale('error.no_firstaid'), 'error')
        return
    end

    local player = GetClosestPlayer()
    if not player then
        exports.qbx_core:Notify(locale('error.no_player'), 'error')
        return
    end

    local patientId = GetPlayerServerId(player)

    performPatientCare('revive', {
        useAnim = true,
        patientId = patientId,
        onSuccess = function()
            exports.qbx_core:Notify(locale('success.revived'), 'success')
            TriggerServerEvent('hospital:server:RevivePlayer', patientId)
        end,
    })
end)

---Use bandage on nearest player to treat their wounds.
RegisterNetEvent('hospital:client:TreatWounds', function()
    if not W2FAmbulance.Client.hasPermission('TreatWounds') then
        W2FAmbulance.Client.notifyRankDenied('TreatWounds')
        return
    end

    if exports.ox_inventory:Search('count', 'bandage') <= 0 then
        exports.qbx_core:Notify(locale('error.no_bandage'), 'error')
        return
    end

    local player = GetClosestPlayer()
    if not player then
        exports.qbx_core:Notify(locale('error.no_player'), 'error')
        return
    end

    local patientId = GetPlayerServerId(player)

    performPatientCare('treat', {
        useAnim = true,
        patientId = patientId,
        onSuccess = function()
            exports.qbx_core:Notify(locale('success.helped_player'), 'success')
            TriggerServerEvent('hospital:server:TreatWounds', patientId)
        end,
    })
end)

---Stabilize trauma on nearest patient (IFAK).
RegisterNetEvent('hospital:client:StabilizePatient', function()
    if not W2FAmbulance.Client.hasPermission('TreatWounds') then
        W2FAmbulance.Client.notifyRankDenied('TreatWounds')
        return
    end

    if exports.ox_inventory:Search('count', 'ifaks') <= 0 then
        exports.qbx_core:Notify(locale('error.no_ifaks'), 'error')
        return
    end

    local player = GetClosestPlayer()
    if not player then
        exports.qbx_core:Notify(locale('error.no_player'), 'error')
        return
    end

    local patientId = GetPlayerServerId(player)

    performPatientCare('repair', {
        useAnim = true,
        patientId = patientId,
        onSuccess = function()
            exports.qbx_core:Notify(locale('success.helped_player'), 'success')
            TriggerServerEvent('hospital:server:StabilizePatient', patientId)
        end,
    })
end)

---Assist a downed patient (no item consumed — field support).
RegisterNetEvent('hospital:client:AssistPatient', function()
    if not W2FAmbulance.Client.hasPermission('TreatWounds') then
        W2FAmbulance.Client.notifyRankDenied('TreatWounds')
        return
    end

    local player = GetClosestPlayer()
    if not player then
        exports.qbx_core:Notify(locale('error.no_player'), 'error')
        return
    end

    local patientId = GetPlayerServerId(player)

    performPatientCare('help', {
        useAnim = true,
        patientId = patientId,
        onSuccess = function()
            exports.qbx_core:Notify(locale('success.helped_player'), 'success')
            TriggerServerEvent('hospital:server:AssistPatient', patientId)
        end,
    })
end)

---@param stashNumber integer id of stash to open
local function openStash(stashNumber)
    if not QBX.PlayerData.job.onduty then return end
    if not W2FAmbulance.Client.hasPermission('UseStash') then
        W2FAmbulance.Client.notifyRankDenied('UseStash')
        return
    end
    exports.ox_inventory:openInventory('stash', sharedConfig.locations.stash[stashNumber].name)
end

---Opens the hospital armory.
---@param armoryId integer id of armory to open
---@param stashId integer id of armory to open
local function openArmory(armoryId, stashId)
    if not QBX.PlayerData.job.onduty then return end
    W2FAmbulance.CatalogClient.openArmory()
end

---Opens the trusted med cabinet (prescriptions & controlled meds).
local function openMedCabinet()
    if not QBX.PlayerData.job.onduty then return end
    W2FAmbulance.CatalogClient.openMedCabinet()
end

---Teleports the player with a fade in/out effect
---@param coords vector3 | vector4
local function teleportPlayerWithFade(coords)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do
        Wait(10)
    end

    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, false)
    if coords.w then
        SetEntityHeading(cache.ped, coords.w)
    end

    Wait(100)

    DoScreenFadeIn(1000)
end

---Teleports the player to main elevator
local function teleportToMainElevator()
    teleportPlayerWithFade(sharedConfig.locations.main[1])
end

---Teleports the player to roof elevator
local function teleportToRoofElevator()
    teleportPlayerWithFade(sharedConfig.locations.roof[1])
end

---Toggles the on duty status of the player.
local function toggleDuty()
    TriggerServerEvent('QBCore:ToggleDuty')
    TriggerServerEvent(W2FAmbulance.Constants.Events.RefreshDutyBlips)
end

---@param entry vector4|{ spawn: vector4, returnPoint?: vector3 }
---@return { spawn: vector4, returnPoint: vector3 }
local function normalizeGarageEntry(entry)
    if entry.spawn then
        local spawn = entry.spawn
        return {
            spawn = spawn,
            returnPoint = entry.returnPoint or vec3(spawn.x + 2.5, spawn.y, spawn.z),
        }
    end

    return {
        spawn = entry,
        returnPoint = vec3(entry.x + 2.5, entry.y, entry.z),
    }
end

---Creates spawn and return zones for EMS fleet vehicles.
---@param kind 'garage'|'air'
---@param entry vector4|{ spawn: vector4, returnPoint?: vector3 }
local function createGarage(kind, entry)
    local garage = normalizeGarageEntry(entry)
    local spawnCoords = garage.spawn
    local returnCoords = garage.returnPoint
    local spawnLabel = kind == 'air' and locale('text.heli_button') or locale('text.veh_button')
    local returnLabel = kind == 'air' and locale('text.heli_return_button') or locale('text.veh_return_button')

    lib.zones.sphere({
        coords = spawnCoords.xyz,
        radius = 2.5,
        debug = config.debugPoly,
        onEnter = function()
            if QBX.PlayerData.job.type == 'ems' and QBX.PlayerData.job.onduty and not cache.vehicle then
                if not (W2FAmbulance.GaragePreview and W2FAmbulance.GaragePreview.isActive and W2FAmbulance.GaragePreview.isActive()) then
                    lib.showTextUI(spawnLabel)
                end
            end
        end,
        onExit = function()
            local _, text = lib.isTextUIOpen()
            if text == spawnLabel then lib.hideTextUI() end
        end,
        inside = function()
            if W2FAmbulance.GaragePreview and W2FAmbulance.GaragePreview.isActive and W2FAmbulance.GaragePreview.isActive() then
                return
            end
            if QBX.PlayerData.job.type == 'ems' and QBX.PlayerData.job.onduty and not cache.vehicle and IsControlJustPressed(0, 38) then
                showGarageMenu(kind, spawnCoords)
            end
        end,
    })

    lib.zones.sphere({
        coords = returnCoords,
        radius = 3.0,
        debug = config.debugPoly,
        onEnter = function()
            if QBX.PlayerData.job.type == 'ems' and QBX.PlayerData.job.onduty and cache.vehicle then
                lib.showTextUI(returnLabel)
            end
        end,
        onExit = function()
            local _, text = lib.isTextUIOpen()
            if text == returnLabel then lib.hideTextUI() end
        end,
        inside = function()
            if QBX.PlayerData.job.type == 'ems' and QBX.PlayerData.job.onduty and cache.vehicle and IsControlJustPressed(0, 38) then
                DeleteEntity(cache.vehicle)
                exports.qbx_core:Notify(locale('success.garage_vehicle_stored'), 'success')
            end
        end,
    })
end

---Creates air and land garages to spawn vehicles at for EMS personnel
CreateThread(function()
    for _, entry in pairs(sharedConfig.locations.vehicle) do
        createGarage('garage', entry)
    end

    for _, entry in pairs(sharedConfig.locations.helicopter) do
        createGarage('air', entry)
    end
end)

---Sets up duty toggle, stash, armory, and elevator interactions using either target or zones.
if config.useTarget then
    CreateThread(function()
        for i = 1, #sharedConfig.locations.duty do
            exports.ox_target:addBoxZone({
                name = 'duty' .. i,
                coords = sharedConfig.locations.duty[i],
                size = vec3(1.5, 1, 2),
                rotation = 71,
                debug = config.debugPoly,
                canInteract = function()
                    return QBX.PlayerData.job.type == 'ems'
                end,
                options = {
                    {
                        icon = 'fa fa-clipboard',
                        label = locale('text.duty'),
                        onSelect = toggleDuty,
                        distance = 2,
                        groups = 'ambulance',
                    }
                }
            })
        end

        for i = 1, #sharedConfig.locations.stash do
            exports.ox_target:addBoxZone({
                name = 'stash' .. i,
                coords = sharedConfig.locations.stash[i].location,
                size = vec3(1, 1, 2),
                rotation = -20,
                debug = config.debugPoly,
                canInteract = function()
                    return QBX.PlayerData.job.type == 'ems'
                end,
                options = {
                    {
                        icon = 'fa fa-clipboard',
                        label = locale('text.pstash'),
                        onSelect = function()
                            openStash(i)
                        end,
                        distance = 2,
                        groups = 'ambulance',
                    }
                }
            })
        end

        for i = 1, #sharedConfig.locations.armory do
            for ii = 1, #sharedConfig.locations.armory[i].locations do
                exports.ox_target:addBoxZone({
                    name = 'armory' .. i .. ':' .. ii,
                    coords = sharedConfig.locations.armory[i].locations[ii],
                    size = vec3(1, 1, 2),
                    rotation = -20,
                    debug = config.debugPoly,
                    canInteract = function()
                        return QBX.PlayerData.job.type == 'ems'
                    end,
                    options = {
                        {
                            icon = 'fa fa-clipboard',
                            label = locale('text.armory'),
                            onSelect = function()
                                openArmory(i, ii)
                            end,
                            distance = 1.5,
                            groups = 'ambulance',
                        }
                    }
                })
            end
        end

        local medCabinets = sharedConfig.locations.medCabinet or {}
        for i = 1, #medCabinets do
            for ii = 1, #medCabinets[i].locations do
                exports.ox_target:addBoxZone({
                    name = 'medCabinet' .. i .. ':' .. ii,
                    coords = medCabinets[i].locations[ii],
                    size = vec3(1, 1, 2),
                    rotation = -20,
                    debug = config.debugPoly,
                    canInteract = function()
                        return QBX.PlayerData.job.type == 'ems'
                            and W2FAmbulance.Client.hasPermission('UseMedCabinet')
                    end,
                    options = {
                        {
                            icon = 'fa-solid fa-pills',
                            label = locale('text.med_cabinet'),
                            onSelect = openMedCabinet,
                            distance = 1.5,
                            groups = 'ambulance',
                        }
                    }
                })
            end
        end

        exports.ox_target:addBoxZone({
            name = 'roof1',
            coords = sharedConfig.locations.roof[1],
            size = vec3(1, 2, 2),
            rotation = -20,
            debug = config.debugPoly,
            options = {
                {
                    icon = 'fas fa-hand-point-down',
                    label = locale('text.el_main'),
                    onSelect = teleportToMainElevator,
                    distance = 1.5,
                    groups = 'ambulance',
                }
            }
        })

        exports.ox_target:addBoxZone({
            name = 'main1',
            coords = sharedConfig.locations.main[1],
            size = vec3(2, 1, 2),
            rotation = -20,
            debug = config.debugPoly,
            options = {
                {
                    icon = 'fas fa-hand-point-up',
                    label = locale('text.el_roof'),
                    onSelect = teleportToRoofElevator,
                    distance = 1.5,
                    groups = 'ambulance',
                }
            }
        })
    end)
else
    CreateThread(function()
        for i = 1, #sharedConfig.locations.duty do
            lib.zones.box({
                coords = sharedConfig.locations.duty[i],
                size = vec3(1, 1, 2),
                rotation = -20,
                debug = config.debugPoly,
                onEnter = function()
                    if QBX.PlayerData.job.type ~= 'ems' then return end
                    local label = QBX.PlayerData.job.onduty and locale('text.onduty_button') or locale('text.offduty_button')
                    lib.showTextUI(label)
                end,
                onExit = function()
                    local _, text = lib.isTextUIOpen()
                    if text == locale('text.onduty_button') or text == locale('text.offduty_button') then lib.hideTextUI() end
                end,
                inside = function()
                    if QBX.PlayerData.job.type ~= 'ems' then return end
                    OnKeyPress(toggleDuty)
                end,
            })
        end

        for i = 1, #sharedConfig.locations.stash do
            lib.zones.box({
                coords = sharedConfig.locations.stash[i].location,
                size = vec3(1, 1, 2),
                rotation = -20,
                debug = config.debugPoly,
                onEnter = function()
                    if QBX.PlayerData.job.type ~= 'ems' or not QBX.PlayerData.job.onduty then return end
                    lib.showTextUI(locale('text.pstash_button'))
                    end,
                onExit = function()
                    local _, text = lib.isTextUIOpen()
                    if text == locale('text.pstash_button') then lib.hideTextUI() end
                end,
                inside = function()
                    if QBX.PlayerData.job.type ~= 'ems' then return end
                    OnKeyPress(function()
                        openStash(i)
                    end)
                end,
            })
        end

        for i = 1, #sharedConfig.locations.armory do
            for ii = 1, #sharedConfig.locations.armory[i].locations do
                lib.zones.box({
                    coords = sharedConfig.locations.armory[i].locations[ii],
                    size = vec3(1, 1, 2),
                    rotation = -20,
                    debug = config.debugPoly,
                    onEnter = function()
                        if QBX.PlayerData.job.type ~= 'ems' or not QBX.PlayerData.job.onduty then return end
                        lib.showTextUI(locale('text.armory_button'))
                        end,
                    onExit = function()
                        local _, text = lib.isTextUIOpen()
                        if text == locale('text.armory_button') then lib.hideTextUI() end
                    end,
                    inside = function()
                        if QBX.PlayerData.job.type ~= 'ems' then return end
                        OnKeyPress(function()
                            openArmory(i, ii)
                        end)
                    end,
                })
            end
        end

        local medCabinets = sharedConfig.locations.medCabinet or {}
        for i = 1, #medCabinets do
            for ii = 1, #medCabinets[i].locations do
                lib.zones.box({
                    coords = medCabinets[i].locations[ii],
                    size = vec3(1, 1, 2),
                    rotation = -20,
                    debug = config.debugPoly,
                    onEnter = function()
                        if QBX.PlayerData.job.type ~= 'ems' or not QBX.PlayerData.job.onduty then return end
                        if not W2FAmbulance.Client.hasPermission('UseMedCabinet') then return end
                        lib.showTextUI(locale('text.med_cabinet_button'))
                    end,
                    onExit = function()
                        local _, text = lib.isTextUIOpen()
                        if text == locale('text.med_cabinet_button') then lib.hideTextUI() end
                    end,
                    inside = function()
                        if QBX.PlayerData.job.type ~= 'ems' then return end
                        OnKeyPress(openMedCabinet)
                    end,
                })
            end
        end

        lib.zones.box({
            coords = sharedConfig.locations.roof[1],
            size = vec3(1, 1, 2),
            rotation = -20,
            debug = config.debugPoly,
            onEnter = function()
                local label = QBX.PlayerData.job.onduty and locale('text.elevator_main') or locale('error.not_ems')
                lib.showTextUI(label)
            end,
            onExit = function()
                local _, text = lib.isTextUIOpen()
                if text == locale('text.elevator_main') or text == locale('error.not_ems') then lib.hideTextUI() end
            end,
            inside = function()
                OnKeyPress(teleportToMainElevator)
            end,
        })

        lib.zones.box({
            coords = sharedConfig.locations.main[1],
            size = vec3(1, 1, 2),
            rotation = -20,
            debug = config.debugPoly,
            onEnter = function()
                local label = QBX.PlayerData.job.onduty and locale('text.elevator_roof') or locale('error.not_ems')
                lib.showTextUI(label)
            end,
            onExit = function()
                local _, text = lib.isTextUIOpen()
                if text == locale('text.elevator_roof') or text == locale('error.not_ems') then lib.hideTextUI() end
            end,
            inside = function()
                OnKeyPress(teleportToRoofElevator)
            end,
        })
    end)
end
