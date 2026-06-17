W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.CatalogClient = W2FAmbulance.CatalogClient or {}

function W2FAmbulance.CatalogClient.openArmory()
    if not W2FAmbulance.Client.isEmsOnDuty() then
        exports.qbx_core:Notify(locale('error.not_ems'), 'error')
        return
    end
    if not W2FAmbulance.Client.hasPermission('UseArmory') then
        W2FAmbulance.Client.notifyRankDenied('UseArmory')
        return
    end
    local catalog = lib.callback.await(W2FAmbulance.Constants.Callbacks.GetArmoryCatalog, false)
    if not catalog then
        exports.qbx_core:Notify(locale('error.not_ems'), 'error')
        return
    end
    W2FAmbulance.UI.Equipment.Open(catalog, 'armory')
end

function W2FAmbulance.CatalogClient.openMedCabinet()
    if not W2FAmbulance.Client.isEmsOnDuty() then
        exports.qbx_core:Notify(locale('error.not_ems'), 'error')
        return
    end
    if not W2FAmbulance.Client.hasPermission('UseMedCabinet') then
        W2FAmbulance.Client.notifyRankDenied('UseMedCabinet')
        return
    end
    local catalog = lib.callback.await(W2FAmbulance.Constants.Callbacks.GetMedCabinetCatalog, false)
    if not catalog then
        exports.qbx_core:Notify(locale('error.med_cabinet_denied'), 'error')
        return
    end
    W2FAmbulance.UI.Equipment.Open(catalog, 'medCabinet')
end

function W2FAmbulance.CatalogClient.openGarage(kind, coords)
    if not W2FAmbulance.Client.isEmsOnDuty() then
        exports.qbx_core:Notify(locale('error.not_ems'), 'error')
        return
    end
    local perm = kind == 'air' and 'UseAirGarage' or 'UseGarage'
    if not W2FAmbulance.Client.hasPermission(perm) then
        W2FAmbulance.Client.notifyRankDenied(perm)
        return
    end
    local catalog = lib.callback.await(W2FAmbulance.Constants.Callbacks.GetGarageCatalog, false, kind)
    if not catalog then
        exports.qbx_core:Notify(locale('error.not_ems'), 'error')
        return
    end
    if W2FAmbulance.GaragePreview and W2FAmbulance.GaragePreview.setActiveGarage then
        W2FAmbulance.GaragePreview.setActiveGarage(coords, kind)
    end
    W2FAmbulance.UI.Garage.Open(catalog, coords, kind)
end
