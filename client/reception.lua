--- Bedside doctor NPC during hospital bed treatment.

W2FAmbulance = W2FAmbulance or {}
W2FAmbulance.Reception = W2FAmbulance.Reception or {}

local triageConfig = require 'config.triage'

---@type { ped: number, active: boolean }?
local bedsideDoctor = nil

---@param ped number
local function configureDoctorPed(ped)
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
end

---@param ped number
---@param anim table
local function playDoctorAnim(ped, anim)
    if not anim or not anim.dict or not anim.clip then return end

    lib.requestAnimDict(anim.dict, 5000)
    TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, anim.flag or 49, 0, false, false, false)
end

local function cleanupBedsideDoctor()
    if not bedsideDoctor then return end

    bedsideDoctor.active = false

    if bedsideDoctor.ped and DoesEntityExist(bedsideDoctor.ped) then
        ClearPedTasks(bedsideDoctor.ped)
        DeleteEntity(bedsideDoctor.ped)
    end

    bedsideDoctor = nil
end

---@param bedCoords vector4
---@param treatment string
---@return number? ped
function W2FAmbulance.Reception.startBedsideTreatment(bedCoords, treatment)
    cleanupBedsideDoctor()

    local cfg = triageConfig.bedDoctor
    if not cfg then return nil end

    local patient = cache.ped
    if not patient or patient == 0 or not DoesEntityExist(patient) then return nil end

    lib.requestModel(cfg.model, 10000)
    if not HasModelLoaded(cfg.model) then return nil end

    local offset = cfg.offset or { x = 0.9, y = 0.2, z = -0.95 }
    local spawnPos = GetOffsetFromEntityInWorldCoords(patient, offset.x, offset.y, offset.z)
    local spawnZ = bedCoords.z + (cfg.zCorrection or -0.92)

    RequestCollisionAtCoord(spawnPos.x, spawnPos.y, spawnZ)
    Wait(100)

    local ped = CreatePed(0, cfg.model, spawnPos.x, spawnPos.y, spawnZ, bedCoords.w, false, true)
    if not ped or ped == 0 then return nil end

    SetModelAsNoLongerNeeded(cfg.model)
    SetPedDefaultComponentVariation(ped)
    configureDoctorPed(ped)
    SetEntityVisible(ped, true, false)

    local anim = cfg.anims[treatment] or cfg.anims.treat
    TaskTurnPedToFaceEntity(ped, patient, 1000)

    bedsideDoctor = { ped = ped, active = true, anim = anim }

    CreateThread(function()
        Wait(1000)
        while bedsideDoctor and bedsideDoctor.active and DoesEntityExist(ped) do
            if anim and anim.dict and anim.clip then
                if not IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) then
                    playDoctorAnim(ped, anim)
                end
            end
            Wait(1500)
        end
    end)

    return ped
end

function W2FAmbulance.Reception.stopBedsideTreatment()
    cleanupBedsideDoctor()
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanupBedsideDoctor()
end)
