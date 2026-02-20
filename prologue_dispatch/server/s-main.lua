GlobalUnits = {}
CallHistory = {}
CallIdCounter = 0

-- Generate a unique call ID
function GenerateCallId()
    CallIdCounter = CallIdCounter + 1
    return CallIdCounter
end

-- Add a unit to the global list
RegisterServerEvent("prologue_dispatch:Server:addGlobalUnit")
AddEventHandler("prologue_dispatch:Server:addGlobalUnit", function(user, name, number, id)
    -- Prevent duplicates
    for _, v in ipairs(GlobalUnits) do
        if v.id == id then return end
    end

    table.insert(GlobalUnits, {
        user = user,
        id = id,
        name = name,
        number = number,
        status = 'greenSt',
        patrol = 'fa-car'
    })
end)

-- Update a unit's property (status, patrol, number)
RegisterServerEvent("prologue_dispatch:Server:updateUserUnit")
AddEventHandler("prologue_dispatch:Server:updateUserUnit", function(id, type, value)
    for _, v in pairs(GlobalUnits) do
        if v.id == id then
            if type == 'status' then
                v.status = value
            elseif type == 'patrol' then
                v.patrol = value
            elseif type == 'number' then
                v.number = value
            end
            break
        end
    end
end)

-- Remove a unit
function RemoveUnit(id)
    for k, v in ipairs(GlobalUnits) do
        if v.id == id then
            table.remove(GlobalUnits, k)
            break
        end
    end
end

-- Store a call in history
RegisterServerEvent("prologue_dispatch:Server:logCall")
AddEventHandler("prologue_dispatch:Server:logCall", function(callData)
    callData.serverTime = os.time()
    table.insert(CallHistory, 1, callData) -- newest first

    -- Cap history at 200
    if #CallHistory > 200 then
        table.remove(CallHistory)
    end
end)

-- Mark a call as responded
RegisterServerEvent("prologue_dispatch:Server:respondCall")
AddEventHandler("prologue_dispatch:Server:respondCall", function(callId, responder)
    for _, v in ipairs(CallHistory) do
        if v.callId == callId then
            v.responded = true
            v.officer = responder
            break
        end
    end
end)
