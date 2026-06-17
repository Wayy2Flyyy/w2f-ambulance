W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Core = W2FAmbulance.Core or {}

W2FAmbulance.Core.Resource = 'w2f-ambulance'
W2FAmbulance.Core.Version = '1.4.0'

---@param player table|nil
---@return boolean
function W2FAmbulance.Core.isEmsOnDuty(player)
    if not player or not player.PlayerData then return false end
    local job = player.PlayerData.job
    return job and job.type == 'ems' and job.onduty == true
end

---@param player table|nil
---@return integer
function W2FAmbulance.Core.getGrade(player)
    if not player or not player.PlayerData or not player.PlayerData.job then return -1 end
    local job = player.PlayerData.job
    if job.type ~= 'ems' then return -1 end
    return job.grade and (job.grade.level or job.grade) or 0
end

---@param player table|nil
---@param permission string
---@return boolean
function W2FAmbulance.Core.hasPermission(player, permission)
    return W2FAmbulance.Permissions.Has(W2FAmbulance.Core.getGrade(player), permission)
end

---@param player table|nil
---@return string
function W2FAmbulance.Core.getCharFullName(player)
    if not player or not player.PlayerData then return 'Unknown' end
    local charinfo = player.PlayerData.charinfo or {}
    local first = charinfo.firstname or ''
    local last = charinfo.lastname or ''
    local fullName = ('%s %s'):format(first, last):match('^%s*(.-)%s*$') or ''
    if fullName == '' then return 'Unknown' end
    return fullName
end

---@param player table|nil
---@return table metadata
function W2FAmbulance.Core.prescriptionPadMetadata(player)
    return {
        description = ('Prescribed by %s'):format(W2FAmbulance.Core.getCharFullName(player)),
    }
end

---@param itemName string
---@return boolean
function W2FAmbulance.Core.isPrescriptionPadItem(itemName)
    local required = (Config.Pharmacy and Config.Pharmacy.itemRequired) or 'medical_prescription'
    return itemName == required
end

---@param player table|nil
---@return string
function W2FAmbulance.Core.getRankLabel(player)
    return W2FAmbulance.Ranks.GetLabel(W2FAmbulance.Core.getGrade(player))
end
