W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.DutyBlipsClient = W2FAmbulance.DutyBlipsClient or {}

local dutyBlips = {}

local function cfg()
    return Config.Systems and Config.Systems.DutyBlips or {}
end

local function clearBlips()
    for id, blip in pairs(dutyBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        dutyBlips[id] = nil
    end
end

local function shouldShow()
    if cfg().Enabled == false then return false end
    return W2FAmbulance.Client.isEmsOnDuty()
end

local function applyBlips(roster)
    clearBlips()
    if not shouldShow() then return end

    local settings = cfg()
    local myId = cache.serverId

    for i = 1, #(roster or {}) do
        local ems = roster[i]
        if ems.source ~= myId and ems.coords then
            local blip = AddBlipForCoord(ems.coords.x, ems.coords.y, ems.coords.z)
            SetBlipSprite(blip, settings.Sprite or 1)
            SetBlipColour(blip, settings.Colour or 1)
            SetBlipScale(blip, settings.Scale or 0.85)
            SetBlipAsShortRange(blip, false)

            if settings.ShowHeading ~= false and ems.coords.w then
                ShowHeadingIndicatorOnBlip(blip, true)
                SetBlipRotation(blip, math.ceil(ems.coords.w))
            end

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(ems.label or ems.name or 'EMS')
            EndTextCommandSetBlipName(blip)

            dutyBlips[ems.source] = blip
        end
    end
end

RegisterNetEvent(W2FAmbulance.Constants.Events.SyncDutyBlips, function(roster)
    applyBlips(roster)
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
    local job = QBX and QBX.PlayerData and QBX.PlayerData.job
    if not onDuty or not job or job.type ~= 'ems' then
        clearBlips()
    end
    TriggerServerEvent(W2FAmbulance.Constants.Events.RefreshDutyBlips)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not job or job.type ~= 'ems' or not job.onduty then
        clearBlips()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    clearBlips()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    clearBlips()
end)
