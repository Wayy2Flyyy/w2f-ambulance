lib.callback.register('qbx_ambulancejob:server:getPlayerStatus', function(_, targetSrc)
	return exports[GetCurrentResourceName()]:GetPlayerStatus(targetSrc)
end)


local function alertAmbulance(src, text)
	local ped = GetPlayerPed(src)
	local coords = GetEntityCoords(ped)
	local players = exports.qbx_core:GetQBPlayers()
	for _, v in pairs(players) do
		if v.PlayerData.job.type == 'ems' and v.PlayerData.job.onduty then
			TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, text)
		end
	end
end

W2FAmbulance.AlertDutyEms = alertAmbulance

local STATUS_LABELS = {
	['10-8'] = 'In Service',
	['10-76'] = 'En Route',
	['10-23'] = 'On Scene',
	['Code 2'] = 'Transporting',
	['Code 3'] = 'At Hospital',
	['10-6'] = 'Busy',
	['10-7'] = 'Out of Service',
}

RegisterNetEvent('w2f-ambulance:server:statusBroadcast', function(code)
	if GetInvokingResource() then return end
	local src = source
	local player = exports.qbx_core:GetPlayer(src)
	if not player or not W2FAmbulance.Core.isEmsOnDuty(player) then return end

	local label = STATUS_LABELS[code] or code
	local grade = player.PlayerData.job.grade and player.PlayerData.job.grade.level or 0
	local callsign = W2FAmbulance.Ranks.GetShort(grade)
	local payload = {
		from = src,
		code = code,
		label = label,
		callsign = callsign,
	}

	local players = exports.qbx_core:GetQBPlayers()
	for _, v in pairs(players) do
		if v.PlayerData.job.type == 'ems' and v.PlayerData.job.onduty then
			TriggerClientEvent('w2f-ambulance:client:statusUpdate', v.PlayerData.source, payload)
		end
	end
end)

RegisterNetEvent('hospital:server:ambulanceAlert', function(text)
	if GetInvokingResource() then return end
	local src = source
	alertAmbulance(src, text or locale('info.civ_down'))
end)

RegisterNetEvent('hospital:server:emergencyAlert', function()
	if GetInvokingResource() then return end
	local src = source
	local player = exports.qbx_core:GetPlayer(src)
	if not player or not W2FAmbulance.Core.isEmsOnDuty(player) then return end
	if not W2FAmbulance.Core.hasPermission(player, 'EmergencyBroadcast') then
		exports.qbx_core:Notify(src, locale('error.rank_required', W2FAmbulance.Ranks.GetLabel(
			W2FAmbulance.Permissions.GetMinRank('EmergencyBroadcast')
		)), 'error')
		return
	end
	alertAmbulance(src, locale('info.ems_down', player.PlayerData.charinfo.lastname))
end)

RegisterNetEvent('qbx_medical:server:onPlayerLaststand', function()
	if GetInvokingResource() then return end
	local src = source
	alertAmbulance(src, locale('info.civ_down'))
end)

---@param playerId number
RegisterNetEvent('hospital:server:TreatWounds', function(playerId)
	if GetInvokingResource() then return end
	local src = source
	local player = exports.qbx_core:GetPlayer(src)
	local patient = exports.qbx_core:GetPlayer(playerId)
	if not player or not patient or player.PlayerData.job.type ~= 'ems' then return end
	if not W2FAmbulance.Core.hasPermission(player, 'TreatWounds') then
		exports.qbx_core:Notify(src, locale('error.rank_required', W2FAmbulance.Ranks.GetLabel(
			W2FAmbulance.Permissions.GetMinRank('TreatWounds')
		)), 'error')
		return
	end

	if not W2FAmbulance.Triage.notifyValidation(src, playerId, 'treat') then return end

	if not W2FAmbulance.Care.consumeItem(src, 'treat') then
		W2FAmbulance.Care.notifyMissingItem(src, 'bandage')
		return
	end

	exports[GetCurrentResourceName()]:HealPartially(patient.PlayerData.source)
	W2FAmbulance.Triage.clear(src, playerId)
	if W2FAmbulance.Records then
		W2FAmbulance.Records.create(
			patient.PlayerData.citizenid,
			W2FAmbulance.Core.getCharFullName(player),
			'EMS wound treatment'
		)
	end
	if W2FAmbulance.PublicRecords then
		W2FAmbulance.PublicRecords.logVisit(
			patient,
			player,
			'treatment',
			'Field wound treatment administered by EMS.'
		)
	end
	TriggerClientEvent('w2f-ambulance:client:patientTreatmentResult', src, { success = true, action = 'treat', patientId = playerId })
end)

