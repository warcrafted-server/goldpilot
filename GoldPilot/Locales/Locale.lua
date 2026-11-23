local _, addon = ...
addon.L = {}
local english, spanish = {}, {}
addon.LocaleStrings = { enUS = english, esES = spanish }

function addon.LocaleRegister(locale, values)
    local target = locale == "esES" and spanish or english
    for key, value in pairs(values) do target[key] = value end
end

function addon.LocaleSet(locale)
    local fallback = english
    local selected = locale == "esES" and spanish or fallback
    setmetatable(addon.L, { __index = function(_, key) return selected[key] or fallback[key] or "[" .. tostring(key) .. "]" end })
end

addon.LocaleSet(GetLocale and GetLocale() or "enUS")
