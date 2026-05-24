W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Records = W2FAmbulance.Records or {}

local Records = W2FAmbulance.Records
local Identity = W2FAmbulance.Identity

---@param row table
---@return table
local function enrichRow(row)
    row.patient_name = Identity.fullNameFromCitizenId(row.citizenid)
    row.author_name = Identity.resolveAuthorDisplay(row.author)
    return row
end

---@param citizenid string
---@param author string
---@param notes string
---@return table|nil
function Records.create(citizenid, author, notes)
    if not citizenid or not author then return nil end

    local id = MySQL.insert.await(
        'INSERT INTO w2f_ambulance_records (citizenid, author, notes) VALUES (?, ?, ?)',
        { citizenid, author, notes or '' }
    )

    return enrichRow({
        id = id,
        citizenid = citizenid,
        author = author,
        notes = notes or '',
    })
end

---@param citizenid string
---@param limit? number
---@return table
function Records.fetchByCitizen(citizenid, limit)
    limit = limit or 25
    local rows = MySQL.query.await(
        'SELECT id, citizenid, author, notes, created_at FROM w2f_ambulance_records WHERE citizenid = ? ORDER BY created_at DESC LIMIT ?',
        { citizenid, limit }
    ) or {}

    for i = 1, #rows do
        enrichRow(rows[i])
    end
    return rows
end

---@param query string
---@param limit? number
---@return table rows
---@return string|nil patientName
---@return string|nil citizenid
function Records.fetchByQuery(query, limit)
    local citizenid, matches = Identity.resolveCitizenQuery(query)
    if not citizenid then
        return {}, nil, nil
    end

    local rows = Records.fetchByCitizen(citizenid, limit or 50)
    return rows, Identity.fullNameFromCitizenId(citizenid), citizenid
end

exports('CreateRecord', function(citizenid, author, notes)
    return Records.create(citizenid, author, notes)
end)

lib.callback.register('w2f-ambulance:server:getRecords', function(_, citizenid)
    return Records.fetchByCitizen(citizenid)
end)

RegisterNetEvent('w2f-ambulance:server:createRecord', function(targetId, notes)
    if GetInvokingResource() then return end
    local src = source
    local medic = exports.qbx_core:GetPlayer(src)
    local patient = exports.qbx_core:GetPlayer(targetId)
    if not medic or not patient then return end
    if medic.PlayerData.job.type ~= 'ems' then return end

    Records.create(
        patient.PlayerData.citizenid,
        W2FAmbulance.Core.getCharFullName(medic),
        notes or ''
    )
end)
