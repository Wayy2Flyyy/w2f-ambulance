W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.DB = W2FAmbulance.DB or {}

local DB = W2FAmbulance.DB

function DB.ensureSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS w2f_ambulance_records (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(64) NOT NULL,
            author VARCHAR(64) NOT NULL,
            notes TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_citizenid (citizenid)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS w2f_ems_public_records (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(64) NOT NULL,
            patient_name VARCHAR(128) NOT NULL,
            visit_type VARCHAR(64) NOT NULL,
            summary TEXT NOT NULL,
            provider_name VARCHAR(128) NOT NULL,
            provider_cid VARCHAR(64) NOT NULL,
            facility VARCHAR(128) NOT NULL DEFAULT 'Pillbox Hospital',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_public_citizenid (citizenid),
            INDEX idx_public_created (created_at)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS w2f_ambulance_placeables (
            object_id VARCHAR(64) NOT NULL PRIMARY KEY,
            citizenid VARCHAR(64) NOT NULL,
            item VARCHAR(64) NOT NULL,
            model VARCHAR(64) NOT NULL,
            label VARCHAR(128) NOT NULL,
            x DOUBLE NOT NULL,
            y DOUBLE NOT NULL,
            z DOUBLE NOT NULL,
            heading DOUBLE NOT NULL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_placeables_citizenid (citizenid)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS w2f_ambulance_announcements (
            id INT AUTO_INCREMENT PRIMARY KEY,
            author VARCHAR(128) NOT NULL,
            message TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_announcement_created (created_at)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS w2f_ambulance_audit_logs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            log_type VARCHAR(32) NOT NULL DEFAULT 'system',
            action VARCHAR(64) NOT NULL DEFAULT 'unknown',
            actor_cid VARCHAR(64) NOT NULL DEFAULT '',
            actor_name VARCHAR(128) NOT NULL DEFAULT '',
            target_cid VARCHAR(64) NOT NULL DEFAULT '',
            target_name VARCHAR(128) NOT NULL DEFAULT '',
            message TEXT NOT NULL DEFAULT '',
            metadata_json TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_audit_log_type (log_type),
            INDEX idx_audit_action (action),
            INDEX idx_audit_actor (actor_cid),
            INDEX idx_audit_target (target_cid),
            INDEX idx_audit_created (created_at)
        )
    ]])
end

function DB.ping()
    return MySQL.scalar.await('SELECT 1') == 1
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CreateThread(function()
        for _ = 1, 20 do
            if GetResourceState('oxmysql') == 'started' then break end
            Wait(500)
        end

        local ok, err = pcall(DB.ensureSchema)
        if ok then
            print('[w2f-ambulance] Database schema ready')
        else
            print(('[w2f-ambulance] Database schema failed: %s'):format(tostring(err)))
        end
    end)
end)
