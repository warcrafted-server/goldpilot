local _, addon = ...

addon.Migrations = { steps = { [1] = function(db) end } }

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
