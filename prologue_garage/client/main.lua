ESX = exports['es_extended']:getSharedObject()

local peds = {}
local blips = {}
local currentGarage = nil  -- index into Config.Garages when menu is open

-----------------------------------------------------------
-- Garage Vehicle Preview System
-----------------------------------------------------------

local garageCam = nil
local previewVehicle = nil
local playerHidden = false

function StartGaragePreview(spawnCoords)
    if garageCam then return end

    local ped = cache.ped or PlayerPedId()

    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    playerHidden = true

    local headingRad = math.rad(spawnCoords.w or 0.0)
    local distance = 7.2
    local height = 0.4

    -- 45-degree front-left angle
    local angleOffset = math.rad(45)
    local camAngle = headingRad + angleOffset
    local camX = spawnCoords.x + (-math.sin(camAngle) * distance)
    local camY = spawnCoords.y + (math.cos(camAngle) * distance)
    local camZ = spawnCoords.z + height

    garageCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(garageCam, camX, camY, camZ)
    PointCamAtCoord(garageCam, spawnCoords.x, spawnCoords.y, spawnCoords.z + 0.5)
    SetCamFov(garageCam, 40.0)
    SetCamActive(garageCam, true)
    RenderScriptCams(true, true, 800, true, false)

    SetCamUseShallowDofMode(garageCam, true)
    SetCamNearDof(garageCam, 1.0)
    SetCamFarDof(garageCam, 12.0)
    SetCamDofStrength(garageCam, 0.15)
end

function ShowPreviewVehicle(modelHash, spawnCoords, plate)
    DestroyPreviewVehicle()
    if not modelHash then return end

    lib.requestModel(modelHash)

    local x, y, z, w = spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w or 0.0
    previewVehicle = CreateVehicle(modelHash, x, y, z, w, false, false)
    SetModelAsNoLongerNeeded(modelHash)

    if not previewVehicle or previewVehicle == 0 then
        print('^1[prologue_garage]^0 Failed to spawn preview vehicle')
        return
    end

    SetEntityInvincible(previewVehicle, true)
    FreezeEntityPosition(previewVehicle, true)
    SetVehicleDoorsLocked(previewVehicle, 2)
    SetVehicleOnGroundProperly(previewVehicle)
    SetEntityCollision(previewVehicle, false, false)

    if plate then
        SetVehicleNumberPlateText(previewVehicle, plate)
    end

    SetVehicleEngineOn(previewVehicle, true, true, false)
    SetVehicleLights(previewVehicle, 3)
end

function DestroyPreviewVehicle()
    if previewVehicle and DoesEntityExist(previewVehicle) then
        SetEntityAsMissionEntity(previewVehicle, true, true)
        DeleteVehicle(previewVehicle)
    end
    previewVehicle = nil
end

function StopGaragePreview(keepVehicle)
    if garageCam then
        RenderScriptCams(false, true, 800, true, false)
        DestroyCam(garageCam, false)
        garageCam = nil
    end

    if not keepVehicle then
        DestroyPreviewVehicle()
    end

    if playerHidden then
        local ped = cache.ped or PlayerPedId()
        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, false)
        FreezeEntityPosition(ped, false)
        playerHidden = false
    end
end

-----------------------------------------------------------
-- Ped Spawning (cloud_shop pattern)
-----------------------------------------------------------

local function spawnPed(coords, model)
    if not IsModelInCdimage(model) or not IsModelAPed(model) then
        print('^1[prologue_garage]^0 Invalid ped model: ' .. tostring(model))
        return nil
    end

    lib.requestModel(model)
    local ped = CreatePed(0, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
    SetModelAsNoLongerNeeded(model)

    ped = lib.waitFor(function()
        if DoesEntityExist(ped) and ped ~= 0 then return ped end
    end, '[prologue_garage] Ped spawn timed out', 5000)

    if not ped or ped == 0 then
        print('^1[prologue_garage]^0 Ped creation failed')
        return nil
    end

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)

    return ped
end

-----------------------------------------------------------
-- Blip Creation
-----------------------------------------------------------

