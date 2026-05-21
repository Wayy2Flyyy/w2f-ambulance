RegisterNetEvent('w2f-ambulance:client:useBed', function(index)
    local bed = Config.Beds[index]
    if not bed then return end
    SetEntityCoords(cache.ped, bed.coords.x, bed.coords.y, bed.coords.z)
end)
