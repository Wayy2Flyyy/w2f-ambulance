Config = Config or {}

Config.Systems = {
    Radial = {
        Key = 'F6',
        Command = 'emsradial',
    },
    CommandTablet = {
        Command = 'emstablet',
        OpenItem = 'ems_command_tablet',
        MinRankPermission = 'HighCommandAccess',
    },
    --- Typed chat commands are registered in server/commands.lua via lib.addCommand.
    Commands = {
        alert = '911e',
        status = 'status',
        heal = 'heal',
        revive = 'revivep',
        stabilize = 'stabilize',
        assist = 'assist',
        prescribe = 'prescribe',
        minigameTest = 'emsmgtest',
    },
    --- Live map blips for on-duty EMS personnel (visible to other on-duty EMS).
    DutyBlips = {
        Enabled = true,
        RefreshSeconds = 10,
        Sprite = 1,
        Colour = 1, --- Red
        Scale = 0.85,
        ShowHeading = true,
    },
}

Config.ItemImagePath = 'nui://ox_inventory/web/images/%s.png'