local function createBlip(coords, blipData, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipData.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipData.scale)
    SetBlipColour(blip, blipData.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

-----------------------------------------------------------
-- Vehicle Helpers
-----------------------------------------------------------

local function getVehicleLabel(model)
    local label = GetLabelText(GetDisplayNameFromVehicleModel(model))
    if label == 'NULL' then
        label = GetDisplayNameFromVehicleModel(model)
    end
    return label
end

local function isSpawnClear(coords)
    if not Config.SpawnCheck then return true end
    return not lib.getClosestVehicle(coords.xyz, Config.SpawnCheckRadius, false)
end

-----------------------------------------------------------
-- Society Vehicle Tracking
-----------------------------------------------------------

local spawnedSociety = {} -- model name -> vehicle entity

local function isSocietyOut(modelName)
    local ent = spawnedSociety[modelName]
    if ent and DoesEntityExist(ent) then
        return true
    end
    spawnedSociety[modelName] = nil
    return false
end

-----------------------------------------------------------
-- NUI: Open Garage Menu
-----------------------------------------------------------

local garageVehicleData = {} -- plate/model -> { model = hash }

local function openGarage(garageIndex)
    local garage = Config.Garages[garageIndex]
    if not garage then return end

    currentGarage = garageIndex
    garageVehicleData = {}

    -- Fetch stored vehicles from server (here, elsewhere, impounded)
    local vehicles, elsewhereVehicles, impoundedVehicles = lib.callback.await('prologue_garage:getVehicles', false, garage.Label, garage.Type)

    -- Format personal vehicles for NUI and cache model data for preview
    local formatted = {}
    for _, v in ipairs(vehicles or {}) do
        garageVehicleData[v.plate] = {
            model = v.model,
        }

        formatted[#formatted + 1] = {
            plate = v.plate,
            name = getVehicleLabel(v.model),
            nickname = v.nickname or nil,
            fuel = v.fuelLevel or 100,
            engine = math.floor(((v.engineHealth or 1000) / 1000) * 100),
            body = math.floor(((v.bodyHealth or 1000) / 1000) * 100),
            oil = v.oilLevel or 100,
            stored = true,
        }
    end

    -- Format vehicles at other garages (for transfer)
    local elsewhereFormatted = {}
    for _, v in ipairs(elsewhereVehicles or {}) do
        elsewhereFormatted[#elsewhereFormatted + 1] = {
            plate = v.plate,
            name = getVehicleLabel(v.model),
            atGarage = v.atGarage or 'Unknown',
        }
    end

    -- Format impounded/out vehicles — check if entity exists in world
    local impoundedFormatted = {}
    local outFormatted = {}

    -- Build plate lookup from game pool
    local worldPlates = {}
    local worldVehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(worldVehicles) do
        local p = GetVehicleNumberPlateText(veh):gsub('%s+', '')
        worldPlates[p] = true
    end

    for _, v in ipairs(impoundedVehicles or {}) do
        local cleanPlate = (v.plate or ''):gsub('%s+', '')
        if worldPlates[cleanPlate] then
            -- Vehicle exists in world — it's out, not impounded
            garageVehicleData[v.plate] = { model = v.model }
            outFormatted[#outFormatted + 1] = {
                plate = v.plate,
                name = getVehicleLabel(v.model),
                fuel = v.fuelLevel or 100,
                engine = math.floor(((v.engineHealth or 1000) / 1000) * 100),
                body = math.floor(((v.bodyHealth or 1000) / 1000) * 100),
                oil = v.oilLevel or 100,
                stored = false,
            }
        else
            -- Entity gone — impounded
            impoundedFormatted[#impoundedFormatted + 1] = {
                plate = v.plate,
                name = getVehicleLabel(v.model),
            }
        end
    end

    -- Build society vehicle list if this is a job garage
    local societyFormatted = {}
    if garage.Job then
        local playerJob = ESX.GetPlayerData().job
        local jobName = playerJob and playerJob.name or ''

        -- Check if player's job matches garage job
        local hasAccess = false
        if type(garage.Job) == 'table' then
            for _, j in ipairs(garage.Job) do
                if j == jobName then hasAccess = true break end
            end
        else
            hasAccess = (garage.Job == jobName)
        end

        if hasAccess and Config.SocietyVehicles and Config.SocietyVehicles[jobName] then
            local societyConfig = Config.SocietyVehicles[jobName]
            local societyPlate = societyConfig.plate or jobName:upper()

            for _, sv in ipairs(societyConfig.vehicles or {}) do
                local modelHash = type(sv.model) == 'number' and sv.model or joaat(sv.model)
                garageVehicleData[sv.model] = {
                    model = modelHash,
                    isSociety = true,
                    plate = societyPlate,
                }

                societyFormatted[#societyFormatted + 1] = {
                    label = sv.label,
                    model = sv.model,
                    plate = societyPlate,
                    checkedOut = isSocietyOut(sv.model),
                }
            end
        end
    end

    -- Start preview: hide player, set up camera
    StartGaragePreview(garage.SpawnCoords)

    -- Spawn preview of first vehicle (personal first, then society)
    if formatted[1] and garageVehicleData[formatted[1].plate] then
        local firstData = garageVehicleData[formatted[1].plate]
        ShowPreviewVehicle(firstData.model, garage.SpawnCoords, formatted[1].plate)
    elseif societyFormatted[1] and garageVehicleData[societyFormatted[1].model] then
        local firstData = garageVehicleData[societyFormatted[1].model]
        ShowPreviewVehicle(firstData.model, garage.SpawnCoords, nil)
    end

    -- Build list of public garage labels for transfer dropdown
    local garageLabels = {}
    for _, g in ipairs(Config.Garages) do
        if not g.Job then
            garageLabels[#garageLabels + 1] = g.Label
        end
    end

    -- Open NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openGarage',
        label = garage.Label,
        vehicles = formatted,
        outVehicles = outFormatted,
        elsewhereVehicles = elsewhereFormatted,
        impoundedVehicles = impoundedFormatted,
        societyVehicles = societyFormatted,
        garageList = garageLabels,
    })

    -- ESC key handler (FiveM captures ESC before JS gets it)
    CreateThread(function()
        while currentGarage do
            DisableControlAction(0, 200, true) -- block pause menu
            if IsDisabledControlJustReleased(0, 200) then
                closeGarage()
                break
            end
            Wait(0)
        end
    end)
