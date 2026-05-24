--- Internal medical export helper (embedded qbx_medical core lives in this resource).
local resource = GetCurrentResourceName()

W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance

function W2FAmbulance.Medical(name, ...)
    return exports[resource][name](...)
end
