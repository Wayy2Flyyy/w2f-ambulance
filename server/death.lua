RegisterNetEvent('w2f-ambulance:server:playerDied', function()
    local src = source
    TriggerClientEvent('w2f-ambulance:client:onDeath', src)
end)
