local _, addon = ...

addon.Compat = {}

function addon.Compat.has(path)
    local value = _G
    for part in string.gmatch(path, "[^%.]+") do
        if type(value) ~= "table" then return false end
        value = value[part]
        if value == nil then return false end
    end
    return type(value) == "function" or type(value) == "table"
end

function addon.Compat.call(path, ...)
    local value = _G
    for part in string.gmatch(path, "[^%.]+") do
        if type(value) ~= "table" then return false, "capacidad ausente: " .. path end
        value = value[part]
        if value == nil then return false, "capacidad ausente: " .. path end
    end
    if type(value) ~= "function" then return false, "no es una función: " .. path end
    return pcall(value, ...)
end
