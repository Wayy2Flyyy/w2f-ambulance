W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Identity = W2FAmbulance.Identity or {}

local Identity = W2FAmbulance.Identity

---@param charinfo table|string|nil
---@return table
local function decodeCharinfo(charinfo)
    if type(charinfo) == 'table' then return charinfo end
    if type(charinfo) == 'string' and charinfo ~= '' then
        local ok, decoded = pcall(json.decode, charinfo)
        if ok and type(decoded) == 'table' then return decoded end
    end
    return {}
end

---@param charinfo table|nil
---@return string
local function nameFromCharinfo(charinfo)
    charinfo = decodeCharinfo(charinfo)
    local first = charinfo.firstname or ''
    local last = charinfo.lastname or ''
    local fullName = ('%s %s'):format(first, last):match('^%s*(.-)%s*$') or ''
    if fullName == '' then return 'Unknown' end
    return fullName
end

---@param row table
---@return table
local function profileFromRow(row)
    local info = decodeCharinfo(row.charinfo)
    local citizenid = row.citizenid
    return {
        citizenid = citizenid,
        name = nameFromCharinfo(info),
        phone = info.phone or '',
        dob = info.birthdate or '',
        online = exports.qbx_core:GetPlayerByCitizenId(citizenid) ~= nil,
    }
end

---@param player table
---@return table
local function profileFromPlayer(player)
    local info = player.PlayerData.charinfo or {}
    return {
        citizenid = player.PlayerData.citizenid,
        name = W2FAmbulance.Core.getCharFullName(player),
        phone = info.phone or '',
        dob = info.birthdate or '',
        online = true,
    }
end

---@param citizenid string
---@return table|nil
function Identity.getCitizenProfile(citizenid)
    if not citizenid or citizenid == '' then return nil end

    local online = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if online then return profileFromPlayer(online) end

    local offline = exports.qbx_core:GetOfflinePlayer(citizenid)
    if offline and offline.PlayerData then return profileFromPlayer(offline) end

    local ok, row = pcall(function()
        return MySQL.single.await(
            'SELECT citizenid, charinfo FROM players WHERE citizenid = ? LIMIT 1',
            { citizenid }
        )
    end)
    if ok and row then return profileFromRow(row) end
    return nil
end

---@param citizenid string
---@return string
function Identity.fullNameFromCitizenId(citizenid)
    local profile = Identity.getCitizenProfile(citizenid)
    return profile and profile.name or citizenid or 'Unknown'
end

---@param author string
---@return string
function Identity.resolveAuthorDisplay(author)
    if not author or author == '' then return 'Unknown' end
    if author:find('%s') then return author end
    return Identity.fullNameFromCitizenId(author)
end

---@param limit? number
---@return table[]
function Identity.listOnlineCitizens(limit)
    limit = limit or 50
    local out = {}
    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if player.PlayerData and player.PlayerData.citizenid then
            out[#out + 1] = profileFromPlayer(player)
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    if #out > limit then
        local trimmed = {}
        for i = 1, limit do trimmed[i] = out[i] end
        return trimmed
    end
    return out
end

---@param limit? number
---@return table[]
function Identity.listCitizens(limit)
    limit = limit or 100
    local out = {}
    local rows = MySQL.query.await([[
        SELECT citizenid, charinfo
        FROM players
        ORDER BY last_updated DESC
        LIMIT ?
    ]], { limit }) or {}

    for i = 1, #rows do
        out[#out + 1] = profileFromRow(rows[i])
    end

    table.sort(out, function(a, b)
        if a.online ~= b.online then return a.online end
        return a.name < b.name
    end)
    return out
end

---@param query string
---@param limit? number
---@return table[]
function Identity.searchCitizens(query, limit)
    limit = limit or 80
    if type(query) ~= 'string' then query = '' end

    local trimmed = query:gsub('^%s+', ''):gsub('%s+$', '')
    if trimmed == '' then
        return Identity.listCitizens(limit)
    end

    local lower = trimmed:lower()
    local out = {}
    local seen = {}

    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        local profile = profileFromPlayer(player)
        local cid = profile.citizenid
        if cid and (
            cid:lower():find(lower, 1, true)
            or profile.name:lower():find(lower, 1, true)
            or (profile.phone ~= '' and profile.phone:find(trimmed, 1, true))
        ) then
            if not seen[cid] then
                seen[cid] = true
                out[#out + 1] = profile
            end
        end
    end

    local pattern = '%' .. trimmed:gsub("'", "''") .. '%'
    local ok, rows = pcall(function()
        return MySQL.query.await([[
            SELECT citizenid, charinfo
            FROM players
            WHERE citizenid LIKE ?
               OR charinfo LIKE ?
               OR LOWER(CONCAT(
                    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ''),
                    ' ',
                    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')), '')
               )) LIKE LOWER(?)
               OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) LIKE ?
            ORDER BY citizenid ASC
            LIMIT ?
        ]], { pattern, pattern, pattern, pattern, limit })
    end)

    if ok and rows then
        for i = 1, #rows do
            local row = rows[i]
            if row.citizenid and not seen[row.citizenid] then
                seen[row.citizenid] = true
                out[#out + 1] = profileFromRow(row)
            end
        end
    end

    table.sort(out, function(a, b)
        if a.online ~= b.online then return a.online end
        return a.name < b.name
    end)

    if #out > limit then
        local trimmedOut = {}
        for i = 1, limit do trimmedOut[i] = out[i] end
        return trimmedOut
    end

    return out
end

---@param query string
---@return string|nil citizenid
---@return table[]|nil matches
function Identity.resolveCitizenQuery(query)
    local results = Identity.searchCitizens(query, 30)
    if #results == 0 then return nil end

    local trimmed = query:gsub('^%s+', ''):gsub('%s+$', '')
    local lower = trimmed:lower()

    for i = 1, #results do
        if results[i].citizenid == trimmed then
            return results[i].citizenid
        end
    end

    for i = 1, #results do
        if results[i].name:lower() == lower then
            return results[i].citizenid
        end
    end

    if #results == 1 then
        return results[1].citizenid
    end

    return nil, results
end

---@param citizenid string
---@return table|nil player-like
function Identity.getPatientPlayer(citizenid)
    local online = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if online then return online end

    local offline = exports.qbx_core:GetOfflinePlayer(citizenid)
    if offline and offline.PlayerData then return offline end

    local ok, row = pcall(function()
        return MySQL.single.await(
            'SELECT citizenid, charinfo FROM players WHERE citizenid = ? LIMIT 1',
            { citizenid }
        )
    end)
    if not ok or not row then return nil end

    return {
        PlayerData = {
            citizenid = row.citizenid,
            charinfo = decodeCharinfo(row.charinfo),
        },
    }
end

---@param player table|nil
---@return string
function Identity.providerLabel(player)
    if not player then return 'Unknown Provider' end
    return ('Dr. %s'):format(W2FAmbulance.Core.getCharFullName(player))
end
