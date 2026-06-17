RegisterNetEvent('w2f-ambulance:client:onDeath', function()
    LocalPlayer.state:set('isDead', true, true)
end)
