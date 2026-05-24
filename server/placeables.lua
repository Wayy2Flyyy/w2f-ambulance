local Placeables = W2FAmbulance.Placeables

local Placed = {}
local LastPlaceAt = {}

local function notify(src, msgKey, nType)
    if not src or src == 0 then return end
    exports.qbx_core:Notify(src, locale(msgKey), nType or 'inform')
end

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function getCitizenId(src)
    local player = getPlayer(src)
    return player and player.PlayerData.citizenid or nil
end

local function isAdmin(src)
    return IsPlayerAceAllowed(src, 'command') or IsPlayerAceAllowed(src, 'w2f.admin')
end

local function isEmsOnDuty(src)
    local player = getPlayer(src)
    return player and W2FAmbulance.Core.isEmsOnDuty(player) or false
end

local function countByCitizen(citizenid)
    local n = 0
    for _, obj in pairs(Placed) do
        if obj.citizenid == citizenid then n += 1 end
    end
    return n
end

local function countAll()
    local n = 0
    for _ in pairs(Placed) do n += 1 end
    return n
end

local function tooCloseToOther(coords)
    local minDist = (Config.Placeables.Limits and Config.Placeables.Limits.MinimumDistanceBetweenObjects) or 2.0
    local minSqr = minDist * minDist
    for _, obj in pairs(Placed) do
        if Placeables.DistanceSqr(coords, { x = obj.x, y = obj.y, z = obj.z }) < minSqr then
            return true
        end
    end
    return false
end

local function buildPayload(obj)
    local cfg = Placeables.GetConfig(obj.item) or {}
    local model = Placeables.ResolvePropModel(obj.model, obj.item) or obj.model
    return {
        id = obj.id,
        owner = obj.citizenid,
        item = obj.item,
        model = model,
        label = obj.label or cfg.label or obj.item,
        coords = vec3(obj.x, obj.y, obj.z),
        heading = obj.heading or 0.0,
        pickupEnabled = cfg.pickupEnabled ~= false,
        zOffset = cfg.zOffset or 0.0,
    }
end

