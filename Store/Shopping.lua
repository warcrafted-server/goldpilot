local _, addon = ...

local Shopping = {}
addon.Shopping = Shopping

local function validID(value)
    local id = tonumber(value)
    if not id or id <= 0 or id ~= math.floor(id) then return nil end
    return id
end

local function validMax(value)
    local amount = tonumber(value)
    if not amount or amount <= 0 or amount ~= math.floor(amount) then return nil end
    return amount
end

local function ensure(db)
    if type(db) ~= "table" then return nil end
    if type(db.shopping) ~= "table" then db.shopping = {} end
    return db.shopping
end

function Shopping.add(db, itemID, max)
    local id, amount, list = validID(itemID), validMax(max), ensure(db)
    if not id or not amount or not list then return false end
    list[id] = { itemID = id, max = amount }
    return true
end

function Shopping.remove(db, itemID)
    local id, list = validID(itemID), ensure(db)
    if not id or not list or not list[id] then return false end
    list[id] = nil
    return true
end

function Shopping.get(db, itemID)
    local id, list = validID(itemID), type(db) == "table" and db.shopping or nil
    local entry = id and type(list) == "table" and list[id]
    if type(entry) ~= "table" then return nil end
    local amount = validMax(entry.max)
    if not amount then return nil end
    return { itemID = id, max = amount }
end

function Shopping.list(db)
    local result, list = {}, type(db) == "table" and db.shopping or nil
    for id, entry in pairs(type(list) == "table" and list or {}) do
        local valid = Shopping.get(db, id)
        if valid then result[#result + 1] = valid end
    end
    table.sort(result, function(a, b) return a.itemID < b.itemID end)
    return result
end

function Shopping.evaluate(entry, observation, now, maxAge)
    local amount = type(entry) == "table" and validMax(entry.max) or nil
    local minimum = type(observation) == "table" and tonumber(observation.min) or nil
    local stamp = type(observation) == "table" and tonumber(observation.t) or nil
    maxAge = tonumber(maxAge) or 3600
    if not amount or not minimum or minimum <= 0 or not stamp or not tonumber(now) or tonumber(now) - stamp > maxAge or stamp > tonumber(now) then
        return { state = "unknown" }
    end
    return { state = minimum <= amount and "buy" or "wait", price = minimum }
end

return Shopping
