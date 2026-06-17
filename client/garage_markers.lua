W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.GarageMarkers = W2FAmbulance.GarageMarkers or {}

local sharedConfig = require 'config.shared'

local function markerCfg()
    return Config.GarageMarkers or {}
end

local function canSeeMarkers()
    if markerCfg().Enabled == false then return false end
    if not QBX or not QBX.PlayerData or not QBX.PlayerData.job then return false end
    return QBX.PlayerData.job.type == 'ems' and QBX.PlayerData.job.onduty
end

local function normalizeGarageEntry(entry)
    if entry.spawn then
        return entry.spawn, entry.returnPoint or vec3(entry.spawn.x + 2.5, entry.spawn.y, entry.spawn.z)
    end
    return entry, vec3(entry.x + 2.5, entry.y, entry.z)
end

local function collectPoints()
    local points = {}

    for _, entry in pairs(sharedConfig.locations.vehicle or {}) do
        local spawn, returnPoint = normalizeGarageEntry(entry)
        points[#points + 1] = { coords = spawn.xyz, kind = 'spawn', air = false }
        points[#points + 1] = { coords = returnPoint, kind = 'return', air = false }
    end

    for _, entry in pairs(sharedConfig.locations.helicopter or {}) do
        local spawn, returnPoint = normalizeGarageEntry(entry)
        points[#points + 1] = { coords = spawn.xyz, kind = 'spawn', air = true }
        points[#points + 1] = { coords = returnPoint, kind = 'return', air = true }
    end

    return points
end

local function getGroundZ(x, y, refZ)
    local probeZ = (refZ or 0.0) + 2.0
    local found, groundZ = GetGroundZFor_3dCoord(x, y, probeZ, false)
    if found then return groundZ end

    found, groundZ = GetGroundZFor_3dCoord(x, y, probeZ + 48.0, false)
    if found then return groundZ end

    return refZ or 0.0
end

local function drawMarkerAt(coords, style)
    if not style then return end
    local color = style.color or {}
    local scale = style.scale or vec3(0.38, 0.38, 0.05)
    local groundZ = getGroundZ(coords.x, coords.y, coords.z)
    local markerZ = groundZ + (scale.z * 0.5) + (style.zOffset or 0.0)

    DrawMarker(
        style.type or 25,
        coords.x, coords.y, markerZ,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        scale.x, scale.y, scale.z,
        color.r or 255, color.g or 255, color.b or 255, color.a or 70,
        false, false, 2, false, nil, nil, false
    )
end

CreateThread(function()
    local points = collectPoints()

    while true do
        local sleep = 1000

        if canSeeMarkers() then
            local pedCoords = GetEntityCoords(cache.ped)
            local settings = markerCfg()
            local drawDistance = settings.DrawDistance or 14.0

            for i = 1, #points do
                local point = points[i]
                local dist = #(pedCoords - point.coords)
                if dist <= drawDistance then
                    sleep = 0
                    local style = point.kind == 'spawn' and settings.Spawn or settings.Return
                    drawMarkerAt(point.coords, style)
                end
            end
        end

        Wait(sleep)
    end
end)
