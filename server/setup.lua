W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Setup = W2FAmbulance.Setup or {}

local Setup = W2FAmbulance.Setup
local sharedConfig = require 'config.shared'

function Setup.registerInventory()
    if GetResourceState('ox_inventory') ~= 'started' then return false end

    for _, stash in pairs(sharedConfig.locations.stash) do
        exports.ox_inventory:RegisterStash(
            stash.name,
            stash.label,
            stash.slots,
            stash.weight,
            stash.owner,
            stash.groups,
            stash.location
        )
    end

    return true
end

function Setup.runDeferred()
    CreateThread(function()
        for _ = 1, 40 do
            if Setup.registerInventory() then
                print('[w2f-ambulance] Personal stash registered (armory uses custom NUI)')
                return
            end
            Wait(500)
        end
        print('[w2f-ambulance] WARN: Could not register stash — is ox_inventory running?')
    end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() or resourceName == 'ox_inventory' then
        Setup.runDeferred()
    end
end)
