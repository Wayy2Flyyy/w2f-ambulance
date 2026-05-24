RegisterNetEvent('w2f-ambulance:client:applyInjury', function(level)
    LocalPlayer.state:set('injuryLevel', level, true)
end)
