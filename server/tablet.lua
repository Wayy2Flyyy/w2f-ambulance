W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Tablet = W2FAmbulance.Tablet or {}

local Tablet = W2FAmbulance.Tablet
local Identity = W2FAmbulance.Identity
local Logging = W2FAmbulance.Logging

local function fetchAnnouncements(limit)
    limit = limit or 20
    return MySQL.query.await([[
        SELECT id, author, message, created_at
        FROM w2f_ambulance_announcements
        ORDER BY created_at DESC
        LIMIT ?
    ]], { limit }) or {}
end

local function notify(src, message, nType)
    exports.qbx_core:Notify(src, message, nType or 'inform')
end

local function isHighCommand(player)
    return W2FAmbulance.Core.hasPermission(player, 'HighCommandAccess')
end

local function maxAssignable(actorGrade)
    return math.min(W2FAmbulance.Ranks.GetMax() - 1, actorGrade - 1)
end

local function resolveTargetQuery(src, query)
    if type(query) ~= 'string' or query == '' then
        notify(src, 'Enter a full name or citizen ID.', 'error')
        return nil
    end

    local citizenid, matches = Identity.resolveCitizenQuery(query)
    if citizenid then return citizenid end

    if matches and #matches > 1 then
        notify(src, ('Multiple matches for "%s" — be more specific.'):format(query), 'error')
    else
        notify(src, ('No citizen found for "%s".'):format(query), 'error')
    end
    return nil
end

local function listPersonnel()
    local rows = {}
    local onlineByCid = {}
    local players = exports.qbx_core:GetQBPlayers()

    for _, player in pairs(players) do
        local data = player.PlayerData
        local cid = data and data.citizenid
        if cid then
            onlineByCid[cid] = player
        end
    end

    local dbRows = MySQL.query.await([[
        SELECT citizenid, charinfo, job
        FROM players
    ]]) or {}

    local function decodeCharinfo(charinfo)
        if type(charinfo) == 'table' then return charinfo end
        if type(charinfo) == 'string' and charinfo ~= '' then
            local ok, decoded = pcall(json.decode, charinfo)
            if ok and type(decoded) == 'table' then return decoded end
        end
        return {}
    end

    local function fullNameFromCharinfo(charinfo)
        local info = decodeCharinfo(charinfo)
        local first = info.firstname or ''
        local last = info.lastname or ''
        local fullName = ('%s %s'):format(first, last):match('^%s*(.-)%s*$') or ''
        if fullName == '' then return 'Unknown' end
        return fullName
    end

    for i = 1, #dbRows do
        local row = dbRows[i]
        local jobData
        if type(row.job) == 'string' and row.job ~= '' then
            local ok, decoded = pcall(json.decode, row.job)
            if ok and type(decoded) == 'table' then
                jobData = decoded
            end
        elseif type(row.job) == 'table' then
            jobData = row.job
        end

        if jobData and jobData.name == Config.JobName then
            local grade = jobData.grade
            if type(grade) == 'table' then
                grade = grade.level or grade.grade or grade.value
            end
            grade = tonumber(grade) or 0

            local onlinePlayer = onlineByCid[row.citizenid]
            local name = fullNameFromCharinfo(row.charinfo)
            if onlinePlayer then
                name = W2FAmbulance.Core.getCharFullName(onlinePlayer)
            end
            local onduty = false
            if onlinePlayer and onlinePlayer.PlayerData and onlinePlayer.PlayerData.job then
                onduty = onlinePlayer.PlayerData.job.onduty == true
            elseif jobData.onduty ~= nil then
                onduty = jobData.onduty == true
            end

            rows[#rows + 1] = {
                citizenid = row.citizenid,
                name = name,
                grade = grade,
                rankLabel = W2FAmbulance.Ranks.GetLabel(grade),
                onduty = onduty,
                online = onlinePlayer ~= nil,
                source = onlinePlayer and onlinePlayer.PlayerData and onlinePlayer.PlayerData.source or nil,
            }
        end
    end

    table.sort(rows, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return (a.name or '') < (b.name or '')
    end)
    return rows
