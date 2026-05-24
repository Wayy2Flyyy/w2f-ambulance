local Placeables = W2FAmbulance.Placeables

local SpawnedEntities = {}
local SpawnedPayloads = {}
local SpawnedTargetZones = {}

local PlacementActive = false
local CurrentPreview = 0
local CurrentItemName = nil
local CurrentSlot = nil
local CurrentHeading = 0.0
local CurrentValid = true

local OUTLINE_VALID = { 90, 230, 140 }
local OUTLINE_INVALID = { 230, 70, 70 }

local CURSOR_LOOK_CONTROLS = { 1, 2, 3, 4, 5, 6, 220, 221, 135, 136, 0, 200, 199 }

local function normalizeVec3(v)
    local len = math.sqrt((v.x * v.x) + (v.y * v.y) + (v.z * v.z))
    if len < 0.0001 then return vec3(0.0, 0.0, 0.0) end
    return vec3(v.x / len, v.y / len, v.z / len)
end

local function getCamBasis()
    local rot = GetFinalRenderedCamRot(2)
    local rotX = math.rad(rot.x)
    local rotZ = math.rad(rot.z)
    local cosX = math.abs(math.cos(rotX))
    local forward = vec3(-math.sin(rotZ) * cosX, math.cos(rotZ) * cosX, math.sin(rotX))
    local right = normalizeVec3(vec3(forward.y, -forward.x, 0.0))
    local up = normalizeVec3(vec3(
        (right.y * forward.z) - (right.z * forward.y),
        (right.z * forward.x) - (right.x * forward.z),
        (right.x * forward.y) - (right.y * forward.x)
    ))
    return GetFinalRenderedCamCoord(), forward, right, up
end

local function getCursorScreenRay()
    local cursorX, cursorY = GetNuiCursorPosition()
    local resX, resY = GetActiveScreenResolution()
    if not resX or resX == 0 then resX = 1920 end
    if not resY or resY == 0 then resY = 1080 end
    cursorX = cursorX or (resX * 0.5)
    cursorY = cursorY or (resY * 0.5)

    local camPos, forward, right, up = getCamBasis()
    local fov = GetGameplayCamFov()
    local aspect = resX / resY
    local tanY = math.tan(math.rad(fov * 0.5))
    local tanX = tanY * aspect
    local nx = (cursorX / resX) * 2.0 - 1.0
    local ny = 1.0 - (cursorY / resY) * 2.0
    local direction = forward + (right * (nx * tanX)) + (up * (ny * tanY))
    return camPos, normalizeVec3(direction)
end

local function raycastFromCursor(maxDistance, ignoreEntity)
    local origin, direction = getCursorScreenRay()
    local destination = origin + (direction * maxDistance)
    local handle = StartShapeTestLosProbe(
        origin.x, origin.y, origin.z,
        destination.x, destination.y, destination.z,
        511, ignoreEntity or cache.ped, 4
    )

    while true do
        local retval, hit, endCoords = GetShapeTestResultIncludingMaterial(handle)
        if retval ~= 1 then
            if hit == 1 then
                return true, endCoords
            end
            return false, destination
        end
        Wait(0)
    end
end

local function setPlacementFocus(active)
    SetNuiFocus(active, active)
    if SetNuiFocusKeepInput then
        SetNuiFocusKeepInput(active)
    end
end

local function disableCursorLookControls()
    for i = 1, #CURSOR_LOOK_CONTROLS do
        DisableControlAction(0, CURSOR_LOOK_CONTROLS[i], true)
    end
end

local function notify(msg, nType)
    exports.qbx_core:Notify(msg, nType or 'inform')
end

local function showHints(label)
    if not lib or not lib.showTextUI then return end
    local placementCfg = Config.Placeables.Placement or {}
    local helpKey = placementCfg.UseCursor ~= false and 'info.placeable_cursor_help' or nil
    local help = helpKey and locale(helpKey) or '[E] Place  •  [Q / →] Rotate  •  [BACKSPACE] Cancel'
    lib.showTextUI(('%s  —  %s'):format(help, label or 'Item'), {
        position = 'top-center',
    })
