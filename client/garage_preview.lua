W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.GaragePreview = W2FAmbulance.GaragePreview or {}

local Preview = W2FAmbulance.GaragePreview
local clientConfig = require 'config.client'

local activeGarage = nil

local preview = {
    active = false,
    vehicleId = nil,
    entity = nil,
    cam = nil,
    frozen = false,
    spinHeading = nil,
    camAngle = 225.0,
}

local function previewCfg()
    return Config.GaragePreview or {}
end

local function notify(msg, nType)
    exports.qbx_core:Notify(msg, nType or 'inform')
end

local function resolveVehicleEntry(vehicleRef, kind)
    local entry = W2FAmbulance.Equipment.GetVehicleEntry(vehicleRef, kind)
    if entry then return entry end
    return W2FAmbulance.Equipment.GetVehicleEntryById(vehicleRef)
end

local function requestVehicleModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return false end
    if lib and lib.requestModel then
        return lib.requestModel(hash, 5000)
    end
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() - t > 5000 then return false end
    end
    return HasModelLoaded(hash)
end

local function drawText3d(text, coords, scale, color, outline)
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextColour(color.r, color.g, color.b, color.a)
    if outline then SetTextOutline() end
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function previewHoloAnchor(entity)
    local coords = GetEntityCoords(entity)
    local minDim, maxDim = GetModelDimensions(GetEntityModel(entity))
    local height = maxDim.z - minDim.z
    return vec3(coords.x, coords.y, coords.z + height + 0.35)
end

local function drawPreviewHologram(entity)
    if not entity or not DoesEntityExist(entity) then return end
    local anchor = previewHoloAnchor(entity)
    local holo = previewCfg().Hologram or {}
    drawText3d(
        locale('info.garage_preview_prompt'),
        vec3(anchor.x, anchor.y, anchor.z + 0.1),
        0.42,
        holo.primary or { r = 45, g = 212, b = 191, a = 230 },
        true
    )
    drawText3d(
        locale('info.garage_preview_cancel'),
        vec3(anchor.x, anchor.y, anchor.z - 0.12),
        0.32,
        holo.secondary or { r = 200, g = 210, b = 225, a = 180 },
        true
    )
end

local function previewCameraFocus(entity)
    if not entity or not DoesEntityExist(entity) then return end

    local coords = GetEntityCoords(entity)
    local minDim, maxDim = GetModelDimensions(GetEntityModel(entity))
    local focusZ = coords.z + ((maxDim.z - minDim.z) * 0.35)

    local rad = math.rad(preview.camAngle or previewCfg().CamAngle or 225.0)
    local distance = previewCfg().CamDistance or 6.0
    local camPos = vec3(
        coords.x + (distance * math.cos(rad)),
        coords.y + (distance * math.sin(rad)),
        coords.z + (previewCfg().CamHeight or 1.85)
    )
    local lookAt = vec3(coords.x, coords.y, focusZ)

    if preview.cam and DoesCamExist(preview.cam) then
        SetCamCoord(preview.cam, camPos.x, camPos.y, camPos.z)
        PointCamAtCoord(preview.cam, lookAt.x, lookAt.y, lookAt.z)
        return
    end

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)
    SetCamFov(cam, previewCfg().CamFov or 48.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 750, true, false)
    preview.cam = cam
end

local function updatePreviewSpin(entity)
    if not entity or not DoesEntityExist(entity) then return end
    local spinSpeed = previewCfg().SpinSpeed or 16.0
    preview.spinHeading = (preview.spinHeading or GetEntityHeading(entity)) + (spinSpeed * GetFrameTime())
    if preview.spinHeading >= 360.0 then preview.spinHeading = preview.spinHeading - 360.0 end
    SetEntityHeading(entity, preview.spinHeading)
end

local function stopPreviewCamera()
    if preview.cam and DoesCamExist(preview.cam) then
        RenderScriptCams(false, true, 600, true, false)
        DestroyCam(preview.cam, false)
    end
    preview.cam = nil
end

local function setPreviewPlayerFrozen(frozen)
    FreezeEntityPosition(cache.ped, frozen)
    SetPlayerControl(PlayerId(), not frozen, 0)
    preview.frozen = frozen
end

local function disablePreviewControls()
    DisableControlAction(0, 1, true)
    DisableControlAction(0, 2, true)
    DisableControlAction(0, 30, true)
    DisableControlAction(0, 31, true)
    DisableControlAction(0, 21, true)
    DisableControlAction(0, 22, true)
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 37, true)
    DisableControlAction(0, 44, true)
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 38, true)
    DisableControlAction(0, 177, true)
    DisableControlAction(0, 194, true)
    DisableControlAction(0, 200, true)
    DisableControlAction(0, 202, true)
    DisableControlAction(0, 322, true)
end

local function previewCancelPressed()
    return IsDisabledControlJustReleased(0, 177)
        or IsDisabledControlJustReleased(0, 194)
        or IsDisabledControlJustReleased(0, 202)
        or IsDisabledControlJustReleased(0, 200)
        or IsDisabledControlJustReleased(0, 322)
end

local function applyVehicleSettings(veh, entry)
    if not entry or not veh or veh == 0 then return end
    local model = entry.model
    local settings = clientConfig.vehicleSettings and clientConfig.vehicleSettings[model]
    if settings and settings.extras then
        qbx.setVehicleExtras(veh, settings.extras)
    end
    if entry.livery ~= nil then
        SetVehicleLivery(veh, entry.livery)
    elseif settings and settings.livery then
        SetVehicleLivery(veh, settings.livery)
    end
end

