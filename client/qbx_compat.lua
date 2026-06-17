--[[
    Legacy client hooks so other resources keep working with w2f-ambulance.
]]

--- Embedded medical core — same event names as qbx_medical for compat.
RegisterNetEvent('hospital:client:HealInjuries', function(type)
    if GetInvokingResource() then return end
    TriggerEvent('qbx_medical:client:heal', type == 'full' and 'full' or 'partial')
end)
