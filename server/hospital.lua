--- Contains code relevant to the physical hospital building. Things like checking in, beds, spawning vehicles, etc.

---@class Player object from core

local config = require 'config.server'
local sharedConfig = require 'config.shared'
local triggerEventHooks = require '@qbx_core.modules.hooks'
local doctorCalled = false

---@type table<string, table<number, boolean>>
local hospitalBedsTaken = {}

for hospitalName, hospital in pairs(sharedConfig.locations.hospitals) do
	hospitalBedsTaken[hospitalName] = {}
	for i = 1, #hospital.beds do
		hospitalBedsTaken[hospitalName][i] = false
	end
end

local function getOpenBed(hospitalName)
	local beds = hospitalBedsTaken[hospitalName]
	for i = 1, #beds do
		local isTaken = beds[i]
		if not isTaken then return i end
	end
end

lib.callback.register('qbx_ambulancejob:server:getOpenBed', function(_, hospitalName)
	return getOpenBed(hospitalName)
end)

---@param src number
local function billPlayer(src)
	local player = exports.qbx_core:GetPlayer(src)
	player.Functions.RemoveMoney('bank', sharedConfig.checkInCost, 'respawned-at-hospital')
	config.depositSociety('ambulance', sharedConfig.checkInCost)
	TriggerClientEvent('hospital:client:SendBillEmail', src, sharedConfig.checkInCost)
	if W2FAmbulance.PublicRecords then
		W2FAmbulance.PublicRecords.logVisit(
			player,
			nil,
			'hospital',
			('Hospital treatment received. Billing charge: $%s'):format(sharedConfig.checkInCost)
		)
	end
end

RegisterNetEvent('qbx_ambulancejob:server:playerEnteredBed', function(hospitalName, bedIndex)
	if GetInvokingResource() then return end
	local src = source
	billPlayer(src)
	hospitalBedsTaken[hospitalName][bedIndex] = true
end)

RegisterNetEvent('qbx_ambulancejob:server:playerLeftBed', function(hospitalName, bedIndex)
	if GetInvokingResource() then return end
	hospitalBedsTaken[hospitalName][bedIndex] = false
end)

---@param playerId number
RegisterNetEvent('hospital:server:putPlayerInBed', function(playerId, hospitalName, bedIndex)
	if GetInvokingResource() then return end
	local src = source
	local player = exports.qbx_core:GetPlayer(src)
	if not player or not W2FAmbulance.Core.isEmsOnDuty(player) then return end
	if not W2FAmbulance.Core.hasPermission(player, 'PutPatientInBed') then
		exports.qbx_core:Notify(src, locale('error.rank_required', W2FAmbulance.Ranks.GetLabel(
			W2FAmbulance.Permissions.GetMinRank('PutPatientInBed')
		)), 'error')
		return
	end
	TriggerClientEvent('qbx_ambulancejob:client:putPlayerInBed', playerId, hospitalName, bedIndex)
end)

lib.callback.register('qbx_ambulancejob:server:isBedTaken', function(_, hospitalName, bedIndex)
	return hospitalBedsTaken[hospitalName][bedIndex]
end)

---@param src number
local function wipeInventory(src)
	exports.ox_inventory:ClearInventory(src)
	exports.qbx_core:Notify(src, locale('error.possessions_taken'), 'error')
end

