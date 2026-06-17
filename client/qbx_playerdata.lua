--- OAL isolates per-file global *writes*, so the bare `QBX` global that
--- @qbx_core/modules/playerdata.lua defines stays trapped in that file's
--- environment and reads back as nil in every other client script (the cause
--- of "attempt to index a nil value (global 'QBX')"). Re-anchor QBX on _G here
--- and keep PlayerData in sync so all files can read `QBX.PlayerData`.
--- Mirrors the namespace pattern in client/namespace.lua.
_G.QBX = _G.QBX or {}
_G.QBX.PlayerData = exports.qbx_core:GetPlayerData() or {}

RegisterNetEvent('QBCore:Player:SetPlayerData', function(playerData)
    _G.QBX.PlayerData = playerData
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    _G.QBX.PlayerData = {}
end)
