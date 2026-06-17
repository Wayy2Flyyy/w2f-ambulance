W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance

W2FAmbulance.Ranks = W2FAmbulance.Ranks or {}

function W2FAmbulance.Ranks.Get(grade)
    local ranks = Config.Ranks
    if not ranks then return nil end
    return ranks[grade]
end

function W2FAmbulance.Ranks.GetMax()
    local ranks = Config.Ranks or {}
    local maxGrade = 0
    for grade in pairs(ranks) do
        if type(grade) == 'number' and grade > maxGrade then
            maxGrade = grade
        end
    end
    return maxGrade
end

function W2FAmbulance.Ranks.GetLabel(grade)
    local info = W2FAmbulance.Ranks.Get(grade)
    return info and info.label or 'Unranked'
end

function W2FAmbulance.Ranks.GetShort(grade)
    local info = W2FAmbulance.Ranks.Get(grade)
    return info and info.shortName or '?'
end

function W2FAmbulance.Ranks.IsSupervisor(grade)
    local info = W2FAmbulance.Ranks.Get(grade)
    return info and info.supervisor or false
end

function W2FAmbulance.Ranks.IsCommand(grade)
    local info = W2FAmbulance.Ranks.Get(grade)
    return info and info.command or false
end

function W2FAmbulance.Ranks.IsHighCommand(grade)
    local info = W2FAmbulance.Ranks.Get(grade)
    return info and info.highCommand or false
end

function W2FAmbulance.Ranks.List()
    local out = {}
    for grade, info in pairs(Config.Ranks or {}) do
        if type(grade) == 'number' then
            out[#out + 1] = {
                grade = grade,
                label = info.label,
                shortName = info.shortName,
                payGrade = info.payGrade,
                supervisor = info.supervisor,
                command = info.command,
                highCommand = info.highCommand,
            }
        end
    end
    table.sort(out, function(a, b) return a.grade < b.grade end)
    return out
end

W2FAmbulance.Permissions = W2FAmbulance.Permissions or {}

function W2FAmbulance.Permissions.GetMinRank(permission)
    local perms = Config.RankPermissions or {}
    if perms[permission] == nil then return 99 end
    return perms[permission]
end

function W2FAmbulance.Permissions.Has(grade, permission)
    if grade == nil or permission == nil then return false end
    return grade >= W2FAmbulance.Permissions.GetMinRank(permission)
end

function W2FAmbulance.Permissions.CanUseArmory(grade)
    return W2FAmbulance.Permissions.Has(grade, 'UseArmory')
end

function W2FAmbulance.Permissions.CanUseMedCabinet(grade)
    return W2FAmbulance.Permissions.Has(grade, 'UseMedCabinet')
end

function W2FAmbulance.Permissions.CanUseGarage(grade)
    return W2FAmbulance.Permissions.Has(grade, 'UseGarage')
end

function W2FAmbulance.Permissions.CanUseAirGarage(grade)
    return W2FAmbulance.Permissions.Has(grade, 'UseAirGarage')
end

function W2FAmbulance.Permissions.CanRevive(grade)
    return W2FAmbulance.Permissions.Has(grade, 'RevivePatient')
end

function W2FAmbulance.Permissions.CanTreat(grade)
    return W2FAmbulance.Permissions.Has(grade, 'TreatWounds')
end

function W2FAmbulance.Permissions.CanCheckStatus(grade)
    return W2FAmbulance.Permissions.Has(grade, 'CheckPatientStatus')
end

function W2FAmbulance.Permissions.CanIssuePrescription(grade)
    return W2FAmbulance.Permissions.Has(grade, 'IssuePrescription')
end

function W2FAmbulance.Permissions.CanPutInBed(grade)
    return W2FAmbulance.Permissions.Has(grade, 'PutPatientInBed')
end

function W2FAmbulance.Permissions.IsHighCommand(grade)
    return W2FAmbulance.Permissions.Has(grade, 'HighCommandAccess')
end

W2FAmbulance.Equipment = W2FAmbulance.Equipment or {}

function W2FAmbulance.Equipment.GetArmoryCatalog()
    return Config.Equipment and Config.Equipment.armory or {}
end

function W2FAmbulance.Equipment.GetMedCabinetCatalog()
    return Config.Equipment and Config.Equipment.medCabinet or {}
end

function W2FAmbulance.Equipment.GetGarageCatalog(kind)
    local equipment = Config.Equipment or {}
    if kind == 'air' then return equipment.air or {} end
    return equipment.garage or {}
end

function W2FAmbulance.Equipment.GetArmoryEntry(itemId)
    for _, entry in ipairs(W2FAmbulance.Equipment.GetArmoryCatalog()) do
        if entry.id == itemId or entry.name == itemId then return entry end
    end
end

function W2FAmbulance.Equipment.GetMedCabinetEntry(itemId)
    for _, entry in ipairs(W2FAmbulance.Equipment.GetMedCabinetCatalog()) do
        if entry.id == itemId or entry.name == itemId then return entry end
    end
end

local function vehicleEntryId(entry)
    return entry.id or entry.model
end

function W2FAmbulance.Equipment.GetVehicleEntry(vehicleRef, kind)
    for _, entry in ipairs(W2FAmbulance.Equipment.GetGarageCatalog(kind)) do
        if vehicleEntryId(entry) == vehicleRef or entry.model == vehicleRef then
            return entry
        end
    end
end

function W2FAmbulance.Equipment.GetVehicleEntryById(vehicleRef)
    for _, kind in ipairs({ 'garage', 'air' }) do
        local entry = W2FAmbulance.Equipment.GetVehicleEntry(vehicleRef, kind)
        if entry then return entry, kind end
    end
end

function W2FAmbulance.Equipment.RankLabel(minRank)
    if not minRank or minRank <= 0 then return 'All ranks' end
    return W2FAmbulance.Ranks.GetLabel(minRank)
end

function W2FAmbulance.Equipment.CanTakeArmoryItem(grade, itemId)
    local entry = W2FAmbulance.Equipment.GetArmoryEntry(itemId)
    if not entry then return false end
    return grade >= (entry.minRank or 0)
end

function W2FAmbulance.Equipment.CanTakeMedCabinetItem(grade, itemId)
    if not W2FAmbulance.Permissions.CanUseMedCabinet(grade) then return false end
    local entry = W2FAmbulance.Equipment.GetMedCabinetEntry(itemId)
    if not entry then return false end
    return grade >= (entry.minRank or 0)
end

function W2FAmbulance.Equipment.CanTakeVehicle(grade, vehicleRef, kind)
    local entry = W2FAmbulance.Equipment.GetVehicleEntry(vehicleRef, kind)
    if not entry then return false end
    return grade >= (entry.minRank or 0)
end
