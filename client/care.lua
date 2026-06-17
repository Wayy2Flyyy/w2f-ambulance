W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.CareClient = W2FAmbulance.CareClient or {}

---Consume a care item after a failed minigame (success uses the care server event).
---@param scenarioId string
---@param success boolean
---@param cancelled boolean
---@param itemOverride? string
function W2FAmbulance.CareClient.handleMinigameResult(scenarioId, success, cancelled, itemOverride)
    if cancelled or success then return end

    local item = itemOverride or W2FAmbulance.Care.getItem(scenarioId)
    if not item then return end

    TriggerServerEvent('w2f-ambulance:server:consumeCareItem', scenarioId, itemOverride)
end