local function clearPreview()
    preview.active = false
    preview.vehicleId = nil
    preview.spinHeading = nil
    stopPreviewCamera()
    if preview.frozen then
        setPreviewPlayerFrozen(false)
    end
    if preview.entity and DoesEntityExist(preview.entity) then
        DeleteEntity(preview.entity)
    end
    preview.entity = nil
end

local function spawnPayloadFromPoint(point)
    if not point then return nil end
    return {
        x = point.x + 0.0,
        y = point.y + 0.0,
        z = point.z + 0.0,
        w = (point.w or point.h or 0.0) + 0.0,
    }
end

local function findFreeSpawn(spawnPoint)
    if not spawnPoint then return nil end
    if not IsPositionOccupied(spawnPoint.x, spawnPoint.y, spawnPoint.z, 2.5, false, true, false, false, false, 0, false) then
        return spawnPoint
    end
    return nil
end

local function createPreviewEntity(entry, spawnPoint)
    if not entry or not requestVehicleModel(entry.model) then return nil end

    local hash = joaat(entry.model)
    local veh = CreateVehicle(
        hash,
        spawnPoint.x, spawnPoint.y, spawnPoint.z,
        (spawnPoint.w or spawnPoint.h or 0.0) + 0.0,
        false, false
    )
    if not veh or veh == 0 then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetEntityCollision(veh, false, false)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetVehicleDoorsLocked(veh, 2)
    SetEntityAlpha(veh, previewCfg().Alpha or 150, false)
    SetVehicleEngineOn(veh, false, true, false)
    applyVehicleSettings(veh, entry)

    SetModelAsNoLongerNeeded(hash)
    return veh
end

local function finalizeSpawnedVehicle(vehicleId, spawnPoint, entry)
    local netId = lib.callback.await(
        'qbx_ambulancejob:server:spawnVehicle',
        false,
        vehicleId,
        spawnPayloadFromPoint(spawnPoint),
        activeGarage and activeGarage.spawn or spawnPoint
    )
    if not netId then
        notify(locale('error.garage_spawn_failed'), 'error')
        return false
    end

    local veh = lib.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(netId) then
            return NetToVeh(netId)
        end
    end, nil, 8000)

    if not veh or veh == 0 then
        notify(locale('error.garage_spawn_failed'), 'error')
        return false
    end

    applyVehicleSettings(veh, entry)
    SetVehicleEngineOn(veh, true, true, true)
    notify(locale('success.garage_vehicle_deployed'), 'success')
    return true
end

local function returnToGarageMenu()
    if activeGarage and W2FAmbulance.CatalogClient and W2FAmbulance.CatalogClient.openGarage then
        W2FAmbulance.CatalogClient.openGarage(activeGarage.kind, activeGarage.spawn)
    end
end

function Preview.setActiveGarage(spawn, kind)
    activeGarage = spawn and kind and { spawn = spawn, kind = kind } or nil
end

function Preview.getActiveGarage()
    return activeGarage
end

function Preview.isActive()
    return preview.active
end

function Preview.CancelPreview()
    clearPreview()
end

function Preview.spawnFromActiveGarage(vehicleId)
    if not activeGarage or not vehicleId then return false end

    local entry = resolveVehicleEntry(vehicleId, activeGarage.kind)
    if not entry then return false end

    local spawnPoint = findFreeSpawn(activeGarage.spawn)
    if not spawnPoint then
        notify(locale('error.garage_full'), 'error')
        return false
    end

    return finalizeSpawnedVehicle(vehicleId, spawnPoint, entry)
end

function Preview.StartPreview(vehicleId)
    if previewCfg().Enabled == false then
        return Preview.spawnFromActiveGarage(vehicleId)
    end

    if preview.active then
        clearPreview()
    end
    if not activeGarage or not vehicleId then return false end

    local entry = resolveVehicleEntry(vehicleId, activeGarage.kind)
    if not entry then
        notify(locale('error.garage_preview_invalid_model'), 'error')
        return false
    end

    local spawnPoint = findFreeSpawn(activeGarage.spawn)
    if not spawnPoint then
        notify(locale('error.garage_full'), 'error')
        return false
    end

    local entity = createPreviewEntity(entry, spawnPoint)
    if not entity then
        notify(locale('error.garage_preview_failed'), 'error')
        return false
    end

    preview.active = true
    preview.vehicleId = vehicleId
    preview.entity = entity
    preview.spinHeading = (spawnPoint.w or spawnPoint.h or 0.0) + 0.0
    preview.camAngle = previewCfg().CamAngle or 225.0

    if lib and lib.hideTextUI then lib.hideTextUI() end
    setPreviewPlayerFrozen(true)
    previewCameraFocus(entity)

    CreateThread(function()
        while preview.active do
            Wait(0)

            if not preview.entity or not DoesEntityExist(preview.entity) then
                clearPreview()
                break
            end

            disablePreviewControls()
            updatePreviewSpin(preview.entity)
            previewCameraFocus(preview.entity)
            drawPreviewHologram(preview.entity)

            if IsDisabledControlJustReleased(0, 38) then
                local id = preview.vehicleId
                clearPreview()
                Preview.spawnFromActiveGarage(id)
                break
            end

            if previewCancelPressed() then
                clearPreview()
                notify(locale('info.garage_preview_cancelled'), 'error')
                returnToGarageMenu()
                break
            end
        end
    end)

    return true
end

--- Backwards-compatible alias used by older call sites.
function Preview.start(vehicleId, spawn, kind)
    Preview.setActiveGarage(spawn, kind)
    return Preview.StartPreview(vehicleId)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    clearPreview()
    activeGarage = nil
end)
