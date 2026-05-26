W2FAmbulance = _G.W2FAmbulance or {}
local Framework = W2FAmbulance.Framework or {}

function Framework.GetPlayerData()
    if Framework.IsQbox() and QBX then return QBX.PlayerData or {} end
    if Framework.IsQBCore() and LocalPlayer and LocalPlayer.state and LocalPlayer.state.isLoggedIn and exports['qb-core'] then
        local core = exports['qb-core']:GetCoreObject()
        return core.Functions.GetPlayerData()
    end
    if Framework.IsESX() then
        local ok, esx = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok and esx then return esx.GetPlayerData() end
    end
    return {}
end

function Framework.Notify(message, ntype)
    if Framework.IsQbox() then
        return exports.qbx_core:Notify(message, ntype or 'inform')
    end
    lib.notify({ description = message, type = ntype or 'inform' })
end

W2FAmbulance.Framework = Framework