lib.callback.register('qbx_ambulancejob:server:spawnVehicle', function(source, vehicleRef, vehicleCoords, garageAnchor)
	local player = exports.qbx_core:GetPlayer(source)
	if not player or not W2FAmbulance.Core.isEmsOnDuty(player) then return end

	local entry, kind = W2FAmbulance.Equipment.GetVehicleEntryById(vehicleRef)
	if not entry then return end

	local vehicleName = entry.model
	local grade = W2FAmbulance.Core.getGrade(player)
	local perm = kind == 'air' and 'UseAirGarage' or 'UseGarage'

	if not W2FAmbulance.Core.hasPermission(player, perm) then
		exports.qbx_core:Notify(source, locale('error.rank_required', W2FAmbulance.Ranks.GetLabel(
			W2FAmbulance.Permissions.GetMinRank(perm)
		)), 'error')
		return
	end

	if not W2FAmbulance.Equipment.CanTakeVehicle(grade, vehicleRef, kind) then
		exports.qbx_core:Notify(source, locale('error.rank_required', W2FAmbulance.Equipment.RankLabel(
			entry.minRank or 0
		)), 'error')
		return
	end

	local spawnCoords = vehicleCoords
	if type(spawnCoords) == 'table' and spawnCoords.x and spawnCoords.y and spawnCoords.z then
		spawnCoords = vec4(spawnCoords.x + 0.0, spawnCoords.y + 0.0, spawnCoords.z + 0.0, spawnCoords.w or 0.0)
	elseif type(spawnCoords) ~= 'vector4' then
		spawnCoords = nil
	end

	if spawnCoords and garageAnchor and type(garageAnchor) == 'table' and garageAnchor.x then
		local anchor = vec3(garageAnchor.x + 0.0, garageAnchor.y + 0.0, garageAnchor.z + 0.0)
		local maxDist = ((Config.GaragePreview and Config.GaragePreview.MaxDistanceFromGarage) or 12.0) + 2.0
		if #(vec3(spawnCoords.x, spawnCoords.y, spawnCoords.z) - anchor) > maxDist then
			exports.qbx_core:Notify(source, locale('error.garage_preview_invalid_spot'), 'error')
			return
		end
	end

	local netId, veh = qbx.spawnVehicle({
		spawnSource = spawnCoords or garageAnchor or source,
		model = vehicleName,
		warp = GetPlayerPed(source),
	})

	local vehType = GetVehicleType(veh)
	local platePrefix = (vehType == 'heli') and locale('info.heli_plate') or locale('info.amb_plate')
	local plate = platePrefix .. tostring(math.random(1000, 9999))

	SetVehicleNumberPlateText(veh, plate)
	TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
	return netId
end)

local function sendDoctorAlert()
	if doctorCalled then return end
	doctorCalled = true
	local _, doctors = exports.qbx_core:GetDutyCountType('ems')
	for i = 1, #doctors do
		local doctor = doctors[i]
		exports.qbx_core:Notify(doctor, locale('info.dr_needed'), 'inform')
	end

	SetTimeout(config.doctorCallCooldown * 60000, function()
		doctorCalled = false
	end)
end

local function canCheckIn(source, hospitalName)
	local numDoctors = exports.qbx_core:GetDutyCountType('ems')
	if numDoctors >= sharedConfig.minForCheckIn then
		exports.qbx_core:Notify(source, locale('info.dr_alert'), 'inform')
		sendDoctorAlert()
		return false
	end

	if not triggerEventHooks('checkIn', { source = source, hospitalName = hospitalName }) then return false end

	return true
end

lib.callback.register('qbx_ambulancejob:server:canCheckIn', canCheckIn)

---Sends the patient to an open bed within the hospital
---@param src number the player doing the checking in
---@param patientSrc number the player being checked in
---@param hospitalName string name of the hospital matching the config where player should be placed
local function checkIn(src, patientSrc, hospitalName)
	if src == patientSrc and not canCheckIn(patientSrc, hospitalName) then return false end

	local bedIndex = getOpenBed(hospitalName)
	if not bedIndex then
		exports.qbx_core:Notify(src, locale('error.beds_taken'), 'error')
		return false
	end

	TriggerClientEvent('qbx_ambulancejob:client:checkedIn', patientSrc, hospitalName, bedIndex)
	return true
end

lib.callback.register('qbx_ambulancejob:server:checkIn', checkIn)

exports('CheckIn', checkIn)

local function respawn(src)
	local player = exports.qbx_core:GetPlayer(src)
	local closestHospital
	if player.PlayerData.metadata.injail > 0 then
		closestHospital = 'jail'
	else
		local coords = GetEntityCoords(GetPlayerPed(src))
		local closest = nil

		for hospitalName, hospital in pairs(sharedConfig.locations.hospitals) do
			if hospitalName ~= 'jail' then
				if not closest or #(coords - hospital.coords) < #(coords - closest) then
					closest = hospital.coords
					closestHospital = hospitalName
				end
			end
		end
	end

	local bedIndex = getOpenBed(closestHospital)
	if not bedIndex then
		exports.qbx_core:Notify(src, locale('error.beds_taken'), 'error')
		return
	end
	TriggerClientEvent('qbx_ambulancejob:client:checkedIn', src, closestHospital, bedIndex)

	if config.wipeInvOnRespawn then
		wipeInventory(src)
	end
end

AddEventHandler('qbx_medical:server:playerRespawned', respawn)

RegisterNetEvent('w2f-ambulance:server:forceHospitalRespawn', function()
	if GetInvokingResource() then return end
	TriggerEvent('qbx_medical:server:playerRespawned', source)
end)
