return {
    doctorCallCooldown = 1,
    wipeInvOnRespawn = true,
    depositSociety = function(society, amount)
        if GetResourceState('Renewed-Banking') ~= 'started' then return end
        pcall(function()
            exports['Renewed-Banking']:addAccountMoney(society, amount)
        end)
    end
}