end

local function hideHints()
    if lib and lib.hideTextUI then lib.hideTextUI() end
end

local function debugPrint(...)
    if not (Config.Placeables and Config.Placeables.Debug) then return end
    local parts = {}
    for i = 1, select('#', ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    print(('[w2f-ambulance][placeables] %s'):format(table.concat(parts, ' ')))
end

local function loadCustomStreamModel(modelName, timeout)
    local hash = type(modelName) == 'number' and modelName or joaat(modelName)
    if HasModelLoaded(hash) then return hash end

    local deadline = GetGameTimer() + timeout

    while not IsModelInCdimage(hash) and not IsModelValid(hash) and GetGameTimer() < deadline do
        Wait(100)
    end

    if not IsModelInCdimage(hash) and not IsModelValid(hash) then
        debugPrint('custom prop not registered:', modelName, hash)
        return nil
    end

    if lib and lib.requestModel then
        local ok, result = pcall(function()
            return lib.requestModel(hash, timeout)
        end)
        if ok and result then return hash end
        debugPrint('lib.requestModel failed:', modelName)
        return nil
    end

    RequestModel(hash)
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(0)
    end

    return HasModelLoaded(hash) and hash or nil
end

local function resolveModelName(modelName, itemName)
    return Placeables.ResolvePropModel(modelName, itemName)
end

local function loadModel(modelName, itemName)
    modelName = resolveModelName(modelName, itemName)
    local hash = type(modelName) == 'number' and modelName or joaat(modelName)
    local custom = itemName and Placeables.IsCustomProp(itemName) or false
    local timeout = custom and 15000 or 5000

    if custom then
        return loadCustomStreamModel(hash, timeout)
    end

    if not IsModelInCdimage(hash) and not IsModelValid(hash) then
        return nil
    end

    if lib and lib.requestModel then
        if not lib.requestModel(hash, timeout) then return nil end
    else
        RequestModel(hash)
        local deadline = GetGameTimer() + timeout
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do
            Wait(0)
        end
        if not HasModelLoaded(hash) then return nil end
    end

    return hash
end

local function safeDeleteEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

local function attachTarget(entity, payload)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    if payload.item == (Config.TrainingDummy and Config.TrainingDummy.ItemName or 'ems_training_dummy') then
        W2FAmbulance.TrainingDummyClient.attachTarget(entity, payload)
    elseif payload.pickupEnabled ~= false then
        local options = {
            {
                name = 'w2f_ambulance_pickup_' .. payload.id,
                icon = 'fa-solid fa-hand',
                label = 'Pick Up ' .. (payload.label or payload.item),
                distance = 2.5,
                groups = 'ambulance',
                onSelect = function()
                    TriggerServerEvent('w2f-ambulance:server:pickupObject', payload.id)
                end,
            },
        }
        exports.ox_target:addLocalEntity(entity, options)
    end

    if payload.coords and not SpawnedTargetZones[payload.id] then
        local zoneOptions = payload.item == (Config.TrainingDummy and Config.TrainingDummy.ItemName or 'ems_training_dummy')
            and W2FAmbulance.TrainingDummyClient.sphereOptions(payload.id, payload.pickupEnabled)
            or {
                {
                    name = 'w2f_ambulance_pickup_' .. payload.id,
                    icon = 'fa-solid fa-hand',
                    label = 'Pick Up ' .. (payload.label or payload.item),
                    distance = 2.5,
                    groups = 'ambulance',
                    onSelect = function()
                        TriggerServerEvent('w2f-ambulance:server:pickupObject', payload.id)
                    end,
                },
            }

        SpawnedTargetZones[payload.id] = exports.ox_target:addSphereZone({
            name = 'w2f_ambulance_placeable_' .. payload.id,
            coords = vec3(payload.coords.x, payload.coords.y, payload.coords.z + 0.5),
            radius = 1.5,
            debug = false,
            options = zoneOptions,
        })
    end
end

local function detachTarget(entity, objectId)
    local payload = SpawnedPayloads[objectId]
    if payload and payload.item == (Config.TrainingDummy and Config.TrainingDummy.ItemName or 'ems_training_dummy') then
        W2FAmbulance.TrainingDummyClient.detachTarget(entity, objectId)
    elseif entity and entity ~= 0 and DoesEntityExist(entity) then
        pcall(function()
            exports.ox_target:removeLocalEntity(entity, { 'w2f_ambulance_pickup_' .. objectId })
        end)
    end

    local zoneId = SpawnedTargetZones[objectId]
    if zoneId then
        pcall(function()
            exports.ox_target:removeZone(zoneId, true)
        end)
        SpawnedTargetZones[objectId] = nil
    end
end

local function spawnPlaced(payload)
    if not payload or not payload.id or SpawnedEntities[payload.id] then return end

    local hash = loadModel(payload.model, payload.item)
    if not hash then
        debugPrint('spawn failed, model did not load:', payload.model)
        return
    end

    local coords = payload.coords
    local zOff = payload.zOffset or 0.0
    local entity = CreateObject(hash, coords.x, coords.y, coords.z + zOff, false, true, false)
    if not entity or entity == 0 then
        debugPrint('CreateObject failed for', payload.model)
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityHeading(entity, payload.heading or 0.0)
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, Config.Placeables.Placement.FreezePlacedObjects ~= false)
    SetEntityCollision(entity, true, true)
    SetEntityInvincible(entity, true)
    SetEntityAsMissionEntity(entity, true, true)

    Wait(100)

    if not DoesEntityExist(entity) then
        debugPrint('entity vanished after spawn for', payload.id)
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SpawnedEntities[payload.id] = entity
    SpawnedPayloads[payload.id] = payload
    attachTarget(entity, payload)
    SetModelAsNoLongerNeeded(hash)
