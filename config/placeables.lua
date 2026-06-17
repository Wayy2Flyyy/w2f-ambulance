Config = Config or {}

--- Placeable EMS props (training equipment, field gear, etc.)
Config.Placeables = {
    Enabled = true,
    Debug = false,

    Controls = {
        Place = 24,        -- LMB
        Cancel = 25,       -- RMB
        CancelAlt = 177,   -- BACKSPACE
        RotateLeft = 14,   -- scroll up
        RotateRight = 15,  -- scroll down
    },

    Placement = {
        UseCursor = true,
        CursorMaxRayDistance = 14.0,
        DefaultDistance = 2.5,
        DefaultHeightOffset = 0.0,
        DefaultRotationSpeed = 2.5,
        DefaultMaxDistanceFromPlayer = 6.5,
        RequireGround = true,
        AllowInVehicle = false,
        FreezePlacedObjects = true,
        UseOutlinePreview = true,
        PreviewAlpha = 165,
    },

    Persistence = {
        Enabled = true,
        SaveToDatabase = true,
        LoadOnResourceStart = true,
        SyncOnPlayerJoin = true,
    },

    Limits = {
        Enabled = true,
        MaxObjectsPerPlayer = 3,
        MaxObjectsGlobal = 40,
        MinimumDistanceBetweenObjects = 2.0,
    },

    Ownership = {
        OnlyOwnerCanPickup = true,
        AllowAdminPickup = true,
        AllowEmsOnDutyPickup = true,
    },

    Security = {
        BlockPlacementInWater = true,
    },

    Items = {
        ems_training_dummy = {
            label = 'CPR Training Dummy (Freddy)',
            prop = 'dummy',
            isCustomProp = true,
            removeItemOnPlace = true,
            pickupEnabled = true,
            giveItemOnPickup = true,
            category = 'training',
            zOffset = 0.0,
            placement = {
                distance = 2.8,
                heightOffset = 0.0,
                rotationSpeed = 3.0,
                maxDistanceFromPlayer = 6.5,
            },
        },
    },
}
