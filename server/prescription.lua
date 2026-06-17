W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Prescription = W2FAmbulance.Prescription or {}

local Rx = W2FAmbulance.Prescription
local Pharmacy = Config.Pharmacy or {}

local hookIds = {}

local function pharmacyCfg()
    return Config.Pharmacy or Pharmacy
end

function Rx.hasPrescription(src)
    local cfg = pharmacyCfg()
    local item = cfg.itemRequired or 'medical_prescription'
    local count = exports.ox_inventory:GetItemCount(src, item)
    return type(count) == 'number' and count > 0
end

function Rx.notify(src, description, nType)
    lib.notify(src, {
        title = 'Pharmacy',
        description = description,
        type = nType or 'inform',
        position = 'top',
    })
end

function Rx.registerShop()
    if GetResourceState('ox_inventory') ~= 'started' then return false end

    local cfg = pharmacyCfg()
    if not cfg.shopType or not cfg.inventory then return false end

    exports.ox_inventory:RegisterShop(cfg.shopType, {
        name = cfg.hookShopLabel or 'Medical Pharmacy',
        icon = cfg.targetIcon or 'fa-solid fa-pills',
        inventory = cfg.inventory,
    })

    return true
end

function Rx.registerHooks()
    if GetResourceState('ox_inventory') ~= 'started' then return false end

    local cfg = pharmacyCfg()
    local shopType = cfg.shopType
    local shopLabel = cfg.hookShopLabel

    if shopType ~= 'W2FPharmacy' or type(shopLabel) ~= 'string' or shopLabel == '' then
        return false
    end

    for i = 1, #hookIds do
        pcall(function() exports.ox_inventory:removeHooks(hookIds[i]) end)
    end
    hookIds = {}

    hookIds[#hookIds + 1] = exports.ox_inventory:registerHook('openShop', function(payload)
        local isPharmacy = payload.label == shopLabel or payload.shopType == shopType
        if not isPharmacy then return end

        if not Rx.hasPrescription(payload.source) then
            Rx.notify(payload.source, 'You need a valid medical prescription for this clerk.', 'error')
            return false
        end

        if cfg.consumeOnOpen then
            local item = cfg.itemRequired or 'medical_prescription'
            exports.ox_inventory:RemoveItem(payload.source, item, 1)
        end
    end)

    hookIds[#hookIds + 1] = exports.ox_inventory:registerHook('buyItem', function(payload)
        if payload.shopType ~= shopType then return end
        if cfg.consumeOnOpen then return end
        if Rx.hasPrescription(payload.source) then return end
        Rx.notify(payload.source, 'You need a valid medical prescription for this clerk.', 'error')
        return false
    end, { typeFilter = { [shopType] = true } })

    return true
end

function Rx.bootstrap()
    local ok = Rx.registerShop()
    local hooks = Rx.registerHooks()
    if ok and hooks then
        print('[w2f-ambulance] Pharmacy shop + hooks registered')
    end
    return ok and hooks
end

---@param medicSrc number
---@param patientSrc number
---@return boolean
function Rx.issueToPatient(medicSrc, patientSrc)
    local medic = exports.qbx_core:GetPlayer(medicSrc)
    local patient = exports.qbx_core:GetPlayer(patientSrc)
    if not medic or not patient then return false end
    if not W2FAmbulance.Core.isEmsOnDuty(medic) then return false end
    if not W2FAmbulance.Core.hasPermission(medic, 'IssuePrescription') then
        exports.qbx_core:Notify(medicSrc, locale('error.rank_required', W2FAmbulance.Ranks.GetLabel(
            W2FAmbulance.Permissions.GetMinRank('IssuePrescription')
        )), 'error')
        return false
    end

    local cfg = pharmacyCfg()
    local item = cfg.itemRequired or 'medical_prescription'

    local medicCount = exports.ox_inventory:GetItemCount(medicSrc, item)
    if type(medicCount) ~= 'number' or medicCount < 1 then
        exports.qbx_core:Notify(medicSrc, locale('error.no_prescription_pad'), 'error')
        return false
    end

    if not exports.ox_inventory:RemoveItem(medicSrc, item, 1) then
        exports.qbx_core:Notify(medicSrc, locale('error.prescription_remove_failed'), 'error')
        return false
    end

    if not exports.ox_inventory:AddItem(patient.PlayerData.source, item, 1, W2FAmbulance.Core.prescriptionPadMetadata(medic)) then
        exports.ox_inventory:AddItem(medicSrc, item, 1)
        exports.qbx_core:Notify(medicSrc, locale('error.prescription_issue_failed'), 'error')
        return false
    end

    exports.qbx_core:Notify(medicSrc, 'Prescription issued.', 'success')
    exports.qbx_core:Notify(patient.PlayerData.source, 'You received a medical prescription. Visit the Pillbox pharmacy clerk.', 'inform')

    if W2FAmbulance.Records then
        W2FAmbulance.Records.create(
            patient.PlayerData.citizenid,
            W2FAmbulance.Core.getCharFullName(medic),
            'Medical prescription issued'
        )
    end
    if W2FAmbulance.PublicRecords then
        W2FAmbulance.PublicRecords.logVisit(
            patient,
            medic,
            'prescription',
            'Medical prescription issued by EMS for pharmacy pickup.'
        )
    end

    return true
end

CreateThread(function()
    for _ = 1, 40 do
        if GetResourceState('ox_inventory') == 'started' and Rx.bootstrap() then return end
        Wait(500)
    end
    print('[w2f-ambulance] WARN: Pharmacy hooks failed to register — restart after ox_inventory')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'ox_inventory' or resourceName == GetCurrentResourceName() then
        CreateThread(function()
            Wait(1000)
            Rx.bootstrap()
        end)
    end
end)

RegisterNetEvent('w2f-ambulance:server:issuePrescription', function(targetId)
    if GetInvokingResource() then return end
    Rx.issueToPatient(source, targetId)
end)

exports('IssuePrescription', function(medicSrc, patientSrc)
    return Rx.issueToPatient(medicSrc, patientSrc)
end)