end

-----------------------------------------------------------
-- NUI: Close
-----------------------------------------------------------

local function closeGarage()
    SetNuiFocus(false, false)
    StopGaragePreview(false) -- destroy preview vehicle, restore player
    SendNUIMessage({ action = 'closeGarage' })
    currentGarage = nil
    garageVehicleData = {}
end

RegisterNUICallback('close', function(_, cb)
    closeGarage()
    cb({})
end)

-----------------------------------------------------------
-- NUI: Select Card (swap preview vehicle)
-----------------------------------------------------------

RegisterNUICallback('selectCard', function(data, cb)
    local garage = Config.Garages[currentGarage]
    if not garage then cb({}) return end

    local key = data.plate
    if not key then cb({}) return end

    local vehData = garageVehicleData[key]
    if vehData and vehData.model then
        local plateText = nil
        if not data.society then plateText = key end
        ShowPreviewVehicle(vehData.model, garage.SpawnCoords, plateText)
    end

    cb({})
end)

-----------------------------------------------------------
-- NUI: Take Out Vehicle
-----------------------------------------------------------

RegisterNUICallback('takeOut', function(data, cb)
    local garage = Config.Garages[currentGarage]
    if not garage then cb({ success = false }) return end

    -- Request server to validate ownership and get props
    local props = lib.callback.await('prologue_garage:takeOutVehicle', false,
        garage.Label, data.plate, garage.SpawnCoords)

    if not props or not props.model then
        ESX.ShowNotification('Failed to take out vehicle.', 'error')
        cb({ success = false })
        return
    end

    -- Destroy preview vehicle and stop camera, but restore player
    DestroyPreviewVehicle()
    StopGaragePreview(false)

    -- Close NUI immediately
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeGarage' })

    -- Spawn the real vehicle with full props
    local spawnCoords = garage.SpawnCoords
    ESX.Game.SpawnVehicle(props.model, vector3(spawnCoords.x, spawnCoords.y, spawnCoords.z), spawnCoords.w, function(vehicle)
        if not DoesEntityExist(vehicle) then
            ESX.ShowNotification('Failed to spawn vehicle.', 'error')
            cb({ success = false })
            return
        end

        ESX.Game.SetVehicleProperties(vehicle, props)
        SetVehicleOnGroundProperly(vehicle)

        -- Restore health
        if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth) end
        if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth) end

        -- Restore fuel via lc_fuel
        if props.fuelLevel then
            pcall(function() exports.lc_fuel:SetFuel(vehicle, props.fuelLevel) end)
        end

        -- Restore oil via lc_fuel
        if props.oilLevel then
            pcall(function() exports.lc_fuel:SetOil(vehicle, props.oilLevel) end)
        end

        TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
        SetVehicleEngineOn(vehicle, true, true, false)

        currentGarage = nil
        garageVehicleData = {}
        ESX.ShowNotification('Vehicle retrieved.')
        cb({ success = true })
    end)
