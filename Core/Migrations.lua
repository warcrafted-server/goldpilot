local _, addon = ...

addon.Migrations = { steps = { [1] = function(db) end } }

addon.Migrations.steps[2] = function(db)
    local function mergeSections(sectionName, timestamp)
        local section = db[sectionName]
        if type(section) ~= "table" then return end
        local keys = {}
        for key in pairs(section) do
            local prefix = type(key) == "string" and string.match(key, "^(.-)%-[^%-]+$")
            if prefix then
                keys[#keys + 1] = key
            end
        end
        for _, key in ipairs(keys) do
            local value = section[key]
            local prefix = string.match(key, "^(.-)%-[^%-]+$")
            if prefix then
                if section[prefix] == nil then
                    section[prefix] = value
                else
                    local target = section[prefix]
                    if sectionName == "prices" and type(value) == "table" and type(target) == "table" then
                        for itemID, observation in pairs(value) do
                            local existing = target[itemID]
                            if type(observation) == "table" and (type(existing) ~= "table" or (tonumber(observation.last and observation.last.t) or 0) > (tonumber(existing.last and existing.last.t) or 0)) then
                                target[itemID] = observation
                            end
                        end
                    elseif type(value) == "table" and (tonumber(value[timestamp]) or 0) > (tonumber(target[timestamp]) or 0) then
                        section[prefix] = value
                    end
                end
                section[key] = nil
            end
        end
    end
    mergeSections("prices", "last")
    mergeSections("houses", "lastSeen")
    mergeSections("chars", "seen")
end

addon.Migrations.steps[3] = function(db)
    local result = {}
    for houseKey, house in pairs(db.prices or {}) do
        local converted = {}
        for itemKey, value in pairs(house) do
            local itemID = addon.ItemKey.itemID(itemKey)
            if not (itemID and addon.ItemKey.isGear(itemID)) then
                local last, daily, weekly
                if type(value) == "table" then
                    last, daily, weekly = value.last, value.d or "", value.w or ""
                elseif type(value) == "string" then
                    local parts = { string.match(value, "^([^|]*)|([^|]*)|([^|]*)$") }
                    if #parts == 3 then
                        local t, min, p50, qty = string.match(parts[1], "^([^:]+):([^:]+):([^:]+):([^:]+)$")
                        if t then last, daily, weekly = { t = tonumber(t), min = tonumber(min), p50 = tonumber(p50), qty = tonumber(qty) }, parts[2], parts[3] end
                    end
                end
                if last and tonumber(last.t) and tonumber(last.min) and tonumber(last.p50) and tonumber(last.qty) then
                    converted[itemKey] = string.format("%.0f:%.0f:%.0f:%.0f|%s|%s", last.t,
                        math.max(1, math.floor(last.min)), math.max(1, math.floor(last.p50)),
                        math.max(1, math.floor(last.qty)), daily, weekly)
                end
            end
        end
        result[houseKey] = converted
    end
    db.prices = result
end

function addon.Migrations:run(db)
    local schema = tonumber(db.schema) or 0
    while schema < #self.steps do
        local step = self.steps[schema + 1]
        if type(step) ~= "function" then return false end
        local backup = {}
        for key, value in pairs(db) do backup[key] = value end
        local ok, err = pcall(step, db)
        if not ok then
            db.backup = backup
            addon.safeMode = true
            addon.Log:error("Falló la migración " .. (schema + 1) .. ": " .. tostring(err))
            return false
        end
        schema = schema + 1
        db.schema = schema
    end
    return true
end
