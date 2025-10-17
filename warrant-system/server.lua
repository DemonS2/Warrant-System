local QBCore = exports['qb-core']:GetCoreObject()

-- Function to check if player has police access
function HasPoliceAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local allowedJobs = {'police', 'sast', 'bcso'}
    for _, job in ipairs(allowedJobs) do
        if Player.PlayerData.job.name == job then
            return true
        end
    end
    return false
end

-- Function to create a new warrant
function CreateWarrant(source, targetName, citizenid, reason, evidence, bounty, expiryHours)
    if not HasPoliceAccess(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Access Denied - Police Only!', 'error')
        return false, "Unauthorized"
    end

    local Player = QBCore.Functions.GetPlayer(source)
    local expiryDate = nil
    
    if expiryHours and expiryHours > 0 then
        expiryDate = os.time() + (expiryHours * 3600)
        expiryDate = os.date('%Y-%m-%d %H:%M:%S', expiryDate)
    end

    local insertData = {
        name = targetName,
        citizenid = citizenid,
        officer_name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        officer_cid = Player.PlayerData.citizenid,
        reason = reason,
        evidence = evidence,
        bounty = bounty or 0,
        expiry_date = expiryDate
    }

    local result = MySQL.insert.await('INSERT INTO warrants (name, citizenid, officer_name, officer_cid, reason, evidence, bounty, expiry_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        insertData.name, insertData.citizenid, insertData.officer_name, insertData.officer_cid, insertData.reason, insertData.evidence, insertData.bounty, insertData.expiry_date
    })

    if result then
        -- Deduct bounty from treasury if set
        if bounty and bounty > 0 then
            DeductFromTreasury(bounty)
        end
        
        TriggerClientEvent('QBCore:Notify', source, 'Warrant issued successfully!', 'success')
        TriggerEvent('qb-warrants:client:WarrantCreated', result, insertData)
        return true, result
    else
        return false, "Database error"
    end
end

