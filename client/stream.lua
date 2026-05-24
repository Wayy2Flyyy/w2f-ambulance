--- Preload custom streamed props once archetypes register via DLC_ITYP_REQUEST.
W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance

local Placeables = W2FAmbulance.Placeables

local function preloadCustomProp(modelName, timeoutMs)
    if type(modelName) ~= 'string' or modelName == '' then return false end

    local hash = joaat(modelName)
    local deadline = GetGameTimer() + timeoutMs

    while not IsModelInCdimage(hash) and not IsModelValid(hash) and GetGameTimer() < deadline do
        Wait(200)
    end

    if not IsModelInCdimage(hash) and not IsModelValid(hash) then
        print(('[w2f-ambulance] custom prop failed to register: %s'):format(modelName))
        return false
    end

    if lib and lib.requestModel then
        local ok = pcall(lib.requestModel, hash, timeoutMs)
        return ok and HasModelLoaded(hash)
    end

    RequestModel(hash)
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(0)
    end

    return HasModelLoaded(hash)
end

CreateThread(function()
    if not Placeables or not Placeables.IsEnabled() then return end

    Wait(1500)

    for itemName, cfg in pairs(Config.Placeables.Items or {}) do
        if cfg.isCustomProp and cfg.prop then
            local model = Placeables.ResolvePropModel(cfg.prop, itemName) or cfg.prop
            preloadCustomProp(model, 30000)
        end
    end
end)
