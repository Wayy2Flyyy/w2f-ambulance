--- ox_inventory item exports + legacy hospital:client:* callbacks for medical consumables.

local config = require 'config.client'
local oxInventory = exports.ox_inventory
local painkillerAmount = 0
local isEscorting = false

AddEventHandler('hospital:client:SetEscortingState', function(bool)
    isEscorting = bool
end)

local function useBandageEffect()
    if lib.progressCircle({
        duration = 4000,
        position = 'bottom',
        label = locale('progress.bandage'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = false, combat = true, mouse = false },
        anim = { dict = 'mp_suicide', clip = 'pill' },
    }) then
        SetEntityHealth(cache.ped, GetEntityHealth(cache.ped) + 10)
        if math.random(1, 100) < 50 then W2FAmbulance.Medical('RemoveBleed', 1) end
        if math.random(1, 100) < 7 then W2FAmbulance.Medical('ResetMinorInjuries') end
        return true
    end
    exports.qbx_core:Notify(locale('error.canceled'), 'error')
    return false
end

local function useIfaksEffect()
    if lib.progressCircle({
        duration = 3000,
        position = 'bottom',
        label = locale('progress.ifaks'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = false, combat = true, mouse = false },
        anim = { dict = 'mp_suicide', clip = 'pill' },
    }) then
        TriggerServerEvent('hud:server:RelieveStress', math.random(12, 24))
        SetEntityHealth(cache.ped, GetEntityHealth(cache.ped) + 10)
        OnPainKillers = true
        W2FAmbulance.Medical('DisableDamageEffects')
        if painkillerAmount < 3 then painkillerAmount += 1 end
        if math.random(1, 100) < 50 then W2FAmbulance.Medical('RemoveBleed', 1) end
        return true
    end
    exports.qbx_core:Notify(locale('error.canceled'), 'error')
    return false
end

local function usePainkillersEffect()
    if lib.progressCircle({
        duration = 3000,
        position = 'bottom',
        label = locale('progress.painkillers'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = false, car = false, combat = true, mouse = false },
        anim = { dict = 'mp_suicide', clip = 'pill' },
    }) then
        OnPainKillers = true
        W2FAmbulance.Medical('DisableDamageEffects')
        if painkillerAmount < 3 then painkillerAmount += 1 end
        return true
    end
    exports.qbx_core:Notify(locale('error.canceled'), 'error')
    return false
end

lib.callback.register('hospital:client:UseBandage', useBandageEffect)
lib.callback.register('hospital:client:UseIfaks', useIfaksEffect)
lib.callback.register('hospital:client:UsePainkillers', usePainkillersEffect)

exports('useBandage', function(data)
    oxInventory:useItem(data, function(used)
        if used then useBandageEffect() end
    end)
end)

exports('useIfaks', function(data)
    oxInventory:useItem(data, function(used)
        if used then useIfaksEffect() end
    end)
end)

exports('usePainkillers', function(data)
    oxInventory:useItem(data, function(used)
        if used then usePainkillersEffect() end
    end)
end)

exports('useFirstaid', function(_data)
    if isEscorting then
        exports.qbx_core:Notify(locale('error.impossible'), 'error')
        return
    end
    local player = GetClosestPlayer()
    if not player then
        exports.qbx_core:Notify(locale('error.no_player'), 'error')
        return
    end
    TriggerServerEvent('hospital:server:UseFirstAid', GetPlayerServerId(player))
end)

local function consumePainKiller()
    painkillerAmount -= 1
    Wait(config.painkillerInterval * 1000)
    if painkillerAmount > 0 then return end
    painkillerAmount = 0
    OnPainKillers = false
    W2FAmbulance.Medical('EnableDamageEffects')
end

CreateThread(function()
    while true do
        if OnPainKillers then
            consumePainKiller()
        else
            Wait(3000)
        end
    end
end)
