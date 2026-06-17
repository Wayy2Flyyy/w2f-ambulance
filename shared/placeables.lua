W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Placeables = W2FAmbulance.Placeables or {}

local Placeables = W2FAmbulance.Placeables

function Placeables.IsEnabled()
    return Config and Config.Placeables and Config.Placeables.Enabled == true
end

function Placeables.IsPlaceableItem(itemName)
    if type(itemName) ~= 'string' then return false end
    return Config.Placeables and Config.Placeables.Items and Config.Placeables.Items[itemName] ~= nil
end

function Placeables.GetConfig(itemName)
    if not Placeables.IsPlaceableItem(itemName) then return nil end
    return Config.Placeables.Items[itemName]
end

function Placeables.IsCustomProp(itemName)
    local cfg = Placeables.GetConfig(itemName)
    return cfg ~= nil and cfg.isCustomProp == true
end

local PROP_ALIASES = {
    freddy = 'dummy',
}

function Placeables.ResolvePropModel(model, itemName)
    if type(model) ~= 'string' then return model end
    if itemName and Placeables.IsCustomProp(itemName) then
        return PROP_ALIASES[model] or model
    end
    return PROP_ALIASES[model] or model
end

function Placeables.IsValidModel(model)
    if not Config.Placeables or not Config.Placeables.Items then return false end
    if type(model) == 'number' then
        for _, def in pairs(Config.Placeables.Items) do
            if def.prop and joaat(def.prop) == model then return true end
            local alias = PROP_ALIASES[def.prop]
            if alias and joaat(alias) == model then return true end
        end
        for alias, canonical in pairs(PROP_ALIASES) do
            if joaat(alias) == model then
                for _, def in pairs(Config.Placeables.Items) do
                    if def.prop == canonical then return true end
                end
            end
        end
        return false
    end
    if type(model) ~= 'string' then return false end
    local resolved = Placeables.ResolvePropModel(model)
    for _, def in pairs(Config.Placeables.Items) do
        if def.prop == model or def.prop == resolved then return true end
    end
    return false
end

function Placeables.GetPlacement(itemName)
    local cfg = Placeables.GetConfig(itemName)
    local defaults = Config.Placeables.Placement or {}
    local placement = (cfg and cfg.placement) or {}
    return {
        distance = placement.distance or defaults.DefaultDistance or 2.5,
        heightOffset = placement.heightOffset or defaults.DefaultHeightOffset or 0.0,
        rotationSpeed = placement.rotationSpeed or defaults.DefaultRotationSpeed or 2.5,
        maxDistanceFromPlayer = placement.maxDistanceFromPlayer or defaults.DefaultMaxDistanceFromPlayer or 5.0,
    }
end

function Placeables.ClampHeading(heading)
    if type(heading) ~= 'number' then return 0.0 end
    heading = heading % 360.0
    if heading < 0 then heading = heading + 360.0 end
    return heading
end

function Placeables.GenerateObjectId()
    return ('ems_plc_%s_%s'):format(os.time(), math.random(100000, 999999))
end

function Placeables.DistanceSqr(a, b)
    if not a or not b then return math.huge end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    local dz = (a.z or 0) - (b.z or 0)
    return dx * dx + dy * dy + dz * dz
end
