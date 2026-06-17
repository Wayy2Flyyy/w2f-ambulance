W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Client = W2FAmbulance.Client or {}

---@return boolean
function W2FAmbulance.Client.isEmsOnDuty()
    if not QBX or not QBX.PlayerData or not QBX.PlayerData.job then return false end
    local job = QBX.PlayerData.job
    return job.type == 'ems' and job.onduty == true
end

---@return integer
function W2FAmbulance.Client.getGrade()
    if not QBX or not QBX.PlayerData or not QBX.PlayerData.job then return -1 end
    local job = QBX.PlayerData.job
    if job.type ~= 'ems' then return -1 end
    return job.grade and job.grade.level or 0
end

---@param permission string
---@return boolean
function W2FAmbulance.Client.hasPermission(permission)
    return W2FAmbulance.Permissions.Has(W2FAmbulance.Client.getGrade(), permission)
end

---@return boolean
function W2FAmbulance.Client.hasPrescriptionPad()
    local item = (Config.Pharmacy and Config.Pharmacy.itemRequired) or 'medical_prescription'
    local count = exports.ox_inventory:Search('count', item)
    return type(count) == 'number' and count > 0
end

---@return string
function W2FAmbulance.Client.getRankLabel()
    return W2FAmbulance.Ranks.GetLabel(W2FAmbulance.Client.getGrade())
end

---@param permission string
function W2FAmbulance.Client.notifyRankDenied(permission)
    local needed = W2FAmbulance.Permissions.GetMinRank(permission)
    exports.qbx_core:Notify(
        locale('error.rank_required', W2FAmbulance.Ranks.GetLabel(needed)),
        'error'
    )
end
