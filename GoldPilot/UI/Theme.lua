local _, addon = ...

addon.Theme = {
    colors = {
        GAME = "|cff70d070", OBS = "|cff66ccff", EXT = "|cffc586ff",
        REG = "|cffffcc66", CONF = "|cff66ffcc", EST = "|cffffaa55",
        default = "|cffcccccc",
    },
}

function addon.Theme.money(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    if addon.Compat and addon.Compat.has("GetCoinTextureString") then
        local ok, value = addon.Compat.call("GetCoinTextureString", copper)
        if ok and type(value) == "string" then return value end
    end
    -- En clientes modernos la función de monedas está en C_CurrencyInfo.
    if addon.Compat and addon.Compat.has("C_CurrencyInfo.GetCoinTextureString") then
        local ok, value = addon.Compat.call("C_CurrencyInfo.GetCoinTextureString", copper)
        if ok and type(value) == "string" then return value end
    end
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    return string.format("%dg %ds %dc", gold, silver, copper % 100)
end

function addon.Theme.age(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    if seconds < 3600 then
        return string.format(addon.L.AGE_MINUTES, math.floor(seconds / 60))
    elseif seconds < 86400 then
        return string.format(addon.L.AGE_HOURS, math.floor(seconds / 3600))
    end
    return string.format(addon.L.AGE_DAYS, math.floor(seconds / 86400))
end

function addon.Theme.badge(class)
    class = tostring(class or "")
    local color = addon.Theme.colors[class] or addon.Theme.colors.default
    return color .. "[" .. (class ~= "" and class or "?") .. "]|r"
end
