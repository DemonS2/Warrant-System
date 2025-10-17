local QBCore = exports['qb-core']:GetCoreObject()
local inTablet = false

-- Check if player has access to warrant system
function HasWarrantAccess()
    local PlayerData = QBCore.Functions.GetPlayerData()
    local allowedJobs = {'police', 'sast', 'bcso'}
    
    for _, job in ipairs(allowedJobs) do
        if PlayerData.job.name == job then
            return true
        end
    end
    return false
end

-- NUI Callbacks
RegisterNUICallback('CloseTablet', function(data, cb)
    SetNuiFocus(false, false)
    inTablet = false
    SendNUIMessage({action = 'hideTablet'})
    cb('ok')
end)

RegisterNUICallback('SearchWarrants', function(data, cb)
    local searchTerm = data.searchTerm
    QBCore.Functions.TriggerCallback('qb-warrants:server:SearchWarrants', function(results)
        cb(results)
    end, searchTerm)
end)

RegisterNUICallback('GetAllWarrants', function(data, cb)
    TriggerServerEvent('qb-warrants:server:GetAllWarrants')
    cb('ok')
end)

RegisterNUICallback('RevokeWarrant', function(data, cb)
    local warrantId = data.warrantId
    TriggerServerEvent('qb-warrants:server:RevokeWarrant', warrantId)
    cb('ok')
end)

RegisterNUICallback('CreateWarrant', function(data, cb)
    TriggerServerEvent('qb-warrants:server:CreateWarrant', data)
    cb('ok')
end)

-- Main tablet function
function OpenWarrantTablet()
    if inTablet then 
        CloseWarrantTablet()
        return 
    end
    
    if not HasWarrantAccess() then
        QBCore.Functions.Notify('Access Denied - Police Only!', 'error')
        return
    end

    SetNuiFocus(true, true)
    inTablet = true
    SendNUIMessage({action = 'showTablet'})
end

function CloseWarrantTablet()
    SetNuiFocus(false, false)
    inTablet = false
    SendNUIMessage({action = 'hideTablet'})
end

-- Command to open tablet
RegisterCommand('warranttablet', function()
    OpenWarrantTablet()
end, false)

-- Key mapping
RegisterKeyMapping('warranttablet', 'Open Warrant Tablet', 'keyboard', 'F6')

-- Events from server
RegisterNetEvent('qb-warrants:client:OpenEvidenceInput', function(name, citizenid, reason, bounty, expiry)
    if not HasWarrantAccess() then return end
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showEvidenceInput',
        name = name,
        citizenid = citizenid,
        reason = reason,
        bounty = bounty,
        expiry = expiry
    })
end)

RegisterNetEvent('qb-warrants:client:ShowWarrantResults', function(warrants)
    if not HasWarrantAccess() then return end
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showWarrantResults',
        warrants = warrants
    })
end)

RegisterNetEvent('qb-warrants:client:ReceiveAllWarrants', function(warrantsData)
    if not HasWarrantAccess() then return end
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showAllWarrants',
        warrants = warrantsData
    })
end)

-- Ensure NUI is closed when resource stops
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        CloseWarrantTablet()
    end
end)

-- Close NUI if resource is started
Citizen.CreateThread(function()
    Wait(1000)
    SendNUIMessage({action = 'hideTablet'})
end)