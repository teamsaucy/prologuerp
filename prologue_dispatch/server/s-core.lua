local ESX = exports["es_extended"]:getSharedObject()

-- Callback: get all units
ESX.RegisterServerCallback('prologue_dispatch:getGlobalUnits', function(src, cb)
    cb(GlobalUnits)
end)

-- Callback: get call history
ESX.RegisterServerCallback('prologue_dispatch:getCallHistory', function(src, cb)
    cb(CallHistory)
end)

-- Clean up unit when player disconnects
AddEventHandler('playerDropped', function(rs)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local job = xPlayer.job.name
        if job == Config.DispatcherJob then
            RemoveUnit(source)
        end
    end
end)

-- Send alert to all players with matching job
RegisterServerEvent("prologue_dispatch:Server:SendAlert")
AddEventHandler("prologue_dispatch:Server:SendAlert", function(aljob, title, text, coords, panic, id, category)
    local callId = GenerateCallId()
    local callData = {
        callId = callId,
        title = title,
        text = text,
        coords = coords,
        panic = panic,
        senderId = id,
        category = category or 'alert',
        responded = false,
        officer = nil,
    }

    -- Log the call
    TriggerEvent("prologue_dispatch:Server:logCall", callData)

    for _, playerId in ipairs(GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            local job = xPlayer.job.name
            if job == aljob then
                TriggerClientEvent("prologue_dispatch:Client:SendAlert", playerId, title, text, coords, panic, id, callId, category)
            end
        end
    end
end)

-- Send vehicle theft alert
RegisterServerEvent("prologue_dispatch:Server:SendVehRob")
AddEventHandler("prologue_dispatch:Server:SendVehRob", function(aljob, coords, model, plate, color, id)
    local callId = GenerateCallId()
    local LC = Locales[Config.Locale]
    local text = LC['Veh_Rob_01'] .. model .. " plate: " .. plate

    local callData = {
        callId = callId,
        title = LC['Vehicle_Title'],
        text = text,
        coords = coords,
        panic = false,
        senderId = id,
        category = 'theft',
        responded = false,
        officer = nil,
        color = color,
    }

    TriggerEvent("prologue_dispatch:Server:logCall", callData)

    for _, playerId in ipairs(GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            local job = xPlayer.job.name
            if job == aljob then
                TriggerClientEvent("prologue_dispatch:Client:SendVehRob", playerId, coords, model, plate, color, id, callId)
            end
        end
    end
end)
