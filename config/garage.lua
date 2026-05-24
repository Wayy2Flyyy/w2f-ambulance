Config = Config or {}

--- Minimal ground hints at EMS motor pool spawn / return points.
Config.GarageMarkers = {
    Enabled = true,
    DrawDistance = 14.0,
    Spawn = {
        type = 25,
        scale = vec3(0.38, 0.38, 0.05),
        color = { r = 45, g = 212, b = 191, a = 72 },
        zOffset = 0.0,
    },
    Return = {
        type = 25,
        scale = vec3(0.34, 0.34, 0.05),
        color = { r = 255, g = 165, b = 0, a = 68 },
        zOffset = 0.0,
    },
}

--- Spinning vehicle preview (same flow as w2f-police garage preview).
Config.GaragePreview = {
    Enabled = true,
    Alpha = 150,
    SpinSpeed = 16.0,
    CamAngle = 225.0,
    CamDistance = 6.0,
    CamHeight = 1.85,
    CamFov = 48.0,
    Hologram = {
        primary = { r = 45, g = 212, b = 191, a = 230 },
        secondary = { r = 200, g = 210, b = 225, a = 180 },
    },
}