local function saveObject(obj)
    if not Config.Placeables.Persistence.SaveToDatabase then return end
    MySQL.insert.await([[
        INSERT INTO w2f_ambulance_placeables
            (object_id, citizenid, item, model, label, x, y, z, heading, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            citizenid = VALUES(citizenid),
            item = VALUES(item),
            model = VALUES(model),
            label = VALUES(label),
            x = VALUES(x),
            y = VALUES(y),
            z = VALUES(z),
            heading = VALUES(heading)
    ]], {
        obj.id,
        obj.citizenid,
        obj.item,
        obj.model,
        obj.label,
        obj.x, obj.y, obj.z,
        obj.heading or 0.0,
    })
end

local function deleteObject(objectId)
    if not Config.Placeables.Persistence.SaveToDatabase then return end
    MySQL.query.await('DELETE FROM w2f_ambulance_placeables WHERE object_id = ?', { objectId })
end

local function loadObjects()
    if not Config.Placeables.Persistence.LoadOnResourceStart then return 0 end
    local rows = MySQL.query.await('SELECT * FROM w2f_ambulance_placeables') or {}
    local n = 0
    for _, row in ipairs(rows) do
        if Placeables.IsPlaceableItem(row.item) then
            Placed[row.object_id] = {
                id = row.object_id,
                citizenid = row.citizenid,
                item = row.item,
                model = row.model,
                label = row.label,
                x = row.x,
                y = row.y,
                z = row.z,
                heading = row.heading or 0.0,
            }
            if W2FAmbulance.TrainingDummy and W2FAmbulance.TrainingDummy.isDummyItem(row.item) then
                W2FAmbulance.TrainingDummy.init(row.object_id)
            end
            n += 1
        end
    end
    return n
end

local function syncTo(src)
    local list = {}
    for _, obj in pairs(Placed) do
        list[#list + 1] = buildPayload(obj)
    end
    TriggerClientEvent('w2f-ambulance:client:syncPlacedObjects', src, list)
end

local function validatePlaceRequest(src, data)
    if not Placeables.IsEnabled() then return false, 'error.placeable_server_rejected' end
    if type(data) ~= 'table' then return false, 'error.placeable_server_rejected' end

    local item = data.item
    local slot = tonumber(data.slot)
    local heading = tonumber(data.heading) or 0.0
    local coords = data.coords

    if type(item) ~= 'string' or not slot or type(coords) ~= 'table' then
        return false, 'error.placeable_server_rejected'
    end

    if not Placeables.IsPlaceableItem(item) then
        return false, 'error.placeable_not_placeable'
    end

    local cfg = Placeables.GetConfig(item)
    if not cfg or not Placeables.IsValidModel(cfg.prop) then
        return false, 'error.placeable_invalid_model'
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'error.placeable_server_rejected' end

    if Config.Placeables.Placement.AllowInVehicle == false then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh and veh ~= 0 then return false, 'error.placeable_in_vehicle' end
    end

    local pCoords = GetEntityCoords(ped)
    local placement = Placeables.GetPlacement(item)
    local maxDist = (placement.maxDistanceFromPlayer or 5.0) + 1.5
    if Placeables.DistanceSqr(pCoords, coords) > (maxDist * maxDist) then
        return false, 'error.placeable_too_far'
    end

    local slotData = exports.ox_inventory:GetSlot(src, slot)
    if not slotData or slotData.name ~= item or (slotData.count or 0) < 1 then
        return false, 'error.placeable_missing_item'
    end

    local citizenid = getCitizenId(src)
    if not citizenid then return false, 'error.placeable_server_rejected' end

    if Config.Placeables.Limits.Enabled then
        local perPlayer = Config.Placeables.Limits.MaxObjectsPerPlayer or 0
        if perPlayer > 0 and countByCitizen(citizenid) >= perPlayer then
            return false, 'error.placeable_limit_reached'
        end
        local global = Config.Placeables.Limits.MaxObjectsGlobal or 0
        if global > 0 and countAll() >= global then
            return false, 'error.placeable_limit_reached'
        end
        if tooCloseToOther(coords) then
            return false, 'error.placeable_too_close'
        end
    end

    return true, {
        item = item,
        slot = slot,
        heading = Placeables.ClampHeading(heading),
        coords = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 },
        cfg = cfg,
    }
end

RegisterNetEvent('w2f-ambulance:server:placeObject', function(payload)
    if GetInvokingResource() then return end
    local src = source
    local now = GetGameTimer()
    if LastPlaceAt[src] and (now - LastPlaceAt[src]) < 750 then return end
    LastPlaceAt[src] = now

    local ok, result = validatePlaceRequest(src, payload)
    if not ok then
        notify(src, result, 'error')
        return
    end

    local r = result
    local cfg = r.cfg

    if cfg.removeItemOnPlace then
        if not exports.ox_inventory:RemoveItem(src, r.item, 1, nil, r.slot) then
            notify(src, 'error.placeable_missing_item', 'error')
            return
        end
    end

    local obj = {
        id = Placeables.GenerateObjectId(),
        citizenid = getCitizenId(src),
        item = r.item,
        model = cfg.prop,
        label = cfg.label,
        x = r.coords.x,
        y = r.coords.y,
        z = r.coords.z,
        heading = r.heading,
    }

    local saveOk, saveErr = pcall(saveObject, obj)
    if not saveOk then
        if cfg.removeItemOnPlace then
            exports.ox_inventory:AddItem(src, r.item, 1)
        end
        print(('[w2f-ambulance] placeable save failed: %s'):format(tostring(saveErr)))
        notify(src, 'error.placeable_server_rejected', 'error')
        return
    end

    Placed[obj.id] = obj
    if W2FAmbulance.TrainingDummy and W2FAmbulance.TrainingDummy.isDummyItem(obj.item) then
        W2FAmbulance.TrainingDummy.init(obj.id)
    end
    TriggerClientEvent('w2f-ambulance:client:createPlacedObject', -1, buildPayload(obj))
    notify(src, 'success.placeable_placed', 'success')
end)

RegisterNetEvent('w2f-ambulance:server:pickupObject', function(objectId)
    if GetInvokingResource() then return end
    local src = source
    if type(objectId) ~= 'string' then return end

    local obj = Placed[objectId]
    if not obj then return end

    local cfg = Placeables.GetConfig(obj.item)
    if not cfg or cfg.pickupEnabled == false then
        notify(src, 'error.placeable_not_placeable', 'error')
        return
    end

    local citizenid = getCitizenId(src)
    if not citizenid then return end

    local owns = obj.citizenid == citizenid
    local ownership = Config.Placeables.Ownership or {}
    if ownership.OnlyOwnerCanPickup and not owns then
        local allowed = false
        if ownership.AllowAdminPickup and isAdmin(src) then allowed = true end
        if ownership.AllowEmsOnDutyPickup and isEmsOnDuty(src) then allowed = true end
        if not allowed then
            notify(src, 'error.placeable_not_owner', 'error')
            return
        end
    end

    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local pCoords = GetEntityCoords(ped)
        if Placeables.DistanceSqr(pCoords, { x = obj.x, y = obj.y, z = obj.z }) > 25.0 then
            notify(src, 'error.placeable_too_far', 'error')
            return
        end
    end

    if cfg.giveItemOnPickup then
        if not exports.ox_inventory:AddItem(src, obj.item, 1) then
            notify(src, 'error.placeable_inventory_full', 'error')
            return
        end
    end

    deleteObject(objectId)
    if W2FAmbulance.TrainingDummy and W2FAmbulance.TrainingDummy.isDummyItem(obj.item) then
        W2FAmbulance.TrainingDummy.clear(objectId)
    end
    Placed[objectId] = nil
    TriggerClientEvent('w2f-ambulance:client:removePlacedObject', -1, objectId)
    notify(src, 'success.placeable_picked_up', 'success')
end)

RegisterNetEvent('w2f-ambulance:server:requestPlacedObjects', function()
    if GetInvokingResource() then return end
    syncTo(source)
end)

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(500) end
    Wait(500)
    if not Placeables.IsEnabled() then return end
    local n = loadObjects()
    if n > 0 then
        print(('[w2f-ambulance] Loaded %d placeable props'):format(n))
        for _, obj in pairs(Placed) do
            TriggerClientEvent('w2f-ambulance:client:createPlacedObject', -1, buildPayload(obj))
        end
    end
end)
