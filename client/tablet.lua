W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.TabletClient = W2FAmbulance.TabletClient or {}

function W2FAmbulance.TabletClient.open()
    if not W2FAmbulance.Client.isEmsOnDuty() then
        exports.qbx_core:Notify(locale('error.not_ems'), 'error')
        return false
    end
    if not W2FAmbulance.Client.hasPermission('HighCommandAccess') then
        W2FAmbulance.Client.notifyRankDenied('HighCommandAccess')
        return false
    end

    local dashboard = lib.callback.await(W2FAmbulance.Constants.Callbacks.GetTabletDashboard, false)
    if not dashboard then
        exports.qbx_core:Notify(locale('error.tablet_denied'), 'error')
        return false
    end

    W2FAmbulance.UI.Tablet.Open(dashboard)
    W2FAmbulance.Animations.StartTablet()
    return true
end

function W2FAmbulance.TabletClient.close()
    W2FAmbulance.UI.Tablet.Close()
    W2FAmbulance.Animations.StopTablet()
    TriggerServerEvent('w2f-ambulance:server:tabletClosed')
end

RegisterNetEvent(W2FAmbulance.Constants.Events.OpenCommandTablet, function()
    W2FAmbulance.TabletClient.open()
end)

exports('useCommandTablet', function(_data)
    W2FAmbulance.TabletClient.open()
end)

exports('OpenCommandTablet', function()
    return W2FAmbulance.TabletClient.open()
end)

local cmd = Config.Systems and Config.Systems.CommandTablet and Config.Systems.CommandTablet.Command or 'emstablet'
RegisterCommand(cmd, function()
    W2FAmbulance.TabletClient.open()
end, false)
