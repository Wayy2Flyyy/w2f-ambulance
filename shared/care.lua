W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Care = W2FAmbulance.Care or {}

---@param scenarioId string
---@return string|nil
function W2FAmbulance.Care.getItem(scenarioId)
    local items = Config.Minigame and Config.Minigame.careItems or {}
    return items[scenarioId]
end
