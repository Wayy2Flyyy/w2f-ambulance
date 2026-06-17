W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.PublicRecordsClient = W2FAmbulance.PublicRecordsClient or {}

local function openKiosk()
    local rows = lib.callback.await(W2FAmbulance.Constants.Callbacks.GetMyPublicRecords, false)
    W2FAmbulance.UI.PublicRecords.Open({
        title = 'Public Medical Records',
        subtitle = Config.PublicRecords and Config.PublicRecords.facility or 'Pillbox Hospital',
        rows = rows or {},
        readOnly = true,
    })
end

CreateThread(function()
    local deadline = GetGameTimer() + 30000
    while GetResourceState('ox_target') ~= 'started' and GetGameTimer() < deadline do
        Wait(200)
    end
    if GetResourceState('ox_target') ~= 'started' then return end

    local kiosks = Config.PublicRecords and Config.PublicRecords.kiosks or {}
    for i = 1, #kiosks do
        local kiosk = kiosks[i]
        if kiosk.blip and kiosk.blip.enabled then
            local blip = AddBlipForCoord(kiosk.coords.x, kiosk.coords.y, kiosk.coords.z)
            SetBlipSprite(blip, kiosk.blip.sprite or 408)
            SetBlipColour(blip, kiosk.blip.colour or 2)
            SetBlipScale(blip, kiosk.blip.scale or 0.65)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(kiosk.blip.label or 'Public Medical Records')
            EndTextCommandSetBlipName(blip)
        end

        exports.ox_target:addBoxZone({
            name = 'ems_public_records_' .. i,
            coords = kiosk.coords,
            size = kiosk.size or vec3(1.2, 1.2, 2.0),
            rotation = kiosk.rotation or 0,
            options = {
                {
                    icon = 'fa-solid fa-notes-medical',
                    label = kiosk.label or 'Public Medical Records',
                    distance = 2.0,
                    onSelect = openKiosk,
                },
            },
        })
    end
end)
