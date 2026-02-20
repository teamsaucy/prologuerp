local ESX = exports["es_extended"]:getSharedObject()

-----------------------
---- ESX Events -------
-----------------------

RegisterNetEvent("esx:playerLoaded")
AddEventHandler("esx:playerLoaded", function(xPlayer)
    ESX.PlayerData = xPlayer

    if ESX.PlayerData.job.name == Config.DispatcherJob then
        local user = GetPlayerName(PlayerId())
        local name = FirstToUpper(ESX.PlayerData.firstName) .. ' ' .. FirstToUpper(ESX.PlayerData.lastName)
        local number = Config.DefaultDispatchNumber
        TriggerServerEvent('prologue_dispatch:Server:addGlobalUnit', user, name, number, GetPlayerServerId(PlayerId()))
    end
end)

RegisterNetEvent("esx:setJob")
AddEventHandler("esx:setJob", function(job)
    ESX.PlayerData.job = job

    -- Reset alerts on job change
    Calls = {}
    SendNUIMessage({ type = 'clearAll' })
    Show = false
end)

-----------------------------------
--- Update Large Dispatch Data ----
-----------------------------------

UpdateUserData = function()
    ESX.TriggerServerCallback('prologue_dispatch:getGlobalUnits', function(units)
        SendNUIMessage({
            type = 'updateUnits',
            units = units,
        })
    end)
end

-----------------------------------
------------ Commands -------------
-----------------------------------

-- /dispatch - toggle dispatch on/off
RegisterCommand('dispatch', function()
    for _, v in pairs(Config.Jobs) do
        if ESX.PlayerData.job.name == v then
            Show = not Show
            SendNUIMessage({
                type = 'toggleDispatch',
                active = Show,
            })
            return
        end
    end
end, false)

-- /panic - panic button
RegisterCommand('panic', function()
    for _, v in pairs(Config.Jobs) do
        if ESX.PlayerData.job.name == v and Config.AllowedJobs[v].panic then
            local name = ESX.PlayerData.firstName
            local surname = ESX.PlayerData.lastName
            local text = LC['Panic_01'] .. name .. " " .. surname .. LC['Panic_02']
            local coords = GetEntityCoords(PlayerPedId())
            local title = LC['Panic_Title']
            local id = GetPlayerServerId(PlayerId())

            ESX.ShowNotification(LC['Panic_Button'])
            TriggerServerEvent('prologue_dispatch:Server:SendAlert', v, title, text, coords, true, id, 'panic')
        end
    end
end, false)

-- /cls - clear local alerts
RegisterCommand('cls', function()
    for _, v in pairs(Config.Jobs) do
        if ESX.PlayerData.job.name == v then
            Calls = {}
            SendNUIMessage({ type = 'clearAll' })
            ESX.ShowNotification(LC['Clear_Alerts'])
            return
        end
    end
end, false)

-- /vehrob - vehicle theft report
RegisterCommand('vehrob', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
        local plate = GetVehicleNumberPlateText(vehicle)
        local r, g, b = GetVehicleColor(vehicle)
        local color = r .. ', ' .. g .. ', ' .. b
        local coords = GetEntityCoords(ped)
        local id = GetPlayerServerId(PlayerId())

        ESX.ShowNotification(LC['Alert_Sent'])
        TriggerServerEvent("prologue_dispatch:Server:SendVehRob", 'police', coords, model, plate, color, id)
    else
        ESX.ShowNotification(LC['Must_Vehicle'])
    end
end, false)

-- Alert commands per job
for _, v in pairs(Config.Jobs) do
    RegisterCommand(Config.AllowedJobs[v].command, function(source, args)
        local job = v
        local text = table.concat(args, " ")
        local coords = GetEntityCoords(PlayerPedId())
        local id = GetPlayerServerId(PlayerId())
        local title = LC['Alert_Title']

        ESX.ShowNotification(LC['Alert_Sent'])
        TriggerServerEvent('prologue_dispatch:Server:SendAlert', job, title, text, coords, false, id, 'alert')
    end, false)
