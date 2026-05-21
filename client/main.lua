local function debug(msg) if Config.Debug then print(('[w2f-ambulance] %s'):format(msg)) end end
RegisterNetEvent('w2f-ambulance:client:notify', function(msg) lib.notify({description=msg,type='inform'}) end)