end

local function despawnPlaced(objectId)
    local entity = SpawnedEntities[objectId]
    detachTarget(entity, objectId)
    safeDeleteEntity(entity)
    SpawnedEntities[objectId] = nil
    SpawnedPayloads[objectId] = nil
end

local function checkValid(coords, maxDistanceFromPlayer)
    if Config.Placeables.Security and Config.Placeables.Security.BlockPlacementInWater then
        local foundWater, _waterHeight = GetWaterHeight(coords.x, coords.y, coords.z)
        if foundWater then return false end
    end

    if maxDistanceFromPlayer and maxDistanceFromPlayer > 0 then
        local pCoords = GetEntityCoords(cache.ped)
        if Placeables.DistanceSqr(pCoords, coords) > (maxDistanceFromPlayer * maxDistanceFromPlayer) then
            return false
        end
    end

    local minDist = (Config.Placeables.Limits and Config.Placeables.Limits.MinimumDistanceBetweenObjects) or 2.0
    local minSqr = minDist * minDist
    for _, payload in pairs(SpawnedPayloads) do
        local p = payload.coords
        if Placeables.DistanceSqr(coords, p) < minSqr then return false end
    end
    return true
end

local function getGroundCoords(x, y, z)
    if Config.Placeables.Placement.RequireGround == false then
        return vec3(x, y, z)
    end
    local ok, groundZ = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
    if ok then return vec3(x, y, groundZ) end
    return vec3(x, y, z)
end

local function endPlacement(cancelled)
    PlacementActive = false
    setPlacementFocus(false)
    hideHints()
    safeDeleteEntity(CurrentPreview)
    CurrentPreview = 0
    CurrentItemName = nil
    CurrentSlot = nil
    CurrentHeading = 0.0
    CurrentValid = true
    if cancelled then notify(locale('info.placeable_cancelled'), 'error') end
