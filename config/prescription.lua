Config = Config or {}

Config.Pharmacy = {
    coords = vec3(309.08, -596.79, 43.29),
    heading = 343.92,
    model = joaat('s_m_m_doctor_01'),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    targetLabel = 'Pharmacy medications',
    targetLabelNoRx = 'Pharmacy (prescription required)',
    targetIcon = 'fa-solid fa-pills',
    targetDistance = 2.4,
    itemRequired = 'medical_prescription',
    shopType = 'W2FPharmacy',
    hookShopLabel = 'Medical Pharmacy',
    blip = {
        enabled = true,
        sprite = 51,
        colour = 2,
        scale = 0.75,
        label = 'Pillbox Pharmacy',
    },
    --- Remove 1 prescription pad from the issuing medic and transfer it to the patient.
    issueConsumesFromMedic = true,
    --- Remove 1 prescription when the pharmacy shop is opened (one visit per slip).
    consumeOnOpen = true,
    consumeOnPurchase = false,
    inventory = {
        { name = 'haveitol', price = 45 },
        { name = 'dead_tired', price = 45 },
        { name = 'wakey_wakey', price = 50 },
        { name = 'oxycodone', price = 125 },
        { name = 'fentanyl', price = 175 },
    },
}

Config.Effects = {
    haveitol = {
        label = 'Haveitol',
        duration = 30000,
        progressMultiplier = 0.75,
        notification = 'Haveitol active: faster progression time.',
    },
    dead_tired = {
        label = 'Dead Tired',
        duration = 8000,
        recoilMultiplier = 0.35,
        notification = 'Dead Tired active: recoil reduced.',
    },
    fentanyl = {
        label = 'Fentanyl',
        duration = 45000,
        armorBuffer = 35,
        staminaMultiplier = 0.88,
        staminaDisplayPenalty = 12,
        faintChance = 15,
        faintInterval = 10000,
        faintDuration = 4500,
        notification = 'Fentanyl active: durability increased, stamina reduced.',
    },
    oxycodone = {
        label = 'Oxycodone',
        duration = 45000,
        healthBoost = 35,
        staminaMultiplier = 0.85,
        staminaDisplayPenalty = 15,
        notification = 'Oxycodone active: health increased, stamina reduced.',
    },
    wakey_wakey = {
        label = 'Wakey Wakey',
        duration = 60000,
        staminaRestore = 0.34,
        sprintMultiplier = 1.04,
        staminaDisplayBoost = 8,
        notification = 'Wakey Wakey active: stamina recovery increased.',
    },
}

Config.Overdose = {
    useWindow = 3 * 60 * 60 * 1000,
    chanceByUseCount = {
        [2] = 30,
        [3] = 75,
        [4] = 100,
    },
    lethal = true,
    blackoutDuration = 5000,
    notification = 'Something is very wrong...',
    damage = 8,
    damageInterval = 7000,
    duration = 45000,
}
