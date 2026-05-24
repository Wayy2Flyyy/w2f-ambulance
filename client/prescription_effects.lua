local activeEffects = {}
local oxInventory = exports.ox_inventory
local recentUses = {}
local overdoseActive = false

-- Per-drug stamina display modifiers (positive = boost, negative = penalty).
-- Summed and pushed to LocalPlayer.state.w2fStaminaModifier so the w2f-hud
-- stamina hex visually reflects every active drug at once.
local staminaModifiers = {}

local function notify(message, notifyType)
	local t = 'inform'

	if notifyType == 'error' then
		t = 'error'
	elseif notifyType == 'warning' then
		t = 'warning'
	elseif notifyType == 'success' then
		t = 'success'
	elseif notifyType == 'info' or notifyType == 'inform' then
		t = 'inform'
	end

	lib.notify({ description = message, type = t })
end

local function publishStaminaModifier()
	if not LocalPlayer or not LocalPlayer.state then return end

	local total = 0
	for _, delta in pairs(staminaModifiers) do
		total = total + (tonumber(delta) or 0)
	end

	if total == 0 then
		LocalPlayer.state:set('w2fStaminaModifier', nil, true)
	else
		LocalPlayer.state:set('w2fStaminaModifier', total, true)
	end
end

local function setStaminaModifier(name, delta)
	staminaModifiers[name] = delta
	publishStaminaModifier()
end

local function clearStaminaModifier(name)
	if staminaModifiers[name] == nil then return end
	staminaModifiers[name] = nil
	publishStaminaModifier()
end

local function clearAllStaminaModifiers()
	staminaModifiers = {}
	publishStaminaModifier()
end

local function effectConfig(name)
	return Config.Effects and Config.Effects[name]
end

local function beginEffect(name, duration)
	local token = (activeEffects[name] or 0) + 1
	activeEffects[name] = token

	SetTimeout(duration or 0, function()
		if activeEffects[name] == token then
			activeEffects[name] = nil
		end
	end)

	return token
end

local function effectActive(name, token)
	return activeEffects[name] == token
end

