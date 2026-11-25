local _, addon = ...

addon.Modules = { registered = {} }

function addon.Modules:register(name, module)
    module.name = name
    self.registered[#self.registered + 1] = module
end

function addon.Modules:enableAll()
    for _, module in ipairs(self.registered) do
        local missing
        for _, capability in ipairs(module.requires or {}) do
            if not addon.Compat.has(capability) then missing = capability; break end
        end
        if missing then
            module.enabled = false
            addon.Log:warning("Módulo " .. module.name .. " desactivado; falta " .. missing)
        else
            local ok, err = true, nil
            if module.onEnable then ok, err = pcall(module.onEnable, module) end
            module.enabled = ok
            if not ok then addon.Log:error("Módulo " .. module.name .. ": " .. tostring(err)) end
        end
    end
end
