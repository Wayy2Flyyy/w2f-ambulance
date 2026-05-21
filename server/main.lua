RegisterNetEvent('w2f-ambulance:server:reviveNearest', function()
    local src = source
    TriggerClientEvent('w2f-ambulance:client:notify', src, 'No patient nearby (placeholder logic).')
end)
