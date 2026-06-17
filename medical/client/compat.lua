local sharedConfig = require 'medical.config.shared'

--- Legacy qbx_medical / w2f-deathnote compatibility (resource is w2f-ambulance).
exports('DisableDeathScreen', function() end)

exports('EnableRespawn', AllowRespawn)

exports('RespawnPlayer', function()
    AllowRespawn()
    if DeathState == sharedConfig.deathState.DEAD then
        local success = lib.callback.await('qbx_medical:server:respawn')
        if not success then return false end
        if QBX.PlayerData.metadata.ishandcuffed then
            TriggerEvent('police:client:GetCuffed', -1)
        end
        TriggerEvent('police:client:DeEscort')
        LocalPlayer.state.invBusy = false
        return true
    end

    TriggerServerEvent('w2f-ambulance:server:forceHospitalRespawn')
    return true
end)

RegisterNetEvent('qbx_medical:client:respawnAtHospital', function()
    TriggerServerEvent('w2f-ambulance:server:forceHospitalRespawn')
end)
