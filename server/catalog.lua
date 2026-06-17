W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Catalog = W2FAmbulance.Catalog or {}

local Catalog = W2FAmbulance.Catalog

local function itemImage(itemName)
    local template = Config.ItemImagePath or 'nui://ox_inventory/web/images/%s.png'
    local imageName = itemName
    local ok, oxItem = pcall(function() return exports.ox_inventory:Items(itemName) end)
    if ok and oxItem then
        if oxItem.client and oxItem.client.image then
            imageName = oxItem.client.image
        elseif oxItem.image then
            imageName = oxItem.image
        end
    end
    if template:find('%%s') then
        return template:format(imageName)
    end
    return template .. imageName
end

function Catalog.buildArmory(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not W2FAmbulance.Core.isEmsOnDuty(player) then return nil end
    if not W2FAmbulance.Core.hasPermission(player, 'UseArmory') then return nil end

    local grade = W2FAmbulance.Core.getGrade(player)
    local items = {}

    for _, entry in ipairs(W2FAmbulance.Equipment.GetArmoryCatalog()) do
        local minRank = entry.minRank or 0
        local authorized = grade >= minRank
        items[#items + 1] = {
            id = entry.id or entry.name,
            label = entry.label or entry.name,
            item = entry.name,
            category = entry.category or 'supplies',
            amount = entry.amount or 1,
            minRank = minRank,
            authorized = authorized,
            rankRequired = W2FAmbulance.Equipment.RankLabel(minRank),
            image = itemImage(entry.name),
        }
    end

    return {
        title = 'Medical Supply Locker',
        subtitle = 'Pillbox Hospital · Armory',
        grade = grade,
        rankLabel = W2FAmbulance.Ranks.GetLabel(grade),
        rankShort = W2FAmbulance.Ranks.GetShort(grade),
        categories = Config.EquipmentCategories or {},
        items = items,
    }
end

function Catalog.buildMedCabinet(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not W2FAmbulance.Core.isEmsOnDuty(player) then return nil end
    if not W2FAmbulance.Core.hasPermission(player, 'UseMedCabinet') then return nil end

    local grade = W2FAmbulance.Core.getGrade(player)
    local items = {}

    for _, entry in ipairs(W2FAmbulance.Equipment.GetMedCabinetCatalog()) do
        items[#items + 1] = {
            id = entry.id or entry.name,
            label = entry.label or entry.name,
            item = entry.name,
            category = entry.category or 'prescriptions',
            amount = entry.amount or 1,
            minRank = entry.minRank or 0,
            authorized = true,
            rankRequired = W2FAmbulance.Ranks.GetLabel(W2FAmbulance.Permissions.GetMinRank('UseMedCabinet')),
            image = itemImage(entry.name),
        }
    end

    return {
        title = 'Med Cabinet',
        subtitle = 'Pillbox Hospital · Trusted personnel only',
        grade = grade,
        rankLabel = W2FAmbulance.Ranks.GetLabel(grade),
        rankShort = W2FAmbulance.Ranks.GetShort(grade),
        categories = Config.MedCabinetCategories or {},
        items = items,
    }
end

function Catalog.buildGarage(src, kind)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not W2FAmbulance.Core.isEmsOnDuty(player) then return nil end

    local perm = kind == 'air' and 'UseAirGarage' or 'UseGarage'
    if not W2FAmbulance.Core.hasPermission(player, perm) then return nil end

    local grade = W2FAmbulance.Core.getGrade(player)
    local vehicles = {}

    for _, entry in ipairs(W2FAmbulance.Equipment.GetGarageCatalog(kind)) do
        local minRank = entry.minRank or 0
        local authorized = grade >= minRank
        vehicles[#vehicles + 1] = {
            id = entry.id or entry.model,
            model = entry.model,
            label = entry.label,
            minRank = minRank,
            authorized = authorized,
            rankRequired = W2FAmbulance.Equipment.RankLabel(minRank),
        }
    end

    return {
        title = kind == 'air' and 'Air Medical Hangar' or 'EMS Motor Pool',
        subtitle = kind == 'air' and 'Flight operations' or 'Ground response fleet',
        kind = kind,
        grade = grade,
        rankLabel = W2FAmbulance.Ranks.GetLabel(grade),
        vehicles = vehicles,
    }
end

function Catalog.takeArmoryItem(src, itemId)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not W2FAmbulance.Core.isEmsOnDuty(player) then return false, 'forbidden' end
    if not W2FAmbulance.Core.hasPermission(player, 'UseArmory') then return false, 'forbidden' end

    local entry
    for _, row in ipairs(W2FAmbulance.Equipment.GetArmoryCatalog()) do
        if row.id == itemId or row.name == itemId then
            entry = row
            break
        end
    end
    if not entry then return false, 'missing' end

    local grade = W2FAmbulance.Core.getGrade(player)
    if grade < (entry.minRank or 0) then return false, 'rank' end

    if entry.name == (Config.Systems and Config.Systems.CommandTablet and Config.Systems.CommandTablet.OpenItem) then
        if not W2FAmbulance.Permissions.IsHighCommand(grade) then return false, 'rank' end
    end

    if entry.commandOnly and not W2FAmbulance.Ranks.IsCommand(grade) then
        return false, 'rank'
    end

    local ok = exports.ox_inventory:AddItem(src, entry.name, entry.amount or 1)
    if not ok then return false, 'inventory' end
    return true
end

function Catalog.takeMedCabinetItem(src, itemId)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not W2FAmbulance.Core.isEmsOnDuty(player) then return false, 'forbidden' end
    if not W2FAmbulance.Core.hasPermission(player, 'UseMedCabinet') then return false, 'rank' end

    local entry = W2FAmbulance.Equipment.GetMedCabinetEntry(itemId)
    if not entry then return false, 'missing' end

    local metadata
    if W2FAmbulance.Core.isPrescriptionPadItem(entry.name) then
        metadata = W2FAmbulance.Core.prescriptionPadMetadata(player)
    end

    local ok = exports.ox_inventory:AddItem(src, entry.name, entry.amount or 1, metadata)
    if not ok then return false, 'inventory' end
    return true
end

lib.callback.register(W2FAmbulance.Constants.Callbacks.GetArmoryCatalog, function(source)
    return Catalog.buildArmory(source)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.GetMedCabinetCatalog, function(source)
    return Catalog.buildMedCabinet(source)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.GetGarageCatalog, function(source, kind)
    return Catalog.buildGarage(source, kind)
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.TakeArmoryItem, function(source, itemId)
    local ok, reason = Catalog.takeArmoryItem(source, itemId)
    return { ok = ok, reason = reason }
end)

lib.callback.register(W2FAmbulance.Constants.Callbacks.TakeMedCabinetItem, function(source, itemId)
    local ok, reason = Catalog.takeMedCabinetItem(source, itemId)
    return { ok = ok, reason = reason }
end)
