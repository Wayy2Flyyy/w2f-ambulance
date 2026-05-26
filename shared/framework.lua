W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance

W2FAmbulance.Framework = W2FAmbulance.Framework or {}
local Framework = W2FAmbulance.Framework

Config = Config or {}
Config.Framework = Config.Framework or 'auto'

local detected

function Framework.Detect()
    if detected then return detected end
    local cfg = (Config.Framework or 'auto'):lower()
    if cfg ~= 'auto' then
        detected = cfg
        return detected
    end

    if GetResourceState('qbx_core') == 'started' then detected = 'qbox'
    elseif GetResourceState('qb-core') == 'started' then detected = 'qbcore'
    elseif GetResourceState('es_extended') == 'started' then detected = 'esx'
    else
        detected = 'unknown'
        print('[w2f-ambulance] ERROR: No supported framework detected (qbx_core / qb-core / es_extended).')
    end

    return detected
end

function Framework.GetName() return Framework.Detect() end
function Framework.IsQbox() return Framework.Detect() == 'qbox' end
function Framework.IsQBCore() return Framework.Detect() == 'qbcore' end
function Framework.IsESX() return Framework.Detect() == 'esx' end
function Framework.IsQBFamily() local n = Framework.Detect(); return n == 'qbox' or n == 'qbcore' end