end

function Tablet.getDashboard(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not isHighCommand(player) then return nil end

    local grade = W2FAmbulance.Core.getGrade(player)
    local onDuty = 0
    local personnel = listPersonnel()
    for i = 1, #personnel do
        if personnel[i].onduty then onDuty += 1 end
    end

    local ranks = {}
    for _, row in ipairs(W2FAmbulance.Ranks.List()) do
        ranks[#ranks + 1] = { grade = row.grade, label = row.label, shortName = row.shortName }
    end

    local announcements = fetchAnnouncements(20)
    local logCount = Logging.countToday()
    local recentLogs = Logging.query({ limit = 5 })

    local actorName = W2FAmbulance.Core.getCharFullName(player)
    local actorCid = player.PlayerData.citizenid
    Logging.write('access', 'tablet_open', actorCid, actorName, '', '', ('Tablet opened by %s'):format(actorName))

    return {
        officer = {
            name = actorName,
            grade = grade,
            rankLabel = W2FAmbulance.Ranks.GetLabel(grade),
            rankShort = W2FAmbulance.Ranks.GetShort(grade),
        },
        stats = {
            onDuty = onDuty,
            roster = #personnel,
            announcements = #announcements,
            logCount = logCount,
        },
        personnel = personnel,
        ranks = ranks,
        announcements = announcements,
        recentLogs = recentLogs,
        permissions = {
            canManagePersonnel = W2FAmbulance.Core.hasPermission(player, 'ManagePersonnel'),
            canManageDepartment = W2FAmbulance.Core.hasPermission(player, 'ManageDepartment'),
            isHighCommand = true,
        },
    }
end

function Tablet.hire(src, query, grade)
    local actor = exports.qbx_core:GetPlayer(src)
    if not actor or not W2FAmbulance.Core.hasPermission(actor, 'ManagePersonnel') then return false end

    local citizenid = resolveTargetQuery(src, query)
    if not citizenid then return false end

    grade = math.max(0, math.min(tonumber(grade) or 0, maxAssignable(W2FAmbulance.Core.getGrade(actor))))
    local targetName = Identity.fullNameFromCitizenId(citizenid)
    local target = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if target then
        target.Functions.SetJob(Config.JobName, grade)
    else
        exports.qbx_core:SetJob(citizenid, Config.JobName, grade)
    end

    local actorName = W2FAmbulance.Core.getCharFullName(actor)
    local actorCid = actor.PlayerData.citizenid
    local rankLabel = W2FAmbulance.Ranks.GetLabel(grade)
    notify(src, ('Hired %s as %s'):format(targetName, rankLabel), 'success')
    Logging.write('personnel', 'hire', actorCid, actorName, citizenid, targetName,
        ('Hired %s as %s'):format(targetName, rankLabel),
        { grade = grade, rankLabel = rankLabel })
    return true
end

function Tablet.fire(src, query)
    local actor = exports.qbx_core:GetPlayer(src)
    if not actor or not W2FAmbulance.Core.hasPermission(actor, 'ManagePersonnel') then return false end

    local citizenid = resolveTargetQuery(src, query)
    if not citizenid then return false end

    local targetName = Identity.fullNameFromCitizenId(citizenid)
    local target = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if target then
        local targetGrade = W2FAmbulance.Core.getGrade(target)
        if targetGrade >= W2FAmbulance.Core.getGrade(actor) then
            notify(src, 'You cannot remove someone at or above your rank.', 'error')
            return false
        end
        target.Functions.SetJob('unemployed', 0)
    else
        exports.qbx_core:SetJob(citizenid, 'unemployed', 0)
    end

    local actorName = W2FAmbulance.Core.getCharFullName(actor)
    local actorCid = actor.PlayerData.citizenid
    notify(src, ('Removed %s from EMS'):format(targetName), 'success')
    Logging.write('personnel', 'fire', actorCid, actorName, citizenid, targetName,
        ('Removed %s from EMS'):format(targetName), {})
    return true
end

function Tablet.setGrade(src, citizenid, grade)
    local actor = exports.qbx_core:GetPlayer(src)
    if not actor or not W2FAmbulance.Core.hasPermission(actor, 'ManagePersonnel') then return false end
    if type(citizenid) ~= 'string' or citizenid == '' then return false end

    grade = math.max(0, math.min(tonumber(grade) or 0, maxAssignable(W2FAmbulance.Core.getGrade(actor))))
    local targetName = Identity.fullNameFromCitizenId(citizenid)
    local target = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if target then
        target.Functions.SetJob(Config.JobName, grade)
    else
        exports.qbx_core:SetJob(citizenid, Config.JobName, grade)
    end

    local actorName = W2FAmbulance.Core.getCharFullName(actor)
    local actorCid = actor.PlayerData.citizenid
    local rankLabel = W2FAmbulance.Ranks.GetLabel(grade)
    notify(src, ('Updated %s to %s'):format(targetName, rankLabel), 'success')
    Logging.write('personnel', 'grade_change', actorCid, actorName, citizenid, targetName,
        ('Updated %s to %s'):format(targetName, rankLabel),
        { grade = grade, rankLabel = rankLabel })
    return true
end

function Tablet.postAnnouncement(src, message)
    local actor = exports.qbx_core:GetPlayer(src)
    if not actor or not isHighCommand(actor) then return false end
    if type(message) ~= 'string' or message == '' then return false end

    local author = W2FAmbulance.Core.getCharFullName(actor)
    local actorCid = actor.PlayerData.citizenid

    MySQL.insert.await(
        'INSERT INTO w2f_ambulance_announcements (author, message) VALUES (?, ?)',
        { author, message }
    )

    MySQL.query.await([[
        DELETE FROM w2f_ambulance_announcements
        WHERE id NOT IN (
            SELECT id FROM (
                SELECT id FROM w2f_ambulance_announcements
                ORDER BY created_at DESC
                LIMIT 50
            ) recent
        )
    ]])

    local players = exports.qbx_core:GetQBPlayers()
    for _, player in pairs(players) do
        if player.PlayerData.job.name == Config.JobName then
            exports.qbx_core:Notify(player.PlayerData.source, ('EMS Announcement: %s'):format(message), 'inform')
        end
    end

    Logging.write('announcement', 'post', actorCid, author, '', '',
        ('Bulletin: %s'):format(message:sub(1, 120)), {})
    return true
end

function Tablet.searchCitizens(src, query)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not isHighCommand(player) then return {} end
    return Identity.searchCitizens(query, 100)
end

function Tablet.getPatientFile(src, citizenid)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not isHighCommand(player) then return nil end
    if type(citizenid) ~= 'string' or citizenid == '' then return nil end

    local profile = Identity.getCitizenProfile(citizenid)
    if not profile then return nil end

    return {
        profile = profile,
        clinical = W2FAmbulance.Records.fetchByCitizen(citizenid, 50),
        public = W2FAmbulance.PublicRecords.fetchByCitizen(citizenid, 50),
    }
end

function Tablet.addClinicalNote(src, citizenid, notes)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not isHighCommand(player) then return false end
    if type(citizenid) ~= 'string' or citizenid == '' then return false end
    if type(notes) ~= 'string' or notes:match('^%s*$') then return false end

    local profile = Identity.getCitizenProfile(citizenid)
    if not profile then
        notify(src, 'No citizen found.', 'error')
        return false
    end

    local author = W2FAmbulance.Core.getCharFullName(player)
    local actorCid = player.PlayerData.citizenid
    local row = W2FAmbulance.Records.create(citizenid, author, notes)
    if row then
        notify(src, ('Clinical note added for %s.'):format(profile.name), 'success')
        Logging.write('patient', 'clinical_note', actorCid, author, citizenid, profile.name,
            ('Clinical note added for %s'):format(profile.name), {})
    end
    return row ~= nil
end

function Tablet.searchRecords(src, query)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not isHighCommand(player) then return { rows = {} } end
    if type(query) ~= 'string' or query == '' then return { rows = {} } end

    local rows, patientName, citizenid = W2FAmbulance.Records.fetchByQuery(query, 50)
    return {
        rows = rows,
        patientName = patientName,
        citizenid = citizenid,
    }
end

function Tablet.searchPublicRecords(src, query)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not isHighCommand(player) then return { rows = {} } end
    if type(query) ~= 'string' or query == '' then return { rows = {} } end

    local rows, patientName, citizenid = W2FAmbulance.PublicRecords.fetchByQuery(query, 50)
    return {
        rows = rows,
        patientName = patientName,
        citizenid = citizenid,
    }
end

function Tablet.publishPublicRecord(src, payload)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not isHighCommand(player) then return false end
    if type(payload) ~= 'table' then return false end

    local citizenid = payload.citizenid
    if not citizenid or citizenid == '' then
        citizenid = resolveTargetQuery(src, payload.query)
    end
    if not citizenid then return false end

    local patient = Identity.getPatientPlayer(citizenid)
    if not patient then
        notify(src, 'No citizen found.', 'error')
        return false
    end

    local summary = payload.summary
    if type(summary) ~= 'string' or summary == '' then return false end

    local actorName = W2FAmbulance.Core.getCharFullName(player)
    local actorCid = player.PlayerData.citizenid
    local targetName = Identity.fullNameFromCitizenId(citizenid)
    local visitType = payload.visitType or 'manual'

    local ok = W2FAmbulance.PublicRecords.create(patient, player, visitType, summary) ~= nil
    if ok then
        notify(src, ('Published visit for %s.'):format(targetName), 'success')
        Logging.write('patient', 'public_record', actorCid, actorName, citizenid, targetName,
            ('Published %s visit for %s'):format(visitType, targetName),
            { visitType = visitType, summary = summary:sub(1, 80) })
    end
    return ok
end

function Tablet.getLogs(src, filters)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not isHighCommand(player) then return { rows = {} } end
    filters = type(filters) == 'table' and filters or {}
    local rows = Logging.query(filters)
    return { rows = rows }
end

-- Tablet close audit log via net event from client
RegisterNetEvent('w2f-ambulance:server:tabletClosed', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local actorName = W2FAmbulance.Core.getCharFullName(player)
    local actorCid = player.PlayerData.citizenid
    Logging.write('access', 'tablet_close', actorCid, actorName, '', '', ('Tablet closed by %s'):format(actorName))
end)

-- ==================== Callbacks ====================

lib.callback.register(W2FAmbulance.Constants.Callbacks.GetTabletDashboard, function(source)
    return Tablet.getDashboard(source)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.TabletHire, function(source, payload)
    return Tablet.hire(source, payload and (payload.query or payload.citizenid), payload and payload.grade)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.TabletFire, function(source, payload)
    return Tablet.fire(source, payload and (payload.query or payload.citizenid))
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.TabletSetGrade, function(source, payload)
    return Tablet.setGrade(source, payload and payload.citizenid, payload and payload.grade)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.TabletPostAnnouncement, function(source, payload)
    return Tablet.postAnnouncement(source, payload and payload.message)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.SearchCitizens, function(source, query)
    local q = query
    if type(query) == 'table' then
        q = query.query
    end
    return Tablet.searchCitizens(source, q)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.GetPatientFile, function(source, citizenid)
    return Tablet.getPatientFile(source, citizenid)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.AddClinicalNote, function(source, payload)
    return Tablet.addClinicalNote(source, payload and payload.citizenid, payload and payload.notes)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.SearchRecords, function(source, query)
    return Tablet.searchRecords(source, query)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.SearchPublicRecords, function(source, query)
    return Tablet.searchPublicRecords(source, query)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.PublishPublicRecord, function(source, payload)
    return Tablet.publishPublicRecord(source, payload)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.GetMyPublicRecords, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end
    return W2FAmbulance.PublicRecords.fetchByCitizen(player.PlayerData.citizenid, 50)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.GetAuditLogs, function(source, filters)
    return Tablet.getLogs(source, filters)
end)
