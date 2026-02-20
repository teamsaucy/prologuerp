ESX = exports['es_extended']:getSharedObject()

local TRANSFER_FEE = 50

-----------------------------------------------------------
-- Helper: fetch pc-mechanic oil for a list of plates
-----------------------------------------------------------
local function getMechanicOil(plates)
    local mechanicData = {}
    if #plates == 0 then return mechanicData end

    local placeholders = string.rep('?,', #plates):sub(1, -2)
    local records = MySQL.query.await(
        'SELECT vehicle_plate, vehicle_data FROM pc_mechanic_vehicle_records WHERE vehicle_plate IN (' .. placeholders .. ')',
        plates
    )
    if records then
        for _, r in ipairs(records) do
            local data = json.decode(r.vehicle_data)
            if data then
                local oil = data.engineOil
                if type(oil) == 'number' then
                    mechanicData[r.vehicle_plate] = oil
                elseif type(oil) == 'table' and oil.durability then
                    mechanicData[r.vehicle_plate] = oil.durability
                end
            end
        end
    end
    return mechanicData
end

-----------------------------------------------------------
-- Helper: format vehicle row into NUI-ready table
-----------------------------------------------------------
local function formatVehicle(v, oilLookup)
    local props = json.decode(v.vehicle)
    if not props or not props.model then return nil end

    local oilLevel = oilLookup[v.plate] or props.oilLevel or 100

    return {
        plate    = v.plate,
        props    = props,
        model    = props.model,
        nickname = v.nickname or nil,
        fuelLevel     = props.fuelLevel or 100,
        engineHealth  = props.engineHealth or 1000.0,
        bodyHealth    = props.bodyHealth or 1000.0,
        oilLevel      = oilLevel,
        parking       = v.parking or nil,
    }
end

-----------------------------------------------------------
-- Get vehicles for a garage (here + elsewhere + impounded)
-----------------------------------------------------------
lib.callback.register('prologue_garage:getVehicles', function(source, garageLabel, vehicleType)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {}, {}, {} end

    local identifier = xPlayer.identifier
    local parkingKey = 'garage_' .. garageLabel

    -- ALL vehicles for this owner (stored and not stored)
    local vehicles = MySQL.query.await([[
        SELECT plate, vehicle, parking, stored FROM owned_vehicles 
        WHERE owner = ?
    ]], { identifier })

    if not vehicles then return {}, {}, {} end

    -- Batch oil lookup
    local plates = {}
    for _, v in ipairs(vehicles) do plates[#plates + 1] = v.plate end
    local oilLookup = getMechanicOil(plates)

    local here = {}
    local elsewhere = {}
    local impounded = {}

    for _, v in ipairs(vehicles) do
        local formatted = formatVehicle(v, oilLookup)
        if formatted then
            if v.stored == 1 then
                local p = v.parking
                if not p or p == '' or p == 'NULL' or p == parkingKey then
                    here[#here + 1] = formatted
                else
                    local atGarage = p:gsub('^garage_', '')
                    formatted.atGarage = atGarage ~= '' and atGarage or 'Unknown'
                    elsewhere[#elsewhere + 1] = formatted
                end
            else
                -- stored = 0: vehicle is out in the world or impounded (/dv'd)
                impounded[#impounded + 1] = formatted
            end
        end
    end

    return here, elsewhere, impounded
end)

-----------------------------------------------------------
-- Get impounded vehicles (for the impound lot)
-----------------------------------------------------------
lib.callback.register('prologue_garage:getImpounded', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    local identifier = xPlayer.identifier

    local vehicles = MySQL.query.await([[
        SELECT plate, vehicle FROM owned_vehicles 
        WHERE owner = ? AND stored = 0
    ]], { identifier })

    if not vehicles then return {} end

    local plates = {}
    for _, v in ipairs(vehicles) do plates[#plates + 1] = v.plate end
    local oilLookup = getMechanicOil(plates)

    local result = {}
    for _, v in ipairs(vehicles) do
        local formatted = formatVehicle(v, oilLookup)
        if formatted then
            result[#result + 1] = formatted
        end
    end

    return result
end)

-----------------------------------------------------------
-- Retrieve from impound (pay fee)
-----------------------------------------------------------
lib.callback.register('prologue_garage:retrieveImpound', function(source, plate, fee)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil, 'Player not found' end

    local identifier = xPlayer.identifier

    local vehicle = MySQL.query.await([[
        SELECT vehicle FROM owned_vehicles 
        WHERE plate = ? AND owner = ? AND stored = 0
    ]], { plate, identifier })

    if not vehicle or not vehicle[1] then
        return nil, 'Vehicle not found'
    end

    -- Check funds
    local bankBalance = xPlayer.getAccount('bank').money
    if bankBalance < fee then
        return nil, 'Insufficient funds ($' .. fee .. ' required)'
    end

    -- Charge fee
    xPlayer.removeAccountMoney('bank', fee, 'Impound retrieval fee')

    local props = json.decode(vehicle[1].vehicle)
    if not props or not props.model then return nil, 'Invalid vehicle data' end

    -- Mark as taken out (will be stored = 0 until parked again)
    -- Don't change stored since it's already 0, just clear parking
    MySQL.update.await('UPDATE owned_vehicles SET parking = NULL WHERE plate = ?', { plate })

    return props, 'Vehicle retrieved for $' .. fee
end)

-----------------------------------------------------------
-- Store (deposit) vehicle into garage
-----------------------------------------------------------
lib.callback.register('prologue_garage:storeVehicle', function(source, garageLabel, props, netId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    local identifier = xPlayer.identifier
    local plate = props.plate

    local owned = MySQL.query.await('SELECT owner FROM owned_vehicles WHERE plate = ?', { plate })
    if not owned or not owned[1] or owned[1].owner ~= identifier then
        return false
    end

    MySQL.update.await([[
        UPDATE owned_vehicles SET stored = 1, parking = ?, vehicle = ? WHERE plate = ?
    ]], { 'garage_' .. garageLabel, json.encode(props), plate })

    if netId then
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    return true
end)

-----------------------------------------------------------
-- Take out vehicle from garage (must be parked HERE)
-----------------------------------------------------------
lib.callback.register('prologue_garage:takeOutVehicle', function(source, garageLabel, plate, spawnCoords)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end

    local identifier = xPlayer.identifier
    local parkingKey = 'garage_' .. garageLabel

    -- Also allow NULL parking (legacy vehicles)
    local vehicle = MySQL.query.await([[
        SELECT vehicle, parking FROM owned_vehicles 
        WHERE plate = ? AND owner = ? AND stored = 1
    ]], { plate, identifier })

    if not vehicle or not vehicle[1] then return nil end

    local p = vehicle[1].parking
    -- Must be at this garage or have NULL parking (legacy)
    if p and p ~= '' and p ~= 'NULL' and p ~= parkingKey then
        return nil
    end

    local props = json.decode(vehicle[1].vehicle)
    if not props or not props.model then return nil end

    MySQL.update.await('UPDATE owned_vehicles SET stored = 0, parking = NULL WHERE plate = ?', { plate })

    return props
end)

-----------------------------------------------------------
-- Transfer vehicle to current garage ($50 fee)
-----------------------------------------------------------
lib.callback.register('prologue_garage:transferVehicle', function(source, garageLabel, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, 'Player not found' end

    local identifier = xPlayer.identifier

    local vehicle = MySQL.query.await([[
        SELECT parking FROM owned_vehicles 
        WHERE plate = ? AND owner = ? AND stored = 1
    ]], { plate, identifier })

    if not vehicle or not vehicle[1] then
        return false, 'Vehicle not found'
    end

    local parkingKey = 'garage_' .. garageLabel

    if vehicle[1].parking == parkingKey then
        return false, 'Vehicle is already at this garage'
    end

    local bankBalance = xPlayer.getAccount('bank').money
    if bankBalance < TRANSFER_FEE then
        return false, 'Insufficient funds ($' .. TRANSFER_FEE .. ' required)'
    end

    xPlayer.removeAccountMoney('bank', TRANSFER_FEE, 'Vehicle transfer fee')

    MySQL.update.await('UPDATE owned_vehicles SET parking = ? WHERE plate = ?', { parkingKey, plate })

    return true, 'Vehicle transferred for $' .. TRANSFER_FEE
end)

-----------------------------------------------------------
-- Get vehicles that are outside (for "Locate" button)
-----------------------------------------------------------
lib.callback.register('prologue_garage:getOutsideVehicles', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    local vehicles = MySQL.query.await([[
        SELECT plate FROM owned_vehicles WHERE owner = ? AND stored = 0
    ]], { xPlayer.identifier })

    return vehicles or {}
end)

-----------------------------------------------------------
-- Rename vehicle (custom display name)
-----------------------------------------------------------
lib.callback.register('prologue_garage:renameVehicle', function(source, plate, nickname)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    local identifier = xPlayer.identifier

    local vehicle = MySQL.query.await('SELECT owner FROM owned_vehicles WHERE plate = ? AND owner = ?', { plate, identifier })
    if not vehicle or not vehicle[1] then return false end

    if nickname and nickname:gsub('%s+', '') == '' then nickname = nil end

    pcall(function()
        MySQL.update.await('UPDATE owned_vehicles SET nickname = ? WHERE plate = ?', { nickname, plate })
    end)

    return true
end)

print('^2[prologue_garage]^0 Server loaded (transfer: $' .. TRANSFER_FEE .. ')')
