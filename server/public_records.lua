W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.PublicRecords = W2FAmbulance.PublicRecords or {}

local PublicRecords = W2FAmbulance.PublicRecords
local cfg = Config.PublicRecords or {}

local function patientName(player)
    local info = player.PlayerData.charinfo or {}
    local first = info.firstname or ''
    local last = info.lastname or ''
    local full = ('%s %s'):format(first, last):match('^%s*(.-)%s*$') or ''
    if full == '' then return player.PlayerData.citizenid or 'Unknown' end
    return full
end

local function providerName(player)
    local info = player.PlayerData.charinfo or {}
    local first = info.firstname or ''
    local last = info.lastname or ''
    return ('Dr. %s %s'):format(first, last)
end

local function visitLabel(visitType)
    local types = cfg.visitTypes or {}
    return types[visitType] or visitType or 'Medical Visit'
end

---@param patient table qbx player
---@param provider table|nil qbx player
---@param visitType string
---@param summary string
---@return table|nil
function PublicRecords.create(patient, provider, visitType, summary)
    if not patient then return nil end
    if type(summary) ~= 'string' or summary == '' then return nil end

    local providerPlayer = provider or patient
    local id = MySQL.insert.await([[
        INSERT INTO w2f_ems_public_records
            (citizenid, patient_name, visit_type, summary, provider_name, provider_cid, facility)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        patient.PlayerData.citizenid,
        patientName(patient),
        visitLabel(visitType),
        summary,
        providerName(providerPlayer),
        providerPlayer.PlayerData.citizenid,
        cfg.facility or 'Pillbox Hospital',
    })

    return {
        id = id,
        citizenid = patient.PlayerData.citizenid,
        patient_name = patientName(patient),
        visit_type = visitLabel(visitType),
        summary = summary,
        provider_name = providerName(providerPlayer),
        provider_cid = providerPlayer.PlayerData.citizenid,
        facility = cfg.facility or 'Pillbox Hospital',
    }
end

---@param patient table
---@param provider table|nil
---@param visitType string
---@param summary string
function PublicRecords.logVisit(patient, provider, visitType, summary)
    if cfg.autoPublish == false then return end
    pcall(function()
        PublicRecords.create(patient, provider, visitType, summary)
    end)
end

---@param citizenid string
---@param limit? number
---@return table
function PublicRecords.fetchByCitizen(citizenid, limit)
    if not citizenid or citizenid == '' then return {} end
    limit = limit or 50
    return MySQL.query.await([[
        SELECT id, citizenid, patient_name, visit_type, summary, provider_name, provider_cid, facility, created_at
        FROM w2f_ems_public_records
        WHERE citizenid = ?
        ORDER BY created_at DESC
        LIMIT ?
    ]], { citizenid, limit }) or {}
end

---@param query string
---@param limit? number
---@return table rows
---@return string|nil patientName
---@return string|nil citizenid
function PublicRecords.fetchByQuery(query, limit)
    limit = limit or 50
    if type(query) ~= 'string' or query == '' then return {}, nil, nil end

    local trimmed = query:gsub('^%s+', ''):gsub('%s+$', '')
    local citizenid, matches = W2FAmbulance.Identity.resolveCitizenQuery(trimmed)
    if citizenid then
        return PublicRecords.fetchByCitizen(citizenid, limit),
            W2FAmbulance.Identity.fullNameFromCitizenId(citizenid),
            citizenid
    end

    local pattern = '%' .. trimmed:gsub("'", "''") .. '%'
    local rows = MySQL.query.await([[
        SELECT id, citizenid, patient_name, visit_type, summary, provider_name, provider_cid, facility, created_at
        FROM w2f_ems_public_records
        WHERE patient_name LIKE ? OR citizenid LIKE ?
        ORDER BY created_at DESC
        LIMIT ?
    ]], { pattern, pattern, limit }) or {}

    if #rows == 0 then return {}, nil, nil end
    return rows, rows[1].patient_name, rows[1].citizenid
end

exports('CreatePublicRecord', function(citizenid, visitType, summary, providerCid)
    local patient = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if not patient then return nil end
    local provider = providerCid and exports.qbx_core:GetPlayerByCitizenId(providerCid) or nil
    return PublicRecords.create(patient, provider, visitType, summary)
end)

exports('GetPublicRecords', function(citizenid, limit)
    return PublicRecords.fetchByCitizen(citizenid, limit)
end)
