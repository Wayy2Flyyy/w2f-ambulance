RegisterNetEvent('w2f-ambulance:server:bill', function(target, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount < Config.Billing.minimum or amount > Config.Billing.maximum then return end
end)
