W2FAmbulance = _G.W2FAmbulance or {}
_G.W2FAmbulance = W2FAmbulance
W2FAmbulance.Constants = W2FAmbulance.Constants or {}

W2FAmbulance.Constants.Callbacks = {
    GetArmoryCatalog = 'w2f-ambulance:cb:getArmoryCatalog',
    GetMedCabinetCatalog = 'w2f-ambulance:cb:getMedCabinetCatalog',
    GetGarageCatalog = 'w2f-ambulance:cb:getGarageCatalog',
    TakeArmoryItem = 'w2f-ambulance:cb:takeArmoryItem',
    TakeMedCabinetItem = 'w2f-ambulance:cb:takeMedCabinetItem',
    GetTabletDashboard = 'w2f-ambulance:cb:getTabletDashboard',
    TabletHire = 'w2f-ambulance:cb:tabletHire',
    TabletFire = 'w2f-ambulance:cb:tabletFire',
    TabletSetGrade = 'w2f-ambulance:cb:tabletSetGrade',
    TabletPostAnnouncement = 'w2f-ambulance:cb:tabletPostAnnouncement',
    SearchRecords = 'w2f-ambulance:cb:searchRecords',
    SearchPublicRecords = 'w2f-ambulance:cb:searchPublicRecords',
    SearchCitizens = 'w2f-ambulance:cb:searchCitizens',
    GetPatientFile = 'w2f-ambulance:cb:getPatientFile',
    AddClinicalNote = 'w2f-ambulance:cb:addClinicalNote',
    PublishPublicRecord = 'w2f-ambulance:cb:publishPublicRecord',
    GetMyPublicRecords = 'w2f-ambulance:cb:getMyPublicRecords',
    GetAuditLogs = 'w2f-ambulance:cb:getAuditLogs',
}

W2FAmbulance.Constants.Events = {
    OpenCommandTablet = 'w2f-ambulance:client:openCommandTablet',
    OpenRadial = 'w2f-ambulance:client:openRadial',
    TestMinigame = 'w2f-ambulance:client:testMinigame',
    SyncDutyBlips = 'w2f-ambulance:client:syncDutyBlips',
    RefreshDutyBlips = 'w2f-ambulance:server:refreshDutyBlips',
}
