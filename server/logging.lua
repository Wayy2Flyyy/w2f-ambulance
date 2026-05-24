W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Logging = W2FAmbulance.Logging or {}

local Logging = W2FAmbulance.Logging

---Write an audit log entry. All fields are optional except logType and action.
---@param logType string  e.g. 'personnel' | 'patient' | 'access' | 'announcement'
---@param action string   e.g. 'hire' | 'fire' | 'clinical_note' | 'tablet_open'
---@param actorCid string
---@param actorName string
---@param targetCid string
---@param targetName string
---@param message string
---@param metadata table|nil
function Logging.write(logType, action, actorCid, actorName, targetCid, targetName, message, metadata)
    local metaJson = ''
    if type(metadata) == 'table' then
        local ok, encoded = pcall(json.encode, metadata)
        if ok then metaJson = encoded end
    end

    pcall(function()
        MySQL.insert.await(
            'INSERT INTO w2f_ambulance_audit_logs (log_type, action, actor_cid, actor_name, target_cid, target_name, message, metadata_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            {
                logType or 'system',
                action or 'unknown',
                actorCid or '',
                actorName or 'System',
                targetCid or '',
                targetName or '',
                message or '',
                metaJson,
            }
        )
    end)
end

---Query audit logs with optional filters and pagination.
---@param filters table  { logType?, actorCid?, targetCid?, limit?, offset? }
---@return table rows
function Logging.query(filters)
    filters = type(filters) == 'table' and filters or {}
    local limit = math.min(tonumber(filters.limit) or 100, 200)
    local offset = tonumber(filters.offset) or 0

    local where = {}
    local params = {}

    if type(filters.logType) == 'string' and filters.logType ~= '' then
        where[#where + 1] = 'log_type = ?'
        params[#params + 1] = filters.logType
    end

    if type(filters.actorCid) == 'string' and filters.actorCid ~= '' then
        where[#where + 1] = 'actor_cid = ?'
        params[#params + 1] = filters.actorCid
    end

    if type(filters.targetCid) == 'string' and filters.targetCid ~= '' then
        where[#where + 1] = 'target_cid = ?'
        params[#params + 1] = filters.targetCid
    end

    local whereClause = #where > 0 and ('WHERE ' .. table.concat(where, ' AND ')) or ''
    params[#params + 1] = limit
    params[#params + 1] = offset

    local ok, rows = pcall(function()
        return MySQL.query.await(
            'SELECT id, log_type, action, actor_cid, actor_name, target_cid, target_name, message, metadata_json, created_at '
            .. 'FROM w2f_ambulance_audit_logs '
            .. whereClause
            .. ' ORDER BY created_at DESC LIMIT ? OFFSET ?',
            params
        )
    end)

    return (ok and rows) or {}
end

---Count today's log entries for dashboard stats.
---@return number
function Logging.countToday()
    local ok, count = pcall(function()
        return MySQL.scalar.await(
            'SELECT COUNT(*) FROM w2f_ambulance_audit_logs WHERE DATE(created_at) = CURDATE()'
        )
    end)
    return (ok and tonumber(count)) or 0
end
