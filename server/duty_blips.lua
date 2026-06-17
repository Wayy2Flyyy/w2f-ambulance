W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.DutyBlips = W2FAmbulance.DutyBlips or {}

local DutyBlips = W2FAmbulance.DutyBlips

local function cfg()
    return Config.Systems and Config.Systems.DutyBlips or {}
end

local function getCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = GetEntityHeading(ped),
    }
end

local function buildRoster()
    local roster = {}

    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        local data = player.PlayerData
        local job = data.job
        if job and job.type == 'ems' and job.onduty then
            local coords = getCoords(data.source)
            if coords then
                local grade = job.grade and job.grade.level or 0
                local callsign = data.metadata and data.metadata.callsign
                local label = (callsign and callsign ~= '') and callsign or W2FAmbulance.Ranks.GetShort(grade)
                roster[#roster + 1] = {
                    source = data.source,
                    label = label,
                    name = ('%s %s'):format(data.charinfo.firstname, data.charinfo.lastname),
                    coords = coords,
                }
            end
        end
    end

    return roster
end

function DutyBlips.broadcast()
    if cfg().Enabled == false then return end

    local roster = buildRoster()
    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        local job = player.PlayerData.job
        if job and job.type == 'ems' and job.onduty then
            TriggerClientEvent(W2FAmbulance.Constants.Events.SyncDutyBlips, player.PlayerData.source, roster)
        end
    end
end

RegisterNetEvent(W2FAmbulance.Constants.Events.RefreshDutyBlips, function()
    DutyBlips.broadcast()
end)

AddEventHandler('QBCore:Server:SetDuty', function(src, _)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    if player.PlayerData.job.type == 'ems' then
        SetTimeout(400, DutyBlips.broadcast)
    end
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    if job and job.type == 'ems' then
        SetTimeout(400, DutyBlips.broadcast)
    end
end)

CreateThread(function()
    while true do
        Wait((cfg().RefreshSeconds or 10) * 1000)
        DutyBlips.broadcast()
    end
end)
