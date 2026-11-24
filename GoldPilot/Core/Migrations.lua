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
