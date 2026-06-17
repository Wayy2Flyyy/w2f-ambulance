W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.TriageClient = W2FAmbulance.TriageClient or {}

local WEAPONS = exports.qbx_core:GetWeapons()

---@param status table
function W2FAmbulance.TriageClient.printStatusDetails(status)
    if not status then return end

    for hash in pairs(status.damageCauses or {}) do
        local weapon = WEAPONS[hash]
        TriggerEvent('chat:addMessage', {
            color = { 255, 0, 0 },
            multiline = false,
            args = { locale('info.status'), weapon and weapon.damagereason or locale('info.wep_unknown') }
        })
    end

    if status.bleedLevel and status.bleedLevel > 0 then
        TriggerEvent('chat:addMessage', {
            color = { 255, 0, 0 },
            multiline = false,
            args = { locale('info.status'), locale('info.is_status', status.bleedState) }
        })
    end

    for i = 1, #(status.injuries or {}) do
        TriggerEvent('chat:addMessage', {
            color = { 255, 120, 120 },
            multiline = false,
            args = { locale('info.status'), status.injuries[i] }
        })
    end
end

---@param patientSrc number
---@param attempted string
---@return boolean
function W2FAmbulance.TriageClient.validateCare(patientSrc, attempted)
    local result = lib.callback.await('w2f-ambulance:cb:validateCare', false, patientSrc, attempted)
    if not result or result.ok then return true end

    if result.err == 'assessment_required' then
        exports.qbx_core:Notify(locale('error.assessment_required'), 'error')
    elseif result.err == 'patient_now_stable' then
        exports.qbx_core:Notify(locale('error.patient_now_stable'), 'error')
    elseif result.err == 'wrong_treatment' then
        local hintKey = ('error.triage_wrong_%s'):format(attempted)
        local hint = locale(hintKey, result.neededLabel or '')
        if hint == hintKey then
            exports.qbx_core:Notify(locale('error.wrong_treatment', result.neededLabel or ''), 'error')
        else
            exports.qbx_core:Notify(hint, 'error')
        end
    end

    return false
end

---@param patientSrc number
function W2FAmbulance.TriageClient.showAssessment(patientSrc)
    local result = lib.callback.await('w2f-ambulance:cb:assessPatient', false, patientSrc)
    if not result or not result.ok then
        exports.qbx_core:Notify(locale('error.not_online'), 'error')
        return
    end

    W2FAmbulance.TriageClient.printStatusDetails(result.status)

    if result.causeLabel then
        TriggerEvent('chat:addMessage', {
            color = { 255, 165, 0 },
            multiline = false,
            args = { locale('info.status'), locale('info.injury_cause', result.causeLabel) }
        })
    end

    if result.treatment == 'none' then
        exports.qbx_core:Notify(locale('success.healthy_player'), 'success')
        return
    end

    exports.qbx_core:Notify(locale('info.triage_required', result.label), 'inform', 9000)
    TriggerEvent('chat:addMessage', {
        color = { 45, 212, 191 },
        multiline = false,
        args = { locale('info.status'), locale('info.triage_order', result.label) }
    })
end

RegisterNetEvent('w2f-ambulance:client:extendLaststand', function(seconds)
    if GetInvokingResource() then return end
    W2FAmbulance.Medical('IncrementLaststandTime', seconds or 45)
end)
