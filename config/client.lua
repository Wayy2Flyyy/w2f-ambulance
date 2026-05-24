return {
    useTarget = true,
    debugPoly = false,
    minForCheckIn = 2, -- Minimum number of people with the ambulance job to prevent the check-in system from being used
    painkillerInterval = 60, -- Time in minutes that painkillers last for
    checkInHealTime = 20, -- Time in seconds that it takes to be healed from the check-in system
    laststandTimer = 300, -- Time in seconds that the laststand timer lasts
    aiHealTimer = 20, -- How long it will take to be healed after checking in, in seconds

    vehicleSettings = { -- Enable or disable vehicle extras when pulling them from the ambulance job vehicle spawner
        ['ambulance'] = { -- Model name
            extras = {
                ['1'] = false, -- on/off
                ['2'] = true,
                ['3'] = true,
                ['4'] = true,
                ['5'] = true,
                ['6'] = true,
                ['7'] = true,
                ['8'] = true,
                ['9'] = true,
                ['10'] = true,
                ['11'] = true,
                ['12'] = true,
            },
        },
        ['polmav'] = {
            livery = 1,
        },
    },
}