-- Function to revoke warrant
function RevokeWarrant(source, warrantId)
    if not HasPoliceAccess(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Access Denied - Police Only!', 'error')
        return false, "Unauthorized"
    end

    local warrant = MySQL.single.await('SELECT * FROM warrants WHERE id = ?', {warrantId})
    if not warrant then
        TriggerClientEvent('QBCore:Notify', source, 'Warrant not found', 'error')
        return false, "Warrant not found"
    end

    if warrant.status ~= 'active' then
        TriggerClientEvent('QBCore:Notify', source, 'Warrant is not active', 'error')
        return false, "Warrant is not active"
    end

    local Player = QBCore.Functions.GetPlayer(source)
    local update = MySQL.update.await('UPDATE warrants SET status = "revoked", revoked_date = NOW(), revoked_by = ? WHERE id = ?', {
        Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        warrantId
    })

    if update then
        -- Return bounty to treasury if warrant had bounty
        if warrant.bounty and warrant.bounty > 0 then
            AddToTreasury(warrant.bounty)
        end
        
        TriggerClientEvent('QBCore:Notify', source, 'Warrant revoked successfully!', 'success')
        TriggerEvent('qb-warrants:client:WarrantRevoked', warrantId)
        return true
    else
        TriggerClientEvent('QBCore:Notify', source, 'Failed to revoke warrant', 'error')
        return false, "Database error"
    end
end

-- Function to check warrants
function CheckWarrants(searchTerm)
    local query = 'SELECT * FROM warrants WHERE (name LIKE ? OR citizenid = ?) AND status = "active"'
    local params = {'%' .. searchTerm .. '%', searchTerm}
    
    local warrants = MySQL.query.await(query, params)
    return warrants or {}
end

-- Function to get all active warrants
function GetAllActiveWarrants()
    local warrants = MySQL.query.await('SELECT * FROM warrants WHERE status = "active" ORDER BY issued_date DESC')
    return warrants or {}
end

-- Treasury management
function DeductFromTreasury(amount)
    -- Assuming you have a treasury system in place
    -- This would need to be adapted to your specific treasury implementation
    TriggerEvent('qb-police:server:deductFromTreasury', amount, 'Warrant Bounty')
end

function AddToTreasury(amount)
    -- For when warrants are revoked and bounty needs to be returned
    TriggerEvent('qb-police:server:addToTreasury', amount, 'Warrant Bounty Return')
end

-- Auto-expiry system
function CheckExpiredWarrants()
    local expired = MySQL.update.await('UPDATE warrants SET status = "expired" WHERE status = "active" AND expiry_date IS NOT NULL AND expiry_date < NOW()')
    if expired and expired > 0 then
        print(expired .. " warrants have expired")
    end
end

-- Bounty payout when warrant is executed (arrest made)
function ExecuteWarrant(warrantId, officerCitizenId)
    local warrant = MySQL.single.await('SELECT * FROM warrants WHERE id = ?', {warrantId})
    if not warrant or warrant.status ~= 'active' then
        return false, "Invalid warrant"
    end

    local update = MySQL.update.await('UPDATE warrants SET status = "executed" WHERE id = ?', {warrantId})
    if update then
        -- Pay bounty to officer
        if warrant.bounty and warrant.bounty > 0 then
            local officer = QBCore.Functions.GetPlayerByCitizenId(officerCitizenId)
            if officer then
                officer.Functions.AddMoney('bank', warrant.bounty, 'Warrant Bounty Payout')
                TriggerClientEvent('QBCore:Notify', officer.PlayerData.source, 'You received $' .. warrant.bounty .. ' for executing warrant #' .. warrantId, 'success')
            end
        end
        
        TriggerEvent('qb-warrants:client:WarrantExecuted', warrantId)
        return true
    end
    return false
end

-- Callbacks
QBCore.Functions.CreateCallback('qb-warrants:server:SearchWarrants', function(source, cb, searchTerm)
    local warrants = CheckWarrants(searchTerm)
    cb(warrants)
end)

-- Commands
QBCore.Commands.Add("issuewarrant", "Issue a warrant (Police Only)", {
    {name = "name", help = "Target Name"},
    {name = "citizenid", help = "Target Citizen ID"},
    {name = "reason", help = "Reason for warrant"},
    {name = "bounty", help = "Bounty amount (optional)"},
    {name = "expiry", help = "Expiry in hours (optional)"}
}, true, function(source, args)
    if not HasPoliceAccess(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Access Denied - Police Only!', 'error')
        return
    end

    if #args < 3 then
        TriggerClientEvent('QBCore:Notify', source, 'Usage: /issuewarrant [name] [citizenid] [reason] [bounty] [expiry]', 'error')
        return
    end

    local name = args[1]
    local citizenid = args[2]
    local reason = table.concat(args, " ", 3)
    local bounty = 0
    local expiry = 0

    -- Check if last arguments are bounty and expiry
    local lastArgs = args[#args]
    if tonumber(lastArgs) then
        expiry = tonumber(lastArgs)
        table.remove(args)
        lastArgs = args[#args]
        if tonumber(lastArgs) then
            bounty = tonumber(lastArgs)
            table.remove(args)
            reason = table.concat(args, " ", 3)
        end
    end

    -- Open evidence input UI
    TriggerClientEvent('qb-warrants:client:OpenEvidenceInput', source, name, citizenid, reason, bounty, expiry)
end)

QBCore.Commands.Add("revokewarrant", "Revoke a warrant (Police Only)", {
    {name = "id", help = "Warrant ID"}
}, true, function(source, args)
    if not HasPoliceAccess(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Access Denied - Police Only!', 'error')
        return
    end

    if #args < 1 then
        TriggerClientEvent('QBCore:Notify', source, 'Usage: /revokewarrant [warrant_id]', 'error')
        return
    end

    local warrantId = tonumber(args[1])
    if not warrantId then
        TriggerClientEvent('QBCore:Notify', source, 'Invalid warrant ID', 'error')
        return
    end

    RevokeWarrant(source, warrantId)
end)

QBCore.Commands.Add("checkwarrant", "Check for warrants", {
    {name = "search", help = "Name or Citizen ID"}
}, true, function(source, args)
    if not HasPoliceAccess(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Access Denied - Police Only!', 'error')
        return
    end

    if #args < 1 then
        TriggerClientEvent('QBCore:Notify', source, 'Usage: /checkwarrant [name/citizenid]', 'error')
        return
    end

    local searchTerm = table.concat(args, " ")
    local warrants = CheckWarrants(searchTerm)

    if #warrants > 0 then
        TriggerClientEvent('qb-warrants:client:ShowWarrantResults', source, warrants)
    else
        TriggerClientEvent('QBCore:Notify', source, 'No active warrants found for: ' .. searchTerm, 'info')
    end
end)

-- Events
RegisterNetEvent('qb-warrants:server:CreateWarrant', function(data)
    local src = source
    CreateWarrant(src, data.name, data.citizenid, data.reason, data.evidence, data.bounty, data.expiry)
end)

RegisterNetEvent('qb-warrants:server:GetAllWarrants', function()
    local src = source
    local warrants = GetAllActiveWarrants()
    TriggerClientEvent('qb-warrants:client:ReceiveAllWarrants', src, warrants)
end)

RegisterNetEvent('qb-warrants:server:RevokeWarrant', function(warrantId)
    local src = source
    RevokeWarrant(src, warrantId)
end)

RegisterNetEvent('qb-warrants:server:ExecuteWarrant', function(warrantId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    ExecuteWarrant(warrantId, Player.PlayerData.citizenid)
end)

-- Auto-expiry check every minute
if Config.AutoExpiryCheck then
    Citizen.CreateThread(function()
        while true do
            CheckExpiredWarrants()
            Citizen.Wait(Config.ExpiryCheckInterval)
        end
    end)
end