end)

-----------------------------------------------------------
-- Society Vehicle Tracking
-- One of each model per player, tracked by entity
-----------------------------------------------------------

-----------------------------------------------------------
-- NUI: Take Out Society Vehicle
-----------------------------------------------------------

RegisterNUICallback('takeOutSociety', function(data, cb)
    local garage = Config.Garages[currentGarage]
    if not garage then cb({ success = false }) return end

    local modelName = data.model
    if not modelName then cb({ success = false }) return end

    -- Check if this model is already out
    if isSocietyOut(modelName) then
        ESX.ShowNotification('That vehicle is already checked out.', 'error')
        cb({ success = false })
        return
    end

    local vehData = garageVehicleData[modelName]
    if not vehData or not vehData.model then
        ESX.ShowNotification('Vehicle not available.', 'error')
        cb({ success = false })
        return
    end

    -- Destroy preview and restore player
    DestroyPreviewVehicle()
    StopGaragePreview(false)

    -- Close NUI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeGarage' })

    -- Spawn fresh society vehicle
    local spawnCoords = garage.SpawnCoords
    local modelHash = vehData.model

    lib.requestModel(modelHash)

    ESX.Game.SpawnVehicle(modelHash, vector3(spawnCoords.x, spawnCoords.y, spawnCoords.z), spawnCoords.w, function(vehicle)
        if not DoesEntityExist(vehicle) then
            ESX.ShowNotification('Failed to spawn society vehicle.', 'error')
            cb({ success = false })
            return
        end

        -- Full fuel and health for society vehicles
        SetVehicleOnGroundProperly(vehicle)
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleBodyHealth(vehicle, 1000.0)
        pcall(function() exports.lc_fuel:SetFuel(vehicle, 100) end)
        pcall(function() exports.lc_fuel:SetOil(vehicle, 100) end)

        SetVehicleNumberPlateText(vehicle, vehData.plate or 'SOCIETY')

        -- Track this society vehicle
        spawnedSociety[modelName] = vehicle

        TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
        SetVehicleEngineOn(vehicle, true, true, false)

        currentGarage = nil
        garageVehicleData = {}
        ESX.ShowNotification('Society vehicle deployed.')
        cb({ success = true })
    end)
end)

-----------------------------------------------------------
-- NUI: Locate Vehicle (GPS waypoint)
-----------------------------------------------------------

RegisterNUICallback('transfer', function(data, cb)
    local garage = Config.Garages[currentGarage]
    if not garage then cb({ success = false }) return end

    local plate = data.plate
    if not plate then cb({ success = false }) return end

    local success, msg = lib.callback.await('prologue_garage:transferVehicle', false, garage.Label, plate)

    if success then
        ESX.ShowNotification(msg, 'success')
        local idx = currentGarage
        closeGarage()
        Wait(300)
        openGarage(idx)
    else
        ESX.ShowNotification(msg or 'Transfer failed.', 'error')
    end

    cb({ success = success })
end)

-----------------------------------------------------------
-- NUI: Transfer to a specific garage
-----------------------------------------------------------

