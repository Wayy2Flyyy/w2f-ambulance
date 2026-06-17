--- Chat commands must register here with lib.addCommand (Qbox routes /commands through the server).
--- Client RegisterCommand alone does not receive typed chat input.

local Events = W2FAmbulance.Constants.Events
local radialCmd = Config.Systems and Config.Systems.Radial and Config.Systems.Radial.Command or 'emsradial'
local tabletCmd = Config.Systems and Config.Systems.CommandTablet and Config.Systems.CommandTablet.Command or 'emstablet'
local testCmd = Config.Minigame and Config.Minigame.testCommand or 'emsmgtest'

---@param src number
---@param event string
local function triggerOnEmsPlayer(src, event)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    if player.PlayerData.job.type ~= 'ems' then
        exports.qbx_core:Notify(src, locale('error.not_ems'), 'error')
        return
    end
    TriggerClientEvent(event, src)
end

lib.addCommand(radialCmd, {
    help = 'Open EMS radial menu (F6)',
}, function(source)
    TriggerClientEvent(Events.OpenRadial, source)
end)

lib.addCommand(tabletCmd, {
    help = 'Open EMS command tablet (high command, on duty)',
}, function(source)
    TriggerClientEvent(Events.OpenCommandTablet, source)
end)

lib.addCommand(testCmd, {
    help = 'Test EMS care minigame overlay',
    params = {
        { name = 'scenario', help = 'checkStatus | treat | help | repair | revive (each uses a unique minigame)', type = 'string', optional = true },
        { name = 'anim', help = 'anim | noanim', type = 'string', optional = true },
    },
}, function(source, args)
    TriggerClientEvent(Events.TestMinigame, source, args.scenario, args.anim)
end)

lib.addCommand('911e', {
    help = locale('info.ems_report'),
    params = {
        { name = 'message', help = locale('info.message_sent'), type = 'longString', optional = true },
    },
}, function(source, args)
    local message = args.message or locale('info.civ_call')
    if W2FAmbulance.AlertDutyEms then
        W2FAmbulance.AlertDutyEms(source, message)
    end
end)

lib.addCommand('status', {
    help = locale('info.check_health'),
}, function(source)
    triggerOnEmsPlayer(source, 'hospital:client:CheckStatus')
end)

lib.addCommand('heal', {
    help = locale('info.heal_player'),
}, function(source)
    triggerOnEmsPlayer(source, 'hospital:client:TreatWounds')
end)

lib.addCommand('revivep', {
    help = locale('info.revive_player'),
}, function(source)
    triggerOnEmsPlayer(source, 'hospital:client:RevivePlayer')
end)

lib.addCommand('stabilize', {
    help = 'Stabilize the nearest patient (EMS, IFAK)',
}, function(source)
    triggerOnEmsPlayer(source, 'hospital:client:StabilizePatient')
end)

lib.addCommand('assist', {
    help = 'Assist the nearest patient (EMS)',
}, function(source)
    triggerOnEmsPlayer(source, 'hospital:client:AssistPatient')
end)

lib.addCommand('prescribe', {
    help = 'Issue a medical prescription to the nearest player (EMS on duty)',
}, function(source)
    TriggerClientEvent('w2f-ambulance:client:issuePrescriptionNearest', source)
end)