end

local function getCursorPlacementCoords(cfg, placement, previewEntity)
    local placementCfg = Config.Placeables.Placement or {}
    local rayDistance = placementCfg.CursorMaxRayDistance or placement.maxDistanceFromPlayer or 12.0
    local hit, hitCoords = raycastFromCursor(rayDistance, previewEntity or cache.ped)
    local base = hit and hitCoords or hitCoords
    local snapped = getGroundCoords(base.x, base.y, base.z)
    return vec3(
        snapped.x,
        snapped.y,
        snapped.z + (cfg.zOffset or 0.0) + (placement.heightOffset or 0.0)
    ), hit
end

local function getForwardPlacementCoords(cfg, placement, placeDist)
    local fwd = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, placeDist, 0.0)
    local snapped = getGroundCoords(fwd.x, fwd.y, fwd.z)
    return vec3(
        snapped.x,
        snapped.y,
        snapped.z + (cfg.zOffset or 0.0) + (placement.heightOffset or 0.0)
    )
end

local function startPlacement(itemName, slot)
    if PlacementActive or not Placeables.IsEnabled() then return end
    if not Placeables.IsPlaceableItem(itemName) then
        notify(locale('error.placeable_not_placeable'), 'error')
        return
    end

    local cfg = Placeables.GetConfig(itemName)
    local placement = Placeables.GetPlacement(itemName)

    if Config.Placeables.Placement.AllowInVehicle == false and cache.vehicle then
        notify(locale('error.placeable_in_vehicle'), 'error')
        return
    end

    local hash = loadModel(cfg.prop, itemName)
    if not hash then
        notify(locale('error.placeable_invalid_model'), 'error')
        return
    end

    local pCoords = GetEntityCoords(cache.ped)
    local entity = CreateObjectNoOffset(hash, pCoords.x, pCoords.y, pCoords.z, false, false, false)
    if not entity or entity == 0 then
        SetModelAsNoLongerNeeded(hash)
        notify(locale('error.placeable_invalid_model'), 'error')
        return
    end

    SetEntityAsMissionEntity(entity, true, true)
    SetEntityCollision(entity, false, false)
    SetEntityAlpha(entity, Config.Placeables.Placement.PreviewAlpha or 165, false)
    FreezeEntityPosition(entity, true)
    if Config.Placeables.Placement.UseOutlinePreview then
        SetEntityDrawOutline(entity, true)
        SetEntityDrawOutlineColor(OUTLINE_VALID[1], OUTLINE_VALID[2], OUTLINE_VALID[3], 200)
    end
    SetModelAsNoLongerNeeded(hash)

    PlacementActive = true
    CurrentPreview = entity
    CurrentItemName = itemName
    CurrentSlot = slot
    CurrentHeading = GetEntityHeading(cache.ped)
    CurrentValid = true

    local useCursor = Config.Placeables.Placement.UseCursor ~= false
    if useCursor then
        setPlacementFocus(true)
    end

    showHints(cfg.label or itemName)

    local controls = Config.Placeables.Controls
    local rotSpeed = placement.rotationSpeed
    local placeDist = placement.distance
    local maxPlayerDist = placement.maxDistanceFromPlayer

    CreateThread(function()
        while PlacementActive and CurrentPreview ~= 0 and DoesEntityExist(CurrentPreview) do
            disableCursorLookControls()

            DisableControlAction(0, controls.Place, true)
            DisableControlAction(0, controls.Cancel, true)
            if controls.CancelAlt then
                DisableControlAction(0, controls.CancelAlt, true)
            end
            DisableControlAction(0, controls.RotateLeft, true)
            DisableControlAction(0, controls.RotateRight, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            local finalCoords
            local hasGroundHit = true
            if useCursor then
                finalCoords, hasGroundHit = getCursorPlacementCoords(cfg, placement, CurrentPreview)
            else
                finalCoords = getForwardPlacementCoords(cfg, placement, placeDist)
            end

            SetEntityCoordsNoOffset(CurrentPreview, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false)
            SetEntityHeading(CurrentPreview, CurrentHeading)

            local valid = hasGroundHit and checkValid(finalCoords, maxPlayerDist)
            if valid ~= CurrentValid then
                CurrentValid = valid
                if Config.Placeables.Placement.UseOutlinePreview then
                    local c = valid and OUTLINE_VALID or OUTLINE_INVALID
                    SetEntityDrawOutlineColor(c[1], c[2], c[3], 220)
                end
            end

            if IsDisabledControlPressed(0, controls.RotateLeft) then
                CurrentHeading = Placeables.ClampHeading(CurrentHeading + rotSpeed)
            elseif IsDisabledControlPressed(0, controls.RotateRight) then
                CurrentHeading = Placeables.ClampHeading(CurrentHeading - rotSpeed)
            end

            local cancelled = IsDisabledControlJustReleased(0, controls.Cancel)
                or (controls.CancelAlt and IsDisabledControlJustReleased(0, controls.CancelAlt))

            if cancelled then
                endPlacement(true)
                break
            end

            if IsDisabledControlJustReleased(0, controls.Place) then
                if not CurrentValid then
                    notify(locale('error.placeable_invalid_ground'), 'error')
                else
                    local item = CurrentItemName
                    local slotVal = CurrentSlot
                    local heading = CurrentHeading
                    local cx, cy, cz = finalCoords.x, finalCoords.y, finalCoords.z
                    endPlacement(false)
                    TriggerServerEvent('w2f-ambulance:server:placeObject', {
                        item = item,
                        slot = slotVal,
                        coords = { x = cx, y = cy, z = cz },
                        heading = heading,
                    })
                    break
                end
            end

            Wait(0)
        end

        if PlacementActive then endPlacement(true) end
    end)
end

RegisterNetEvent('w2f-ambulance:client:startPlaceablePlacement', function(data)
    if type(data) ~= 'table' then return end
    local itemName = data.name
    local slot = tonumber(data.slot)
    if not itemName or not slot then
        notify(locale('error.placeable_not_placeable'), 'error')
        return
    end
    debugPrint('start placement', itemName, slot)
    if PlacementActive then
        endPlacement(true)
        Wait(50)
    end
    startPlacement(itemName, slot)
end)

RegisterNetEvent('w2f-ambulance:client:createPlacedObject', function(payload)
    if type(payload) ~= 'table' or not payload.id then return end
    CreateThread(function() spawnPlaced(payload) end)
end)

RegisterNetEvent('w2f-ambulance:client:removePlacedObject', function(objectId)
    if type(objectId) ~= 'string' then return end
    despawnPlaced(objectId)
end)

RegisterNetEvent('w2f-ambulance:client:syncPlacedObjects', function(list)
    if type(list) ~= 'table' then return end
    local seen = {}
    for _, payload in ipairs(list) do
        if payload and payload.id then
            seen[payload.id] = true
            if not SpawnedEntities[payload.id] then
                CreateThread(function() spawnPlaced(payload) end)
            end
        end
    end
    for id in pairs(SpawnedEntities) do
        if not seen[id] then despawnPlaced(id) end
    end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(1000)
    if Placeables.IsEnabled() and Config.Placeables.Persistence.SyncOnPlayerJoin then
        TriggerServerEvent('w2f-ambulance:server:requestPlacedObjects')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if PlacementActive then endPlacement(true) else setPlacementFocus(false) end
    for id in pairs(SpawnedEntities) do
        despawnPlaced(id)
    end
end)

exports('useTrainingDummy', function(_, itemData)
    if type(itemData) ~= 'table' or not itemData.name or not itemData.slot then return end
    TriggerEvent('w2f-ambulance:client:startPlaceablePlacement', itemData)
end)