end

-----------------------------------
------ Keybinds (Changeable) ------
-----------------------------------

-- E - Respond to latest alert
RegisterKeyMapping('dispatchRespond', 'Dispatch: Respond to alert', 'keyboard', 'E')
RegisterCommand('dispatchRespond', function()
    if Show and #Calls > 0 then
        local latestCall = Calls[#Calls]
        SetNewWaypoint(latestCall.coords.x, latestCall.coords.y)
        SendNUIMessage({ type = 'respondLatest' })

        TriggerServerEvent('prologue_dispatch:Server:respondCall', latestCall.callId, Config.DefaultDispatchNumber)

        -- Flash confirmation
        PlaySoundFrontend(-1, "WAYPOINT_SET", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0)
    end
end, false)

-- K - Open/close dispatch log
RegisterKeyMapping('dispatchLog', 'Dispatch: Open call log', 'keyboard', 'K')
RegisterCommand('dispatchLog', function()
    for _, v in pairs(Config.Jobs) do
        if ESX.PlayerData.job.name == v then
            if ShowLog then
                -- Close log
                SetNuiFocus(false, false)
                ShowLog = false
                SendNUIMessage({ type = 'toggleLog', open = false })
            else
                -- Open log, fetch history from server
                ESX.TriggerServerCallback('prologue_dispatch:getCallHistory', function(history)
                    ShowLog = true
                    SetNuiFocus(true, true)
                    SendNUIMessage({
                        type = 'toggleLog',
                        open = true,
                        history = history,
                        localCalls = Calls,
                    })
                end)
            end
            return
        end
    end
end, false)

-- O - Open/close large dispatch (unit management)
RegisterKeyMapping('dispatchLarge', 'Dispatch: Unit management panel', 'keyboard', 'O')
RegisterCommand('dispatchLarge', function()
    if ESX.PlayerData.job.name == Config.DispatcherJob then
        if ShowLarg then
            -- Force close - always release focus first
            SetNuiFocus(false, false)
            ShowLarg = false
            SendNUIMessage({ type = 'closeLargeDispatch' })
        else
            ESX.TriggerServerCallback('prologue_dispatch:getGlobalUnits', function(units)
                ShowLarg = true
                SetNuiFocus(true, true)
                SendNUIMessage({
                    type = 'openLargeDispatch',
                    id = GetPlayerServerId(PlayerId()),
                    units = units,
                })
            end)
        end
    end
end, false)

-----------------------------------
------- Chat Suggestions ----------
-----------------------------------

TriggerEvent("chat:addSuggestion", "/dispatch", "Toggle dispatch on/off")
TriggerEvent("chat:addSuggestion", "/panic", "Activate panic button")
TriggerEvent("chat:addSuggestion", "/cls", "Clear all alerts")
TriggerEvent("chat:addSuggestion", "/vehrob", "Report vehicle theft")

for _, v in pairs(Config.Jobs) do
    TriggerEvent("chat:addSuggestion", "/" .. Config.AllowedJobs[v].command, Config.AllowedJobs[v].descriptcommand, {
        { name = "alert", help = "Describe the alert" }
    })
end

-----------------------------------
------ Resource Start Sync --------
-----------------------------------

AddEventHandler("onResourceStart", function(resource)
    if resource == GetCurrentResourceName() then
        Wait(2000)
        Calls = {}
        SendNUIMessage({ type = 'clearAll' })

        if ESX.PlayerData and ESX.PlayerData.job then
            if ESX.PlayerData.job.name == Config.DispatcherJob then
                local user = GetPlayerName(PlayerId())
                local name = FirstToUpper(ESX.PlayerData.firstName) .. ' ' .. FirstToUpper(ESX.PlayerData.lastName)
                local number = Config.DefaultDispatchNumber
                TriggerServerEvent('prologue_dispatch:Server:addGlobalUnit', user, name, number, GetPlayerServerId(PlayerId()))
            end
        end
    end
end)
