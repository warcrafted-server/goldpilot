local _, addon = ...

-- Cada ajuste se define una sola vez; de aquí salen la pestaña Ajustes, /gpilot set y sus valores por defecto.
local Settings = { definitions = {}, byKey = {}, sectionList = {}, sectionOrder = {} }
addon.Settings = Settings

local function saved()
    return GoldPilotDB and GoldPilotDB.settings
end

local function readNested(root, key)
    local current = root
    for part in string.gmatch(key, "[^%.]+") do
        if type(current) ~= "table" then return nil end
        current = current[part]
    end
    return current
end

local function writeNested(root, key, value)
    local parts = {}
    for part in string.gmatch(key, "[^%.]+") do parts[#parts + 1] = part end
    if #parts == 0 then return false end
    local current = root
    for index = 1, #parts - 1 do
        local part = parts[index]
        if type(current[part]) ~= "table" then current[part] = {} end
        current = current[part]
    end
    current[parts[#parts]] = value
    return true
end

local function minimapSettings()
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.settings = GoldPilotDB.settings or {}
    GoldPilotDB.settings.minimap = GoldPilotDB.settings.minimap or {}
    return GoldPilotDB.settings.minimap
end

function Settings.define(definition)
    if type(definition) ~= "table" or type(definition.key) ~= "string" or definition.key == "" then return nil end
    if definition.type ~= "toggle" then return nil end
    if Settings.byKey[definition.key] then return Settings.byKey[definition.key] end
    local section = definition.section or "general"
    local entry = {
        key = definition.key,
        type = definition.type,
        default = definition.default == true,
        section = section,
        label = definition.label or definition.key,
        order = tonumber(definition.order) or 0,
        get = definition.get,
        set = definition.set,
        apply = definition.apply,
        index = #Settings.definitions + 1,
    }
    Settings.definitions[#Settings.definitions + 1] = entry
    Settings.byKey[entry.key] = entry
    if not Settings.sectionList[section] then
        Settings.sectionList[section] = true
        Settings.sectionOrder[#Settings.sectionOrder + 1] = section
    end
    return entry
end

function Settings.get(key)
    local definition = Settings.byKey[key]
    if not definition then return nil end
    if definition.get then return definition.get() end
    local root = saved()
    local value = root and readNested(root, key)
    if value == nil then return definition.default end
    return value
end

function Settings.set(key, value)
    local definition = Settings.byKey[key]
    if not definition then return false, "unknown" end
    if definition.type == "toggle" and type(value) ~= "boolean" then return false, "type" end
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.settings = GoldPilotDB.settings or {}
    if definition.set then
        definition.set(value)
    elseif not writeNested(GoldPilotDB.settings, key, value) then
        return false, "key"
    end
    if definition.apply then
        local ok, err = pcall(definition.apply, value)
        if not ok then addon.Log:error("ajuste " .. key .. ": " .. tostring(err)) end
    end
    addon.Events:send("GOLDPILOT_SETTING_CHANGED", key, value)
    return true
end

function Settings.list(section)
    local result = {}
    for _, definition in ipairs(Settings.definitions) do
        if section == nil or definition.section == section then result[#result + 1] = definition end
    end
    table.sort(result, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.index < b.index
    end)
    return result
end

function Settings.sections()
    local result = {}
    for index, section in ipairs(Settings.sectionOrder) do result[index] = section end
    return result
end

Settings.define{
    key = "minimap", type = "toggle", default = true, section = "general", label = "SETTING_MINIMAP", order = 1,
    -- Se guarda al revés por compatibilidad con el botón del minimapa.
    get = function()
        local root = saved()
        local minimap = type(root) == "table" and root.minimap
        return not (type(minimap) == "table" and minimap.hidden == true)
    end,
    set = function(value) minimapSettings().hidden = not value end,
    apply = function(value)
        if addon.Minimap and addon.Minimap.setVisible then addon.Minimap:setVisible(value) end
    end,
}

Settings.define{
    key = "tooltip", type = "toggle", default = true, section = "general", label = "SETTING_TOOLTIP", order = 2,
}

Settings.define{
    key = "sellAssist", type = "toggle", default = true, section = "general", label = "SETTING_SELL_ASSIST", order = 3,
    apply = function(value)
        if not value and addon.SellAssist then addon.SellAssist:hide() end
    end,
}

Settings.define{
    key = "myAuctions", type = "toggle", default = true, section = "general", label = "SETTING_MY_AUCTIONS", order = 4,
    apply = function(value)
        if not value and addon.MyAuctions then addon.MyAuctions:hide() end
        if value and addon.MyAuctions then addon.MyAuctions:start() end
    end,
}

Settings.define{
    key = "fullScan", type = "toggle", default = true, section = "gathering", label = "SETTING_FULLSCAN", order = 1,
}

Settings.define{
    key = "hud", type = "toggle", default = true, section = "gathering", label = "SETTING_HUD", order = 2,
    apply = function(value)
        if addon.SessionHUD and addon.SessionHUD.setEnabled then addon.SessionHUD:setEnabled(value) end
    end,
}

Settings.define{
    key = "routeWaypoint", type = "toggle", default = true, section = "gathering", label = "SETTING_WAYPOINT", order = 3,
    apply = function(value)
        if addon.RouteFollow and addon.RouteFollow.setWaypoint then addon.RouteFollow:setWaypoint(value) end
    end,
}

Settings.define{
    key = "tooltipFields.vendor", type = "toggle", default = true, section = "fields", label = "SETTING_FIELD_VENDOR", order = 1,
}

Settings.define{
    key = "tooltipFields.last", type = "toggle", default = true, section = "fields", label = "SETTING_FIELD_LAST", order = 2,
}

Settings.define{
    key = "tooltipFields.median", type = "toggle", default = true, section = "fields", label = "SETTING_FIELD_MEDIAN", order = 3,
}

Settings.define{
    key = "tooltipFields.advice", type = "toggle", default = true, section = "fields", label = "SETTING_FIELD_ADVICE", order = 4,
}

Settings.define{
    key = "appPrices", type = "toggle", default = true, section = "prices", label = "SETTING_APP_PRICES", order = 1,
}
