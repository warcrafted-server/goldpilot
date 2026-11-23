local _, addon = ...

addon.Log = {}
local levels = { debug = 1, info = 2, warning = 3, error = 4 }

local function write(level, ...)
    if level == "debug" and not (GoldPilotDB and GoldPilotDB.debug) then return end
    local message = table.concat({ ... }, " ")
    if type(print) == "function" then print("|cffffd100GoldPilot|r [" .. level .. "] " .. message) end
end

for name in pairs(levels) do
    addon.Log[name] = function(_, ...) write(name, ...) end
end
