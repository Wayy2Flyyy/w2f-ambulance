W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Bootstrap = W2FAmbulance.Bootstrap or {}

local Bootstrap = W2FAmbulance.Bootstrap

local REQUIRED = { 'qbx_core', 'ox_lib', 'ox_inventory', 'ox_target', 'oxmysql' }
local BLOCKED = { 'qbx_ambulancejob', 'w2f-prescription', 'qbx_medical' }

local REQUIRED_ITEMS = {
    'radio', 'bandage', 'painkillers', 'firstaid', 'ifaks', 'medical_prescription',
    'ems_command_tablet',
    'haveitol', 'dead_tired', 'fentanyl', 'oxycodone', 'wakey_wakey',
}

local function logLine(level, message)
    print(('[w2f-ambulance][%s] %s'):format(level, message))
end

local function getJobs()
    local ok, jobs = pcall(function()
        return exports.qbx_core:GetJobs()
    end)
    if ok and type(jobs) == 'table' then
        return jobs
    end
    return nil
end

local function hasItem(name)
    local ok, item = pcall(function()
        return exports.ox_inventory:Items(name)
    end)
    return ok and item ~= nil
end

function Bootstrap.Run()
    local ok = true
    local warnings = {}
    local errors = {}

    for i = 1, #REQUIRED do
        local resource = REQUIRED[i]
        local state = GetResourceState(resource)
        if state ~= 'started' then
            ok = false
            errors[#errors + 1] = ('Required dependency "%s" is %s'):format(resource, state)
        end
    end

    for i = 1, #BLOCKED do
        local resource = BLOCKED[i]
        local state = GetResourceState(resource)
        if state == 'started' or state == 'starting' then
            StopResource(resource)
            logLine('WARN', ('Stopped "%s" — merged into w2f-ambulance'):format(resource))
        elseif state ~= 'stopped' and state ~= 'missing' then
            ok = false
            errors[#errors + 1] = ('"%s" is %s — add "stop %s" after ensure [qbx] in server.cfg'):format(resource, state, resource)
        end
    end

    local jobs = getJobs()
    if not jobs then
        warnings[#warnings + 1] = 'Could not read qbx_core jobs export — verify ambulance job manually.'
    elseif not jobs.ambulance then
        ok = false
        errors[#errors + 1] = 'Missing Qbox job "ambulance" — see qbx_core/shared/jobs.lua'
    elseif jobs.ambulance.type ~= 'ems' then
        warnings[#warnings + 1] = 'Job "ambulance" should have type = "ems"'
    else
        local expectedMax = W2FAmbulance.Ranks.GetMax()
        local actualMax = 0
        for grade in pairs(jobs.ambulance.grades or {}) do
            if type(grade) == 'number' and grade > actualMax then actualMax = grade end
        end
        if actualMax < expectedMax then
            warnings[#warnings + 1] = ('Job "ambulance" has grades 0-%d but w2f-ambulance expects 0-%d — update qbx_core/shared/jobs.lua'):format(
                actualMax, expectedMax
            )
        end
    end

    if GetResourceState('ox_inventory') == 'started' then
        for i = 1, #REQUIRED_ITEMS do
            local itemName = REQUIRED_ITEMS[i]
            if not hasItem(itemName) then
                ok = false
                errors[#errors + 1] = ('Missing ox_inventory item "%s"'):format(itemName)
            end
        end
    end

    logLine('INFO', 'Startup check — w2f-ambulance v' .. W2FAmbulance.Version)
    for i = 1, #warnings do logLine('WARN', warnings[i]) end
    for i = 1, #errors do logLine('ERROR', errors[i]) end

    if ok then
        logLine('INFO', 'Ready — /setjob <id> ambulance 0, F6 radial, /911e /status /heal /revivep /prescribe')
    else
        logLine('ERROR', 'Not ready — fix the errors above and restart w2f-ambulance')
    end

    return ok
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CreateThread(function()
        for _ = 1, 30 do
            local ready = true
            for i = 1, #REQUIRED do
                if GetResourceState(REQUIRED[i]) ~= 'started' then
                    ready = false
                    break
                end
            end
            if ready then break end
            Wait(500)
        end

        Wait(500)
        Bootstrap.Run()
    end)
end)
