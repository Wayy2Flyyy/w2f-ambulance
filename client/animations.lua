W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Animations = W2FAmbulance.Animations or {}

local Animations = W2FAmbulance.Animations
local tabletActive = false
local tabletProp = nil

local TABLET_DICT = 'amb@code_human_in_bus_passenger_idles@female@tablet@base'
local TABLET_ANIM = 'base'
local TABLET_PROP = 'prop_cs_tablet'
local TABLET_BONE = 28422

local function requestAnim(dict)
    if not DoesAnimDictExist(dict) then return false end
    lib.requestAnimDict(dict, 5000)
    return HasAnimDictLoaded(dict)
end

local function clearTabletProp()
    if tabletProp and DoesEntityExist(tabletProp) then
        DeleteEntity(tabletProp)
    end
    tabletProp = nil
end

local function attachTabletProp()
    clearTabletProp()
    local model = joaat(TABLET_PROP)
    lib.requestModel(model, 5000)
    if not HasModelLoaded(model) then return end

    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    tabletProp = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false)
    AttachEntityToEntity(
        tabletProp,
        ped,
        GetPedBoneIndex(ped, TABLET_BONE),
        0.0, 0.0, 0.03,
        0.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(model)
end

function Animations.StartTablet()
    if tabletActive then return end
    tabletActive = true

    if requestAnim(TABLET_DICT) then
        TaskPlayAnim(cache.ped, TABLET_DICT, TABLET_ANIM, 4.0, -4.0, -1, 49, 0.0, false, false, false)
    end
    attachTabletProp()

    CreateThread(function()
        while tabletActive do
            if not IsEntityPlayingAnim(cache.ped, TABLET_DICT, TABLET_ANIM, 3) then
                if requestAnim(TABLET_DICT) then
                    TaskPlayAnim(cache.ped, TABLET_DICT, TABLET_ANIM, 4.0, -4.0, -1, 49, 0.0, false, false, false)
                end
            end
            Wait(500)
        end
    end)
end

function Animations.StopTablet()
    if not tabletActive then return end
    tabletActive = false
    clearTabletProp()
    StopAnimTask(cache.ped, TABLET_DICT, TABLET_ANIM, 1.0)
end

function Animations.IsTabletActive()
    return tabletActive
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Animations.StopTablet()
end)
