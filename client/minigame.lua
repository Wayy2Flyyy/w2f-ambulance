W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Minigame = W2FAmbulance.Minigame or {}

local Minigame = W2FAmbulance.Minigame
local pending = nil
local careActive = false
local careAnimActive = false
local activeAnim = nil

local function cfg()
    return Config.Minigame or {}
end

local function scenarioConfig(id)
    local scenarios = cfg().scenarios or {}
    return scenarios[id]
end

local function buildPayload(id)
    local row = scenarioConfig(id) or {}
    return {
        id = id,
        type = row.type or 'pulse',
        label = row.label or 'EMS Procedure',
        subtitle = row.subtitle or '',
        instruction = row.instruction or 'Press SPACE to continue',
        rounds = row.rounds or 3,
        speed = row.speed or 1.0,
        window = row.window or 0.16,
        holdMs = row.holdMs or 900,
        cycleMs = row.cycleMs or 1100,
        flashMs = row.flashMs or 1400,
        inhaleRatio = row.inhaleRatio or 0.55,
        sweepMs = row.sweepMs or 3400,
        windowStart = row.windowStart or 0.26,
        windowEnd = row.windowEnd or 0.74,
        windowSize = row.windowSize,
        woundSites = row.woundSites,
        sequenceLabels = row.sequenceLabels,
        maxMisses = row.maxMisses or cfg().maxMisses or 3,
        key = cfg().defaultKey or 'Space',
    }
end

local function startScenarioAnim(row)
    if not row or row.useAnim == false then return end
    local anim = row.anim
    if not anim or not anim.dict or not anim.clip then return end

    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 8.0, -8.0, -1, anim.flag or 1, 0, false, false, false)
    activeAnim = { dict = anim.dict, clip = anim.clip }
    careAnimActive = true
end

local function stopCareAnim()
    if not careAnimActive then return end
    careAnimActive = false
    local ped = cache.ped
    if activeAnim then
        StopAnimTask(ped, activeAnim.dict, activeAnim.clip, 1.0)
        activeAnim = nil
    end
    ClearPedSecondaryTask(ped)
end

local function setCareControls(active)
    careActive = active
end

CreateThread(function()
    while true do
        if careActive then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 75, true)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

---@param scenarioId string
---@param opts? { useAnim?: boolean, force?: boolean }
---@return boolean success, boolean cancelled
function Minigame.run(scenarioId, opts)
    opts = opts or {}
    if not opts.force and not cfg().enabled then return true, false end
    if pending then return false, true end

    local row = scenarioConfig(scenarioId)
    if not row then
        if opts.force then return false, false end
        return true, false
    end

    local useAnim = opts and opts.useAnim
    if useAnim == nil then useAnim = row.useAnim ~= false end

    local p = promise.new()
    pending = p

    if useAnim then startScenarioAnim(row) end
    setCareControls(true)
    W2FAmbulance.UI.Minigame.Open(buildPayload(scenarioId))

    local result = Citizen.Await(p)
    pending = nil
    setCareControls(false)
    if useAnim then stopCareAnim() end

    if type(result) ~= 'table' then
        return result == true, false
    end
    return result.success == true, result.cancelled == true
end

function Minigame.resolve(result)
    if not pending then return end
    pending:resolve(result)
    pending = nil
end

function Minigame.isActive()
    return pending ~= nil
end

function Minigame.forceStop()
    setCareControls(false)
    stopCareAnim()
    if pending then
        Minigame.resolve({ success = false, cancelled = true })
    end
end

RegisterNUICallback('minigameComplete', function(data, cb)
    W2FAmbulance.UI.Minigame.Close()
    setCareControls(false)
    stopCareAnim()
    Minigame.resolve({
        success = data and data.success == true,
        cancelled = data and data.cancelled == true,
    })
    cb({ ok = true })
end)

exports('RunCareMinigame', function(scenarioId, opts)
    return Minigame.run(scenarioId, opts)
end)

local function listScenarios()
    local names = {}
    for id in pairs(cfg().scenarios or {}) do
        names[#names + 1] = id
    end
    table.sort(names)
    return names
end

local function parseTestArgs(scenario, animFlag, args, rawCommand)
    if type(scenario) == 'string' and scenario ~= '' then
        return scenario, animFlag
    end

    if args and args[1] and args[1] ~= '' then
        return args[1], args[2]
    end

    if type(rawCommand) == 'string' and rawCommand ~= '' then
        local parts = {}
        for token in rawCommand:gmatch('%S+') do
            parts[#parts + 1] = token
        end
        return parts[2], parts[3]
    end
end

local function runTestMinigame(scenario, animFlag)
    if Minigame.isActive() then
        exports.qbx_core:Notify('Minigame already running', 'error')
        return
    end

    scenario = scenario or 'treat'
    if not scenarioConfig(scenario) then
        exports.qbx_core:Notify(
            ('Unknown scenario "%s". Options: %s'):format(scenario, table.concat(listScenarios(), ', ')),
            'error'
        )
        return
    end

    CreateThread(function()
        local row = scenarioConfig(scenario)
        local useAnim = row.useAnim ~= false
        if animFlag == 'noanim' then useAnim = false end
        if animFlag == 'anim' then useAnim = true end

        local success, cancelled = Minigame.run(scenario, { force = true, useAnim = useAnim })
        if cancelled then
            exports.qbx_core:Notify('Minigame cancelled', 'error')
        elseif success then
            exports.qbx_core:Notify(('Minigame passed (%s)'):format(scenario), 'success')
        else
            exports.qbx_core:Notify(('Minigame failed (%s)'):format(scenario), 'error')
        end
    end)
end

RegisterNetEvent(W2FAmbulance.Constants.Events.TestMinigame, function(scenario, animFlag)
    runTestMinigame(scenario, animFlag)
end)

local testCmd = cfg().testCommand or 'emsmgtest'
RegisterCommand(testCmd, function(_, args, rawCommand)
    local scenario, animFlag = parseTestArgs(nil, nil, args, rawCommand)
    runTestMinigame(scenario, animFlag)
end, false)
