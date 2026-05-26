W2FAmbulance = _G.W2FAmbulance or {}
local Framework = W2FAmbulance.Framework or {}

local QBCore
local ESX

local function qb()
    if QBCore then return QBCore end
    local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok then QBCore = core end
    return QBCore
end

local function esx()
    if ESX then return ESX end
    local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    if ok then ESX = obj end
    return ESX
end

function Framework.GetPlayer(src)
    if Framework.IsQbox() then return exports.qbx_core:GetPlayer(src) end
    if Framework.IsQBCore() then local c = qb(); return c and c.Functions.GetPlayer(src) or nil end
    if Framework.IsESX() then local x = esx(); return x and x.GetPlayerFromId(src) or nil end
end

function Framework.Notify(src, message, ntype)
    if Framework.IsQbox() then return exports.qbx_core:Notify(src, message, ntype or 'inform') end
    TriggerClientEvent('ox_lib:notify', src, { description = message, type = ntype or 'inform' })
end

function Framework.GetIdentifier(src)
    local p = Framework.GetPlayer(src)
    if not p then return nil end
    if Framework.IsESX() then return p.identifier end
    return p.PlayerData and (p.PlayerData.citizenid or p.PlayerData.license)
end

function Framework.GetJob(src)
    local p = Framework.GetPlayer(src)
    if not p then return nil end
    if Framework.IsESX() then
        local j = p.job or {}
        return { name=j.name, label=j.label, grade={ level=tonumber(j.grade) or 0, name=j.grade_label }, onduty=true, type=(j.name=='ambulance' and 'ems' or j.name) }
    end
    return p.PlayerData and p.PlayerData.job or nil
end

W2FAmbulance.Framework = Framework