RegisterNUICallback('transferToGarage', function(data, cb)
    local plate = data.plate
    local targetGarage = data.garage
    if not plate or not targetGarage then cb({ success = false }) return end

    local success, msg = lib.callback.await('prologue_garage:transferVehicle', false, targetGarage, plate)

    if success then
        ESX.ShowNotification('Vehicle transferred to ' .. targetGarage, 'success')
        local idx = currentGarage
        closeGarage()
        Wait(300)
        openGarage(idx)
    else
        ESX.ShowNotification(msg or 'Transfer failed.', 'error')
    end

    cb({ success = success })
end)

-----------------------------------------------------------
-- NUI: Locate Vehicle (GPS waypoint)
-----------------------------------------------------------

RegisterNUICallback('locate', function(data, cb)
    -- Find the vehicle entity in the world by plate
    local plate = data.plate
    local found = false

    local vehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(vehicles) do
        local vehPlate = GetVehicleNumberPlateText(veh):gsub('%s+', '')
        if vehPlate == plate:gsub('%s+', '') then
            local coords = GetEntityCoords(veh)
            SetNewWaypoint(coords.x, coords.y)
            ESX.ShowNotification('Vehicle marked on GPS.')
            found = true
            break
        end
    end

    if not found then
        ESX.ShowNotification('Vehicle not found nearby.')
    end

    cb({})
end)

-----------------------------------------------------------
-- NUI: Rename Vehicle
-----------------------------------------------------------

RegisterNUICallback('rename', function(data, cb)
    if not data.plate or not data.name then cb({}) return end

    local success = lib.callback.await('prologue_garage:renameVehicle', false, data.plate, data.name)

    if success then
        ESX.ShowNotification('Vehicle renamed.')
    end

    cb({})
end)

-----------------------------------------------------------
-- Impound Lot
-----------------------------------------------------------

local isImpoundOpen = false
local currentImpound = nil

local function openImpound(impoundIndex)
    if isImpoundOpen then return end
    isImpoundOpen = true
    currentImpound = impoundIndex

    local impound = Config.Impounds[impoundIndex]
    garageVehicleData = {}

    -- Fetch impounded vehicles
    local vehicles = lib.callback.await('prologue_garage:getImpounded', false)

    local formatted = {}
    for _, v in ipairs(vehicles or {}) do
        garageVehicleData[v.plate] = {
            model = v.model,
        }

        formatted[#formatted + 1] = {
            plate = v.plate,
            name = getVehicleLabel(v.model),
            fuel = v.fuelLevel or 100,
            engine = math.floor(((v.engineHealth or 1000) / 1000) * 100),
            body = math.floor(((v.bodyHealth or 1000) / 1000) * 100),
            oil = v.oilLevel or 100,
        }
    end

    -- Start preview camera
    StartGaragePreview(impound.SpawnCoords)

    if formatted[1] and garageVehicleData[formatted[1].plate] then
        local firstData = garageVehicleData[formatted[1].plate]
        ShowPreviewVehicle(firstData.model, impound.SpawnCoords, formatted[1].plate)
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openImpound',
        label = impound.Label,
        fee = impound.Fee,
        vehicles = formatted,
    })

    -- ESC handler
    CreateThread(function()
        while isImpoundOpen do
            Wait(0)
            DisableAllControlActions(0)
            if IsDisabledControlJustPressed(0, 200) then -- ESC
                closeImpound()
            end
        end
    end)
end

local function closeImpound()
    if not isImpoundOpen then return end
    isImpoundOpen = false
    currentImpound = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeGarage' })
    StopGaragePreview()
    garageVehicleData = {}
end

RegisterNUICallback('closeImpound', function(data, cb)
    closeImpound()
    cb({})
end)

RegisterNUICallback('impoundPreview', function(data, cb)
    local impound = Config.Impounds[currentImpound]
    if not impound then cb({}) return end
    local plate = data.plate
    if plate and garageVehicleData[plate] then
        local vData = garageVehicleData[plate]
        ShowPreviewVehicle(vData.model, impound.SpawnCoords, plate)
    end
    cb({})
end)

