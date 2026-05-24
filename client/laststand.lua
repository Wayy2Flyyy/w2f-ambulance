local isEscorting = false

AddEventHandler('hospital:client:SetEscortingState', function(bool)
    isEscorting = bool
end)

lib.callback.register('hospital:client:UseFirstAid', function()
    if isEscorting then
        exports.qbx_core:Notify(locale('error.impossible'), 'error')
        return
    end
    local player = GetClosestPlayer()
    if player then
        TriggerServerEvent('hospital:server:UseFirstAid', GetPlayerServerId(player))
    end
end)

lib.callback.register('hospital:client:canHelp', function()
    return W2FAmbulance.Medical('IsLaststand') and W2FAmbulance.Medical('GetLaststandTime') <= 300
end)

RegisterNetEvent('hospital:client:HelpPerson', function(targetId)
    if GetInvokingResource() then return end

    local success, cancelled = W2FAmbulance.Minigame.run('help', { useAnim = true })
    if success then
        exports.qbx_core:Notify(locale('success.revived'), 'success')
        TriggerServerEvent('hospital:server:RevivePlayer', targetId)
    else
        W2FAmbulance.CareClient.handleMinigameResult('revive', success, cancelled)
        if cancelled then
            exports.qbx_core:Notify(locale('error.canceled'), 'error')
        else
            exports.qbx_core:Notify(locale('error.minigame_failed'), 'error')
        end
    end
end)
