--- EMS prescription tools (ox_target + command fallback).

local function resolveTargetServerId(entity)
    if not entity or entity == 0 then return nil end
    if IsPedAPlayer(entity) then
        local idx = NetworkGetPlayerIndexFromPed(entity)
        if idx and idx ~= -1 then
            return GetPlayerServerId(idx)
        end
    end
    return nil
end

CreateThread(function()
    local deadline = GetGameTimer() + 30000
    while GetResourceState('ox_target') ~= 'started' and GetGameTimer() < deadline do
        Wait(200)
    end
    if GetResourceState('ox_target') ~= 'started' then return end

    exports.ox_target:addGlobalPlayer({
        {
            name = 'w2f_ambulance_issue_prescription',
            icon = 'fa-solid fa-file-prescription',
            label = 'Issue prescription',
            distance = 2.5,
            canInteract = function(entity)
                return W2FAmbulance.Client.isEmsOnDuty()
                    and W2FAmbulance.Client.hasPermission('IssuePrescription')
                    and W2FAmbulance.Client.hasPrescriptionPad()
                    and entity ~= cache.ped
            end,
            onSelect = function(data)
                local targetId = resolveTargetServerId(data.entity)
                if not targetId then return end
                TriggerServerEvent('w2f-ambulance:server:issuePrescription', targetId)
            end,
        },
    })
end)

RegisterNetEvent('w2f-ambulance:client:issuePrescriptionNearest', function()
    if not W2FAmbulance.Client.isEmsOnDuty() then
        exports.qbx_core:Notify('You must be on-duty EMS to issue prescriptions.', 'error')
        return
    end
    if not W2FAmbulance.Client.hasPermission('IssuePrescription') then
        W2FAmbulance.Client.notifyRankDenied('IssuePrescription')
        return
    end
    if not W2FAmbulance.Client.hasPrescriptionPad() then
        exports.qbx_core:Notify(locale('error.no_prescription_pad'), 'error')
        return
    end

    local player = GetClosestPlayer()
    if not player then
        exports.qbx_core:Notify(locale('error.no_player'), 'error')
        return
    end

    TriggerServerEvent('w2f-ambulance:server:issuePrescription', GetPlayerServerId(player))
end)
