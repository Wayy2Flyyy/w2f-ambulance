W2F.Shared.Injuries = {}
function W2F.Shared.Injuries.severityFromHealth(health)
    if health <= 0 then return 'critical' end
    if health < 50 then return 'major' end
    if health < 80 then return 'minor' end
    return 'none'
end