-- Returns true if any drug effect is still active (used so one drug ending
-- doesn't strip overrides another drug is still applying).
local function anyEffectActive()
	for _, token in pairs(activeEffects) do
		if token then return true end
	end
	return false
end

-- Reset per-frame overrides. Called when an individual drug ends.
-- If other drugs are still active, leave move-rate / sprint alone so the
-- remaining drugs' loops keep applying their own values; only clear the
-- progress multiplier when no progress-effect drug is active.
-- When `force` is true (resource stop), reset everything unconditionally.
local function cleanupOverrides(force)
	if force or not anyEffectActive() then
		local ped = PlayerPedId()
		if ped and ped ~= 0 then
			SetPedMoveRateOverride(ped, 1.0)
		end
		SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
	end

	-- Progress multiplier is owned exclusively by haveitol; only clear when
	-- haveitol is no longer active.
	if (force or not activeEffects.haveitol) and LocalPlayer and LocalPlayer.state then
		LocalPlayer.state:set('w2fDrugProgressMultiplier', nil, true)
	end
end

local function blackout(duration)
	local ped = PlayerPedId()

	DoScreenFadeOut(350)
	SetPedToRagdoll(ped, duration or 5000, duration or 5000, 0, false, false, false)
	Wait(duration or 5000)
	DoScreenFadeIn(700)
end

local function startOverdose()
	if overdoseActive then return end

	local cfg = Config.Overdose or {}
	overdoseActive = true
	-- Wipe the recent-use buffer so OD does not immediately retrigger after recovery.
	recentUses = {}
	notify(cfg.notification or 'Something is very wrong...', 'error')

	-- Lethal OD: brief blackout for atmosphere, then kill the player.
	if cfg.lethal then
		CreateThread(function()
			blackout(cfg.blackoutDuration or 5000)
			local ped = PlayerPedId()
			if ped and ped ~= 0 then
				SetEntityHealth(ped, 0)
			end
			overdoseActive = false
		end)
		return
	end

	-- Non-lethal damage-over-time fallback. Damage is floored at 1 HP.
	CreateThread(function()
		local endsAt = GetGameTimer() + (cfg.duration or 45000)
		local nextDamage = 0
		local nextBlackout = 0

		while overdoseActive and GetGameTimer() < endsAt do
			local now = GetGameTimer()
			local ped = PlayerPedId()

			if now >= nextDamage then
				nextDamage = now + (cfg.damageInterval or 7000)
				local health = GetEntityHealth(ped)
				SetEntityHealth(ped, math.max(101, health - (cfg.damage or 8)))
			end

			if now >= nextBlackout then
				nextBlackout = now + math.random(9000, 16000)
				blackout(cfg.blackoutDuration or 5000)
			end

			Wait(500)
		end

		overdoseActive = false
		recentUses = {}
	end)
end

-- Look up the OD chance (0-100) for a given use count using
-- Config.Overdose.chanceByUseCount. Counts above the highest defined key fall
-- back to that key's chance (so a single `[4] = 100` entry covers 5+ as well).
local function odChanceForUseCount(useCount)
	local chances = (Config.Overdose and Config.Overdose.chanceByUseCount) or {}

	if useCount < 2 then return 0 end
	if chances[useCount] then return chances[useCount] end

	local highestKey, highestChance = 0, 0
	for k, v in pairs(chances) do
		if k > highestKey then
			highestKey = k
			highestChance = v
		end
	end

	if useCount > highestKey and highestKey > 0 then
		return highestChance
	end

	return 0
end

local function registerDrugUse(_effectName)
	local cfg = Config.Overdose or {}
	local now = GetGameTimer()
	local window = cfg.useWindow or (3 * 60 * 60 * 1000)

	recentUses[#recentUses + 1] = now

	for i = #recentUses, 1, -1 do
		if now - recentUses[i] > window then
			table.remove(recentUses, i)
		end
	end

	-- Hidden cooldown: silently roll OD chance based on uses in the window.
	local chance = odChanceForUseCount(#recentUses)
	if chance > 0 and math.random(100) <= chance then
		startOverdose()
	end
end

local function clearProgressMultiplier(name, token)
	if activeEffects[name] and activeEffects[name] ~= token then return end

	if LocalPlayer and LocalPlayer.state then
		LocalPlayer.state:set('w2fDrugProgressMultiplier', nil, true)
	end
end

local function useDrug(data, effectName, applyEffect)
	local cfg = effectConfig(effectName)
	if not cfg then
		return notify(('Drug effect missing config: %s'):format(effectName), 'error')
	end

	oxInventory:useItem(data, function(used)
		if not used then return end

		registerDrugUse(effectName)
		notify(cfg.notification or ('Used %s'):format(cfg.label or effectName), 'info')
		applyEffect(cfg)
	end)
end

local function applyProgressEffect(name, cfg)
	local token = beginEffect(name, cfg.duration)

	if cfg.progressMultiplier and LocalPlayer and LocalPlayer.state then
		LocalPlayer.state:set('w2fDrugProgressMultiplier', cfg.progressMultiplier, true)
	end

	CreateThread(function()
		while effectActive(name, token) do
			Wait(250)
		end

		clearProgressMultiplier(name, token)
	end)
end

local function applyDeadTired(cfg)
	local token = beginEffect('dead_tired', cfg.duration)
	local recoil = cfg.recoilMultiplier or 0.35

	CreateThread(function()
		while effectActive('dead_tired', token) do
			local ped = PlayerPedId()

			if IsPedArmed(ped, 4) then
				SetWeaponRecoilShakeAmplitude(GetSelectedPedWeapon(ped), recoil)
			end

			Wait(0)
		end
	end)
end

local function applyFentanyl(cfg)
	local token = beginEffect('fentanyl', cfg.duration)
	local ped = PlayerPedId()
	local startHealth = GetEntityHealth(ped)
	local startArmor = GetPedArmour(ped)
	local armorBuffer = cfg.armorBuffer or 0
	local faintInterval = cfg.faintInterval or 10000
	local faintChance = cfg.faintChance or 15
	local faintDuration = cfg.faintDuration or 4500
	local nextFaintRoll = GetGameTimer() + faintInterval

	if armorBuffer > 0 then
		SetPedArmour(ped, math.min(100, startArmor + armorBuffer))
	end
	local protectedArmor = GetPedArmour(ped)

	-- Visible stamina drop in the HUD hex (default 12% per spec).
	setStaminaModifier('fentanyl', -(cfg.staminaDisplayPenalty or 12))

	CreateThread(function()
		while effectActive('fentanyl', token) do
			ped = PlayerPedId()

			if GetEntityHealth(ped) < startHealth or GetPedArmour(ped) < protectedArmor then
				activeEffects.fentanyl = nil
				notify('Fentanyl durability buffer broke after taking damage.', 'warning')
				break
			end

			-- Sprint multiplier is clamped to 1.0 internally, so a sub-1.0 value
			-- is a no-op. Apply the stamina penalty via move-rate only.
			SetPedMoveRateOverride(ped, cfg.staminaMultiplier or 0.88)

			if GetGameTimer() >= nextFaintRoll then
				nextFaintRoll = GetGameTimer() + faintInterval

				if math.random(100) <= faintChance then
					SetPedToRagdoll(ped, faintDuration, faintDuration, 0, false, false, false)
					notify('You feel faint.', 'warning')
				end
			end

			Wait(100)
		end

		clearStaminaModifier('fentanyl')
		cleanupOverrides()
	end)
end

local function applyOxycodone(cfg)
	local ped = PlayerPedId()
	local maxHealth = GetEntityMaxHealth(ped)
	local health = GetEntityHealth(ped)
	local token = beginEffect('oxycodone', cfg.duration)

	-- Visible health gain in the HUD health bar (one-shot top-up).
	SetEntityHealth(ped, math.min(maxHealth, health + (cfg.healthBoost or 25)))

	-- Visible stamina drop in the HUD hex (default 15% per spec).
	setStaminaModifier('oxycodone', -(cfg.staminaDisplayPenalty or 15))

	CreateThread(function()
		while effectActive('oxycodone', token) do
			-- Sprint multiplier <1.0 is a no-op; rely on move-rate override only.
			SetPedMoveRateOverride(PlayerPedId(), cfg.staminaMultiplier or 0.85)
			Wait(100)
		end

		clearStaminaModifier('oxycodone')
		cleanupOverrides()
	end)
end

local function applyWakeyWakey(cfg)
	local token = beginEffect('wakey_wakey', cfg.duration)

	-- Visible stamina boost (default +8). RestorePlayerStamina keeps the
	-- native stamina pegged near full so the bar visibly stays high.
	setStaminaModifier('wakey_wakey', cfg.staminaDisplayBoost or 8)

	CreateThread(function()
		while effectActive('wakey_wakey', token) do
			RestorePlayerStamina(PlayerId(), cfg.staminaRestore or 0.25)

			if cfg.sprintMultiplier then
				SetRunSprintMultiplierForPlayer(PlayerId(), cfg.sprintMultiplier)
			end

			Wait(500)
		end

		clearStaminaModifier('wakey_wakey')
		cleanupOverrides()
	end)
end

exports('useHaveitol', function(data)
	useDrug(data, 'haveitol', function(cfg)
		applyProgressEffect('haveitol', cfg)
	end)
end)

exports('useDeadTired', function(data)
	useDrug(data, 'dead_tired', applyDeadTired)
end)

exports('useFentanyl', function(data)
	useDrug(data, 'fentanyl', applyFentanyl)
end)

exports('useOxycodone', function(data)
	useDrug(data, 'oxycodone', applyOxycodone)
end)

exports('useWakeyWakey', function(data)
	useDrug(data, 'wakey_wakey', applyWakeyWakey)
end)

AddEventHandler('onClientResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then return end

	-- Clear in-memory effect tracking so a restart starts from a clean slate.
	for name in pairs(activeEffects) do
		activeEffects[name] = nil
	end
	recentUses = {}
	overdoseActive = false

	clearAllStaminaModifiers()
	cleanupOverrides(true)
end)
