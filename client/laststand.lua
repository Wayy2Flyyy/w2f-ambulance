RegisterNetEvent('w2f-ambulance:client:laststand', function(seconds)
    lib.notify({description=('Last stand: %s seconds'):format(seconds), type='warning'})
end)
