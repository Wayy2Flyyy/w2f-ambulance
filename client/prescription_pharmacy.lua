--- Pillbox pharmacy clerk NPC + blip.

local ped
local blip

local function pharmacyCfg()
    return Config.Pharmacy or {}
end

local function hasPrescription()
    local cfg = pharmacyCfg()
    local ok, count = pcall(function()
        return exports.ox_inventory:Search('count', cfg.itemRequired or 'medical_prescription')
    end)
    return ok and type(count) == 'number' and count > 0
end

local function openPharmacy()
    local cfg = pharmacyCfg()
    if not hasPrescription() then
        lib.notify({
            title = 'Pharmacy',
            description = 'You need a medical prescription from EMS before buying medications.',
            type = 'error',
        })
        return
    end

    exports.ox_inventory:openInventory('shop', { type = cfg.shopType or 'W2FPharmacy' })
end

local function cleanup()
    if ped and DoesEntityExist(ped) then
        pcall(function() exports.ox_target:removeLocalEntity(ped) end)
        DeleteEntity(ped)
        ped = nil
    end
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
        blip = nil
    end
end

local function createBlip(cfg)
    if not cfg.blip or not cfg.blip.enabled then return end
    local c = cfg.coords
    blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, cfg.blip.sprite or 51)
    SetBlipColour(blip, cfg.blip.colour or 2)
    SetBlipScale(blip, cfg.blip.scale or 0.75)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(cfg.blip.label or 'Pharmacy')
    EndTextCommandSetBlipName(blip)
end

local function spawnPharmacist()
    local cfg = pharmacyCfg()
    if type(cfg) ~= 'table' or cfg.shopType ~= 'W2FPharmacy' then return end

    cleanup()

    local c = cfg.coords --[[@as vector3]]
    lib.requestModel(cfg.model, 10000)

    ped = CreatePed(0, cfg.model, c.x, c.y, c.z - 1.0, cfg.heading, false, true)
    if not ped or ped == 0 then return end

    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)

    if cfg.scenario then
        TaskStartScenarioInPlace(ped, cfg.scenario, 0, true)
    end

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'w2f_ambulance_pharmacy_open',
            icon = cfg.targetIcon,
            label = cfg.targetLabel,
            distance = cfg.targetDistance or 2.4,
            canInteract = hasPrescription,
            onSelect = openPharmacy,
        },
        {
            name = 'w2f_ambulance_pharmacy_info',
            icon = 'fa-solid fa-circle-info',
            label = cfg.targetLabelNoRx or 'Pharmacy (prescription required)',
            distance = cfg.targetDistance or 2.4,
            canInteract = function()
                return not hasPrescription()
            end,
            onSelect = function()
                lib.notify({
                    title = 'Pharmacy',
                    description = 'Ask on-duty EMS for a medical prescription, then return here.',
                    type = 'inform',
                })
            end,
        },
    })

    createBlip(cfg)
end

CreateThread(function()
    local deadline = GetGameTimer() + 30000
    while GetResourceState('ox_target') ~= 'started' and GetGameTimer() < deadline do
        Wait(200)
    end
    if GetResourceState('ox_target') ~= 'started' then return end

    lib.waitFor(function()
        return cache.ped
    end, 'player ped unavailable', 90000)

    spawnPharmacist()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then cleanup() end
end)

exports('usePrescription', function(_data)
    lib.notify({
        title = 'Medical Prescription',
        description = 'Take this to the Pillbox pharmacy clerk to purchase prescribed medications.',
        type = 'inform',
    })
end)
