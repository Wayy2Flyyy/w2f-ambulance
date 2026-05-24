W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Care = W2FAmbulance.Care or {}

local Care = W2FAmbulance.Care

local ITEM_ERRORS = {
    bandage = 'error.no_bandage',
    ifaks = 'error.no_ifaks',
    firstaid = 'error.no_firstaid',
}

---@param src number
---@param scenarioId string
---@param itemOverride? string
---@return boolean removed
function Care.consumeItem(src, scenarioId, itemOverride)
    local item = itemOverride or W2FAmbulance.Care.getItem(scenarioId)
    if not item then return true end
    return exports.ox_inventory:RemoveItem(src, item, 1) == true
end

---@param src number
---@param item string
function Care.notifyMissingItem(src, item)
    local key = ITEM_ERRORS[item] or 'error.impossible'
    exports.qbx_core:Notify(src, locale(key), 'error')
end

RegisterNetEvent('w2f-ambulance:server:consumeCareItem', function(scenarioId, itemOverride)
    if GetInvokingResource() then return end
    if type(scenarioId) ~= 'string' then return end

    local src = source
    local item = (type(itemOverride) == 'string' and itemOverride ~= '') and itemOverride
        or W2FAmbulance.Care.getItem(scenarioId)
    if not item then return end

    if Care.consumeItem(src, scenarioId, item) then
        exports.qbx_core:Notify(src, locale('error.care_item_wasted'), 'error')
    else
        Care.notifyMissingItem(src, item)
    end
end)
