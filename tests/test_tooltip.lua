local function setup()
    time = function() return 100000 end
    UnitFactionGroup = function() return "Horde" end
    GetRealmName = function() return "Forever" end
    IsShiftKeyDown = function() return false end
    GetCoinTextureString = nil
end

local function tooltip()
    local frame = { lines = {} }
    function frame:AddLine(line) self.lines[#self.lines + 1] = line end
    function frame:GetItem() return "Item", "item:25" end
    function frame:HookScript(event, callback) self.hook = callback end
    return frame
end

return {
    ["tooltip muestra dos lineas y cuatro con Mayus"] = function(addon)
        setup()
        GoldPilotDB = { houses = { ["Horde-Forever"] = {} }, prices = { ["Horde-Forever"] = { [25] = { last = { t = 99900, min = 80, p50 = 100, qty = 12, src = "OBS" } } } } }
        addon.Modules:enableAll()
        local frame = tooltip()
        addon.Tooltip:add(frame, { id = 25 })
        assert(#frame.lines == 2 and string.find(frame.lines[1], "0g 0s 7c", 1, true))
        local expanded = tooltip()
        IsShiftKeyDown = function() return true end
        addon.Tooltip:add(expanded, { id = 25 })
        assert(#expanded.lines == 4 and string.find(expanded.lines[3], "80", 1, true))
    end,
    ["tooltip muestra antiguedad en gris y ausencia de observacion"] = function(addon)
        setup()
        time = function() return 300000 end
        GoldPilotDB = { prices = { ["Horde-Forever"] = { [25] = { last = { t = 1, min = 5, p50 = 6, qty = 3, src = "OBS" } } } } }
        local old = tooltip()
        addon.Tooltip:add(old, { id = 25 })
        assert(#old.lines == 2 and string.find(old.lines[2], "old data", 1, true))
        GoldPilotDB = nil
        local none = tooltip()
        addon.Tooltip:add(none, { id = 25 })
        assert(#none.lines == 2 and string.find(none.lines[2], "no observed price", 1, true))
    end,
    ["tooltip no actua en combate"] = function(addon, mock)
        setup()
        mock.combat = true
        local frame = tooltip()
        addon.Tooltip:add(frame, { id = 25 })
        assert(#frame.lines == 0)
    end,
    ["comando bags imprime el resumen"] = function(addon, mock)
        setup()
        C_Container = {
            GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
            GetContainerItemInfo = function() return { itemID = 25, stackCount = 4 } end,
        }
        NUM_BAG_SLOTS = 0
        GoldPilotDB = {
            houses = { ["Horde-Forever"] = { cut = 0.05 } },
            prices = { ["Horde-Forever"] = { [25] = { last = { t = 99900, min = 80, p50 = 100, qty = 12, src = "OBS" } } } },
        }
        SlashCmdList.GOLDPILOT("bags")
        assert(#mock.output == 1 and string.find(mock.output[1], "Bags:", 1, true))
        assert(string.find(mock.output[1], "3s 80c", 1, true))
    end,
}
