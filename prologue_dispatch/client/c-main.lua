local Cooldown = false
LC = Locales[Config.Locale]

Calls = {}
Show = false
ShowLarg = false
ShowLog = false

-----------------------
---- Alert Events -----
-----------------------

RegisterNetEvent("prologue_dispatch:Client:SendAlert")
AddEventHandler("prologue_dispatch:Client:SendAlert", function(title, text, coords, panic, id, callId, category)
    local substreet = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetname = GetStreetNameFromHashKey(substreet)

    local dist = #(GetEntityCoords(PlayerPedId()) - coords)
    local distStr = ""
    if Config.Measurement then
        distStr = string.format("%.2f", dist / 1000)
    else
        distStr = string.format("%.2f", dist / 1609.34)
    end

    local callData = {
        callId = callId,
        title = title,
        text = text,
        coords = coords,
        panic = panic,
        senderId = id,
        category = category or 'alert',
        distance = distStr,
        street = streetname,
    }

    table.insert(Calls, callData)

    -- Send to NUI for popup
    SendNUIMessage({
        type = 'newAlert',
        call = callData,
        dismissTime = Config.AlertDismissTime,
        measurement = Config.Measurement and 'km' or 'mi',
    })

    if Config.Sound then
        PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", 0)
    end
end)

RegisterNetEvent("prologue_dispatch:Client:SendVehRob")
AddEventHandler("prologue_dispatch:Client:SendVehRob", function(coords, model, plate, color, id, callId)
    local substreet = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetname = GetStreetNameFromHashKey(substreet)

    local dist = #(GetEntityCoords(PlayerPedId()) - coords)
    local distStr = ""
    if Config.Measurement then
        distStr = string.format("%.2f", dist / 1000)
    else
        distStr = string.format("%.2f", dist / 1609.34)
    end

    local callData = {
        callId = callId,
        title = LC['Vehicle_Title'],
        text = LC['Veh_Rob_01'] .. model .. " plate: " .. plate .. LC['Veh_Rob_02'] .. streetname,
        coords = coords,
        panic = false,
        senderId = id,
        category = 'theft',
        distance = distStr,
        street = streetname,
        color = color,
    }

    table.insert(Calls, callData)

    SendNUIMessage({
        type = 'newAlert',
        call = callData,
        dismissTime = Config.AlertDismissTime,
        measurement = Config.Measurement and 'km' or 'mi',
    })

    if Config.Sound then
        PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", 0)
    end
end)

-----------------------
---- Cooldown ---------
-----------------------

RegisterNetEvent('prologue_dispatch:Client:Cooldown')
AddEventHandler('prologue_dispatch:Client:Cooldown', function()
    Cooldown = true
    Wait(Config.ShootingCooldown * 1000)
    Cooldown = false
end)

-----------------------
---- NUI Callbacks ----
-----------------------

-- Respond to an alert (set waypoint)
RegisterNUICallback('respondAlert', function(data, cb)
    local callId = data.callId
    for _, call in ipairs(Calls) do
        if call.callId == callId then
            SetNewWaypoint(call.coords.x, call.coords.y)

            -- Get our callsign for the response log
            local myNumber = Config.DefaultDispatchNumber
            local myId = GetPlayerServerId(PlayerId())
            TriggerServerEvent('prologue_dispatch:Server:respondCall', callId, myNumber)
            break
        end
    end
    cb('ok')
end)

-- GPS to a past call from the dispatch log
RegisterNUICallback('gpsToCall', function(data, cb)
    if data.x and data.y then
        SetNewWaypoint(data.x + 0.0, data.y + 0.0)
    end
    cb('ok')
end)

-- Close the large dispatch panel
RegisterNUICallback('closeLarge', function(data, cb)
    SetNuiFocus(false, false)
    ShowLarg = false
    SendNUIMessage({ type = 'closeLargeDispatch' })
    cb('ok')
end)

-- Close the dispatch log
RegisterNUICallback('closeLog', function(data, cb)
    SetNuiFocus(false, false)
    ShowLog = false
    cb('ok')
end)

-- Escape key handler - always release focus
RegisterNUICallback('escapePressed', function(data, cb)
    SetNuiFocus(false, false)
    ShowLarg = false
    ShowLog = false
    cb('ok')
end)

-- Update unit data (status, patrol, number)
RegisterNUICallback('updateUserUnit', function(data, cb)
    TriggerServerEvent('prologue_dispatch:Server:updateUserUnit', GetPlayerServerId(PlayerId()), data.type, data.value)
    cb('ok')
end)

-----------------------------------
------------ Threads --------------
-----------------------------------

-- Shooting detection
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if Config.ShootingAlerts and IsPedShooting(ped) and not Cooldown then
            local coords = GetEntityCoords(ped)
            local substreet = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local streetname = GetStreetNameFromHashKey(substreet)
            local id = GetPlayerServerId(PlayerId())
            local text = LC['Shooting_Alert'] .. " " .. streetname
            local title = LC['Shotting_Title']

            for _, v in pairs(Config.Jobs) do
                TriggerServerEvent('prologue_dispatch:Server:SendAlert', v, title, text, coords, true, id, 'shooting')
            end

            ShootingBlip()
            TriggerEvent('prologue_dispatch:Client:Cooldown')
        end
        Wait(5)
    end
end)

-- Update large dispatch unit list when open
CreateThread(function()
    while true do
        if ShowLarg then
            UpdateUserData()
        end
        Wait(400)
    end
end)

-----------------------------------
------------ Functions ------------
-----------------------------------

function ShootingBlip()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 156)
    SetBlipColour(blip, 4)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 1.5)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(LC['Blip_Label'])
    EndTextCommandSetBlipName(blip)

    SetTimeout(Config.BlipDeletion * 1000, function()
        RemoveBlip(blip)
    end)
end

function FirstToUpper(str)
    return (str:gsub("^%l", string.upper))
end