RegisterNUICallback('retrieveImpound', function(data, cb)
    local impound = Config.Impounds[currentImpound]
    if not impound then cb({ success = false }) return end
    local plate = data.plate
    if not plate then cb({ success = false }) return end

    local props, msg = lib.callback.await('prologue_garage:retrieveImpound', false, plate, impound.Fee)

    if props then
        -- Close impound UI
        closeImpound()

        -- Spawn vehicle
        ESX.Game.SpawnVehicle(props.model, vector3(impound.SpawnCoords.x, impound.SpawnCoords.y, impound.SpawnCoords.z), impound.SpawnCoords.w, function(vehicle)
            lib.setVehicleProperties(vehicle, props)
            SetVehicleOnGroundProperly(vehicle)

            pcall(function() exports.lc_fuel:SetFuel(vehicle, props.fuelLevel or 100) end)
            pcall(function() exports.lc_fuel:SetOil(vehicle, props.oilLevel or 100) end)

            SetVehicleNumberPlateText(vehicle, plate)

            TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
            SetVehicleEngineOn(vehicle, true, true, false)

            ESX.ShowNotification(msg or 'Vehicle retrieved.', 'success')
        end)
    else
        ESX.ShowNotification(msg or 'Could not retrieve vehicle.', 'error')
    end

    cb({ success = props ~= nil })
end)

-----------------------------------------------------------
-- Find nearest garage (with optional job check)
-----------------------------------------------------------
local function findNearestGarage()
    local playerCoords = GetEntityCoords(cache.ped)
    local playerJob = ESX.GetPlayerData().job
    local jobName = playerJob and playerJob.name or ''
    local nearest = nil
    local nearestDist = math.huge

    for i, garage in ipairs(Config.Garages) do
        -- Job check
        if garage.Job then
            local hasAccess = false
            if type(garage.Job) == 'table' then
                for _, j in ipairs(garage.Job) do
                    if j == jobName then hasAccess = true break end
                end
            else
                hasAccess = (garage.Job == jobName)
            end
            if not hasAccess then goto continue end
        end

        local gCoords = vector3(garage.PedCoords.x, garage.PedCoords.y, garage.PedCoords.z)
        local dist = #(playerCoords - gCoords)
        if dist < nearestDist then
            nearestDist = dist
            nearest = i
        end

        ::continue::
    end

    return nearest, nearestDist
end

-----------------------------------------------------------
-- Store Vehicle (works from ped target or vehicle target)
-----------------------------------------------------------

local function storeVehicle(garageIndex, targetVehicle)
    local garage = Config.Garages[garageIndex]
    if not garage then return end

    -- Use provided vehicle, or find one
    local vehicle = targetVehicle
    if not vehicle or vehicle == 0 then
        vehicle = GetVehiclePedIsIn(cache.ped, false)
    end
    if not vehicle or vehicle == 0 then
        vehicle = GetVehiclePedIsIn(cache.ped, true)
    end
    if not vehicle or vehicle == 0 then
        vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 10.0, false)
    end

    if not vehicle or vehicle == 0 then
        ESX.ShowNotification('No vehicle nearby to store.')
        return
    end

    local props = lib.getVehicleProperties(vehicle)
    if not props then
        ESX.ShowNotification('Could not read vehicle data.')
        return
    end

    -- Exit vehicle if inside it
    if GetVehiclePedIsIn(cache.ped, false) == vehicle then
        TaskLeaveVehicle(cache.ped, vehicle, 0)
        Wait(1500)
    end

    props.plate = props.plate:gsub('%s+', '')
    props.engineHealth = GetVehicleEngineHealth(vehicle)
    props.bodyHealth = GetVehicleBodyHealth(vehicle)

    -- Get fuel from lc_fuel
    local ok, fuel = pcall(function() return exports.lc_fuel:GetFuel(vehicle) end)
    props.fuelLevel = (ok and fuel) and fuel or (GetVehicleFuelLevel(vehicle) or 100)

    -- Get oil from lc_fuel
    local okOil, oil = pcall(function() return exports.lc_fuel:GetOil(vehicle) end)
    props.oilLevel = (okOil and oil) and oil or 100

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    local success = lib.callback.await('prologue_garage:storeVehicle', false,
        garage.Label, props, netId)

    if success then
        -- Vehicle deleted server-side, but also clean up client
        if DoesEntityExist(vehicle) then
            local attempt = 0
            while DoesEntityExist(vehicle) and attempt < 50 do
                SetEntityAsMissionEntity(vehicle, true, true)
                DeleteVehicle(vehicle)
                Wait(50)
                attempt = attempt + 1
            end
        end
        ESX.ShowNotification('Vehicle stored at ' .. garage.Label .. '.')
    else
        ESX.ShowNotification("You don't own this vehicle.", 'error')
    end