---@param playerId number
RegisterNetEvent('hospital:server:StabilizePatient', function(playerId)
	if GetInvokingResource() then return end
	local src = source
	local player = exports.qbx_core:GetPlayer(src)
	local patient = exports.qbx_core:GetPlayer(playerId)
	if not player or not patient or player.PlayerData.job.type ~= 'ems' then return end
	if not W2FAmbulance.Core.hasPermission(player, 'TreatWounds') then
		exports.qbx_core:Notify(src, locale('error.rank_required', W2FAmbulance.Ranks.GetLabel(
			W2FAmbulance.Permissions.GetMinRank('TreatWounds')
		)), 'error')
		return
	end

	if not W2FAmbulance.Triage.notifyValidation(src, playerId, 'repair') then return end

	if not W2FAmbulance.Care.consumeItem(src, 'repair') then
		W2FAmbulance.Care.notifyMissingItem(src, 'ifaks')
		return
	end

	exports[GetCurrentResourceName()]:HealPartially(patient.PlayerData.source)
	W2FAmbulance.Triage.clear(src, playerId)
	if W2FAmbulance.Records then
		W2FAmbulance.Records.create(
			patient.PlayerData.citizenid,
			W2FAmbulance.Core.getCharFullName(player),
			'EMS trauma stabilization'
		)
	end
	if W2FAmbulance.PublicRecords then
		W2FAmbulance.PublicRecords.logVisit(
			patient,
			player,
			'treatment',
			'Field trauma stabilization administered by EMS.'
		)
	end
	TriggerClientEvent('w2f-ambulance:client:patientTreatmentResult', src, { success = true, action = 'repair', patientId = playerId })
end)

---@param playerId number
RegisterNetEvent('hospital:server:AssistPatient', function(playerId)
	if GetInvokingResource() then return end
	local src = source
	local player = exports.qbx_core:GetPlayer(src)
	local patient = exports.qbx_core:GetPlayer(playerId)
	if not player or not patient or player.PlayerData.job.type ~= 'ems' then return end
	if not W2FAmbulance.Core.hasPermission(player, 'TreatWounds') then
		exports.qbx_core:Notify(src, locale('error.rank_required', W2FAmbulance.Ranks.GetLabel(
			W2FAmbulance.Permissions.GetMinRank('TreatWounds')
		)), 'error')
		return
	end

	if not W2FAmbulance.Triage.notifyValidation(src, playerId, 'help') then return end

	TriggerClientEvent('w2f-ambulance:client:extendLaststand', patient.PlayerData.source, 45)
    W2FAmbulance.Triage.clear(src, playerId)
    if W2FAmbulance.Records then
        W2FAmbulance.Records.create(
            patient.PlayerData.citizenid,
            W2FAmbulance.Core.getCharFullName(player),
            'EMS field assist'
        )
    end
    if W2FAmbulance.PublicRecords then
        W2FAmbulance.PublicRecords.logVisit(
            patient,
            player,
            'treatment',
            'Field breathing assist provided by EMS.'
        )
    end
	TriggerClientEvent('w2f-ambulance:client:patientTreatmentResult', src, { success = true, action = 'assist', patientId = playerId })
end)

---@param playerId number
RegisterNetEvent('hospital:server:RevivePlayer', function(playerId)
	if GetInvokingResource() then return end
	local src = source
	local player = exports.qbx_core:GetPlayer(src)
	local patient = exports.qbx_core:GetPlayer(playerId)
	if not patient then return end

    if not player or player.PlayerData.job.type ~= 'ems' then
        if player then
            lib.logger(src, 'RevivePlayer', ('"%s" triggered event for "%s" bus was missing the required job'):format(player.PlayerData.citizenid, patient.PlayerData.citizenid or ''))
        end
        return
    end

	if not W2FAmbulance.Core.hasPermission(player, 'RevivePatient') then
		exports.qbx_core:Notify(src, locale('error.rank_required', W2FAmbulance.Ranks.GetLabel(
			W2FAmbulance.Permissions.GetMinRank('RevivePatient')
		)), 'error')
		return
	end

	if not W2FAmbulance.Triage.notifyValidation(src, playerId, 'revive') then return end

	if not W2FAmbulance.Care.consumeItem(src, 'revive') then
		W2FAmbulance.Care.notifyMissingItem(src, 'firstaid')
		return
	end

	TriggerClientEvent('qbx_medical:client:playerRevived', patient.PlayerData.source)
	W2FAmbulance.Triage.clear(src, playerId)
	if W2FAmbulance and W2FAmbulance.Records then
		W2FAmbulance.Records.create(
			patient.PlayerData.citizenid,
			W2FAmbulance.Core.getCharFullName(player),
			'EMS field revive'
		)
	end
	if W2FAmbulance.PublicRecords then
		W2FAmbulance.PublicRecords.logVisit(
			patient,
			player,
			'revive',
			'Patient revived in the field by EMS personnel.'
		)
	end
	TriggerClientEvent('w2f-ambulance:client:patientTreatmentResult', src, { success = true, action = 'revive', patientId = playerId })
end)

---@param targetId number
RegisterNetEvent('hospital:server:UseFirstAid', function(targetId)
	if GetInvokingResource() then return end
	local src = source
	local target = exports.qbx_core:GetPlayer(targetId)
	if not target then return end

	local canHelp = lib.callback.await('hospital:client:canHelp', targetId)
	if not canHelp then
		exports.qbx_core:Notify(src, locale('error.cant_help'), 'error')
		return
	end

	TriggerClientEvent('hospital:client:HelpPerson', src, targetId)
end)

lib.callback.register('qbx_ambulancejob:server:getNumDoctors', function()
	return exports.qbx_core:GetDutyCountType('ems')
end)

RegisterNetEvent('qbx_medical:server:playerDied', function()
	if GetInvokingResource() then return end
	local src = source
	alertAmbulance(src, locale('info.civ_died'))
end)