end

-----------------------------------------------------------
-- Initialize: Spawn Peds, Blips, ox_target
-----------------------------------------------------------

CreateThread(function()
    -- Wait for player to load
    while not ESX.GetPlayerData().job do
        Wait(100)
    end

    print('^3[prologue_garage]^0 Setting up ' .. #Config.Garages .. ' garages...')

    for i, garage in ipairs(Config.Garages) do
        -- Check job access for blips
        local playerJob = ESX.GetPlayerData().job

        -- Spawn ped
        local ped = spawnPed(garage.PedCoords, garage.PedModel or Config.PedModel)
        if ped then
            peds[#peds + 1] = ped
            print('^2[prologue_garage]^0 Ped spawned: "' .. garage.Label .. '"')

            -- ox_target on ped
            local garageIndex = i
            exports.ox_target:addLocalEntity(ped, {
                {
                    label = 'Open Garage',
                    icon = 'fas fa-warehouse',
                    distance = 3.5,
                    canInteract = function()
                        -- Job check
                        local g = Config.Garages[garageIndex]
                        if g.Job then
                            local pj = ESX.GetPlayerData().job
                            local jn = pj and pj.name or ''
                            if type(g.Job) == 'table' then
                                local found = false
                                for _, j in ipairs(g.Job) do
                                    if j == jn then found = true break end
                                end
                                if not found then return false end
                            else
                                if g.Job ~= jn then return false end
                            end
                        end
                        return true
                    end,
                    onSelect = function()
                        openGarage(garageIndex)
                    end,
                },
                {
                    label = 'Store Vehicle',
                    icon = 'fas fa-square-parking',
                    distance = 8.0,
                    canInteract = function()
                        -- Job check
                        local g = Config.Garages[garageIndex]
                        if g.Job then
                            local pj = ESX.GetPlayerData().job
                            local jn = pj and pj.name or ''
                            if type(g.Job) == 'table' then
                                local found = false
                                for _, j in ipairs(g.Job) do
                                    if j == jn then found = true break end
                                end
                                if not found then return false end
                            else
                                if g.Job ~= jn then return false end
                            end
                        end
                        -- In a vehicle or near one
                        local inVeh = GetVehiclePedIsIn(cache.ped, false)
                        if inVeh and inVeh ~= 0 then return true end
                        local closest = lib.getClosestVehicle(GetEntityCoords(cache.ped), 10.0, false)
                        return closest and closest ~= 0
                    end,
                    onSelect = function()
                        storeVehicle(garageIndex)
                    end,
                },
            })
        else
            print('^1[prologue_garage]^0 FAILED to spawn ped: "' .. garage.Label .. '"')
        end

        -- Blip
        if garage.Blip then
            local blipData = Config.Blips[garage.Type]
            if blipData then
                local blip = createBlip(garage.PedCoords, blipData, garage.Label)
                blips[#blips + 1] = blip
            end
        end
    end

    -- Global vehicle third-eye: "Store Vehicle" on any vehicle near a garage
    exports.ox_target:addGlobalVehicle({
        {
            label = 'Store Vehicle',
            icon = 'fas fa-square-parking',
            distance = 3.0,
            canInteract = function(entity, distance, coords, name, bone)
                -- Must be near a garage
                local idx, dist = findNearestGarage()
                if not idx or dist > (Config.StoreDistance or 50.0) then return false end
                return true
            end,
            onSelect = function(data)
                local idx = findNearestGarage()
                if idx then
                    storeVehicle(idx, data.entity)
                end
            end,
        },
        {
            label = 'Impound Vehicle',
            icon = 'fas fa-truck-ramp-box',
            distance = 3.0,
            canInteract = function(entity)
                local pj = ESX.GetPlayerData().job
                if not pj or pj.name ~= 'mechanic' then return false end
                -- Don't show on society vehicles (use Return instead)
                for _, ent in pairs(spawnedSociety) do
                    if ent == entity then return false end
                end
                return true
            end,
            onSelect = function(data)
                local vehicle = data.entity
                if not vehicle or not DoesEntityExist(vehicle) then return end

                -- Delete any vehicles attached to this one (flatbed cargo)
                local pool = GetGamePool('CVehicle')
                for _, v in ipairs(pool) do
                    if v ~= vehicle and IsEntityAttachedToEntity(v, vehicle) then
                        SetEntityAsMissionEntity(v, true, true)
                        DeleteVehicle(v)
                    end
                end

                -- Exit if inside
                if GetVehiclePedIsIn(cache.ped, false) == vehicle then
                    TaskLeaveVehicle(cache.ped, vehicle, 0)
                    Wait(1500)
                end

                -- Delete the vehicle
                SetEntityAsMissionEntity(vehicle, true, true)
                DeleteVehicle(vehicle)
                ESX.ShowNotification('Vehicle impounded.')
            end,
        },
        {
            label = 'Return Society Vehicle',
            icon = 'fas fa-rotate-left',
            distance = 3.0,
            canInteract = function(entity)
                local pj = ESX.GetPlayerData().job
                if not pj then return false end
                -- Check if this entity is a tracked society vehicle
                for model, ent in pairs(spawnedSociety) do
                    if ent == entity then return true end
                end
                return false
            end,
            onSelect = function(data)
                local vehicle = data.entity
                if not vehicle or not DoesEntityExist(vehicle) then return end

                -- Delete any vehicles attached (flatbed cargo)
                local pool = GetGamePool('CVehicle')
                for _, v in ipairs(pool) do
                    if v ~= vehicle and IsEntityAttachedToEntity(v, vehicle) then
                        SetEntityAsMissionEntity(v, true, true)
                        DeleteVehicle(v)
                    end
                end

                -- Exit if inside
                if GetVehiclePedIsIn(cache.ped, false) == vehicle then
                    TaskLeaveVehicle(cache.ped, vehicle, 0)
                    Wait(1500)
                end

                -- Clear tracking
                for model, ent in pairs(spawnedSociety) do
                    if ent == vehicle then
                        spawnedSociety[model] = nil
                        break
                    end
                end

                -- Delete society vehicle
                SetEntityAsMissionEntity(vehicle, true, true)
                DeleteVehicle(vehicle)
                ESX.ShowNotification('Society vehicle returned.')
            end,
        },
    })

    -- Impound lots setup
    if Config.Impounds then
        for idx, imp in ipairs(Config.Impounds) do
            local impPed = spawnPed(imp.PedCoords, Config.PedModel)
            if impPed then
                peds[#peds + 1] = impPed
                print('^2[prologue_garage]^0 Impound ped spawned: "' .. imp.Label .. '"')

                local impoundIndex = idx
                exports.ox_target:addLocalEntity(impPed, {
                    {
                        label = 'Open Impound',
                        icon = 'fas fa-car-burst',
                        distance = 3.5,
                        onSelect = function()
                            openImpound(impoundIndex)
                        end,
                    },
                })
            end

            if imp.Blip then
                local blipData = Config.Blips.impound
                if blipData then
                    local blip = createBlip(imp.PedCoords, blipData, imp.Label)
                    blips[#blips + 1] = blip
                end
            end
        end
    end

    print('^2[prologue_garage]^0 Garage system ready (' .. #peds .. ' peds)')
end)

-----------------------------------------------------------
-- Cleanup on resource stop
-----------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) then
            exports.ox_target:removeLocalEntity(ped)
            DeletePed(ped)
        end
    end

    pcall(function() exports.ox_target:removeGlobalVehicle({'Store Vehicle'}) end)

    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    if currentGarage then
        closeGarage()
    end

    StopGaragePreview(false)
end)
