local function setup()
    time = function() return 100000 end
    UnitFactionGroup = function() return "Horde" end
    GetRealmName = function() return "Forever" end
    IsShiftKeyDown = function() return false end
    GetCoinTextureString = nil
end

local function find(lines, text)
    for _, line in ipairs(lines) do if string.find(line, text, 1, true) then return true end end
end

local function tooltip()
    local frame = { lines = {} }
    function frame:AddLine(line) self.lines[#self.lines + 1] = line end
    function frame:GetItem() return "Item", "item:25" end
    function frame:HookScript(event, callback) self.hook = callback end
    return frame
end

return {
    ["tooltip muestra cabecera, vendedor, ultimo visto, mediana y mejor opcion; Mayus añade detalle"] = function(addon)
        setup()
        GoldPilotDB = { houses = { Horde = {} }, prices = { Horde = { [25] = { last = { t = 99900, min = 80, p50 = 100, qty = 12, src = "OBS" } } } } }
        addon.Modules:enableAll()
        local frame = tooltip()
        addon.Tooltip:add(frame, { id = 25 })
        assert(#frame.lines == 5 and string.find(frame.lines[1], "GoldPilot", 1, true))
        assert(string.find(frame.lines[2], "Vendor: 0g 0s 7c", 1, true))
        assert(string.find(frame.lines[3], "Last seen: 0g 0s 80c", 1, true))
        assert(string.find(frame.lines[4], "Median: 1g", 1, true) or string.find(frame.lines[4], "Median: 0g 1s", 1, true))
        assert(string.find(frame.lines[5], "Best option", 1, true) and string.find(frame.lines[5], "Auction", 1, true))
        local expanded = tooltip()
        IsShiftKeyDown = function() return true end
        addon.Tooltip:add(expanded, { id = 25 })
        assert(find(expanded.lines, "For sale: 12 units"))
    end,
    ["tooltip respeta las lineas desactivadas en ajustes"] = function(addon)
        setup()
        GoldPilotDB = { settings = { tooltipFields = { vendor = false, median = false, advice = false } },
            houses = { Horde = {} }, prices = { Horde = { [25] = { last = { t = 99900, min = 80, p50 = 100, qty = 12, src = "OBS" } } } } }
        addon.Modules:enableAll()
        local frame = tooltip()
        addon.Tooltip:add(frame, { id = 25 })
        assert(#frame.lines == 2 and find(frame.lines, "Last seen"))
        GoldPilotDB.settings.tooltipFields.last = false
        local none = tooltip()
        addon.Tooltip:add(none, { id = 25 })
        assert(#none.lines == 0)
    end,
    ["tooltip usa lineas dobles cuando existen"] = function(addon)
        setup()
        GoldPilotDB = { houses = { Horde = {} }, prices = { Horde = { [25] = { last = { t = 99900, min = 80, p50 = 100, qty = 12, src = "OBS" } } } } }
        addon.Modules:enableAll()
        local frame = tooltip()
        frame.doubles = {}
        function frame:AddDoubleLine(left, right) self.doubles[#self.doubles + 1] = { left, right } end
        addon.Tooltip:add(frame, { id = 25 })
        assert(#frame.doubles == 5 and frame.doubles[1][1] == "GoldPilot" and string.find(frame.doubles[1][2], "ago", 1, true))
        assert(frame.doubles[2][1] == "Vendor" and frame.doubles[3][1] == "Last seen")
    end,
    ["tooltip muestra antiguedad en gris y ausencia de observacion"] = function(addon)
        setup()
        time = function() return 300000 end
        GoldPilotDB = { prices = { Horde = { [25] = { last = { t = 1, min = 5, p50 = 6, qty = 3, src = "OBS" } } } } }
        local old = tooltip()
        addon.Tooltip:add(old, { id = 25 })
        assert(find(old.lines, "old data"))
        GoldPilotDB = nil
        local none = tooltip()
        addon.Tooltip:add(none, { id = 25 })
        assert(find(none.lines, "no observed price"))
    end,
    ["tooltip no actua en combate"] = function(addon, mock)
        setup()
        mock.combat = true
        local frame = tooltip()
        addon.Tooltip:add(frame, { id = 25 })
        assert(#frame.lines == 0)
    end,
    ["hover encola con prioridad solo durante subasta y sin observación reciente"] = function(addon, mock)
        setup()
        for _, itemID in ipairs({ 25, 35, 36 }) do addon.DataItems[itemID] = "1;1;0;7;0" end
        C_AuctionHouse = {
            MakeItemKey = function(id) return { itemID = id } end,
            SendSearchQuery = function() end,
            GetNumItemSearchResults = function() return 0 end,
        }
        GoldPilotDB = { watch = { [35] = true }, prices = { Horde = {
            [25] = { last = { t = 99950, min = 1, p50 = 1, qty = 1 } },
            [36] = { last = { t = 90000, min = 1, p50 = 1, qty = 1 } },
        } } }
        addon.Bags.scan = function() return {} end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        addon.Tooltip:add(tooltip(), { id = 25 })
        addon.Tooltip:add(tooltip(), { id = 36 })
        assert(addon.AuctionHouse:status().current == 35)
        mock.fire("ITEM_SEARCH_RESULTS_UPDATED", 35)
        assert(addon.AuctionHouse:status().current == 36)
        mock.fire("ITEM_SEARCH_RESULTS_UPDATED", 36)
        assert(addon.AuctionHouse:status().current == nil)
        mock.fire("AUCTION_HOUSE_CLOSED")
        addon.Tooltip:add(tooltip(), { id = 36 })
        assert(addon.AuctionHouse:status().current == nil)
    end,
    ["tooltip busca el precio de la variante indicada por data.hyperlink"] = function(addon)
        setup()
        GoldPilotDB = { houses = { Horde = {} }, prices = { Horde = {
            ["25:111"] = { last = { t = 99900, min = 80, p50 = 100, qty = 1, src = "OBS" } },
        } } }
        addon.Modules:enableAll()
        local first = tooltip()
        addon.Tooltip:add(first, { id = 25, hyperlink = "item:25::::::::::::1:111" })
        assert(find(first.lines, "Last seen: 0g 0s 80c"))
        local other = tooltip()
        addon.Tooltip:add(other, { id = 25, hyperlink = "item:25::::::::::::1:222" })
        assert(not find(other.lines, "Last seen") and not find(other.lines, "0g 0s 80c"))
    end,
    ["tooltip ligado solo muestra vendedor y no aconseja ni encola subasta"] = function(addon, mock)
        setup()
        ITEM_SOULBOUND = "Soulbound"
        addon.DataItems[25] = "7;1;0;0;0"
        GoldPilotDB = { houses = { Horde = {} }, prices = { Horde = {
            [25] = { last = { t = 99900, min = 80, p50 = 100, qty = 1 } },
        } } }
        addon.Modules:enableAll()
        local frame = tooltip()
        addon.Tooltip:add(frame, { id = 25, lines = { { leftText = "Soulbound" } } })
        assert(#frame.lines == 4 and find(frame.lines, "Vendor:") and not find(frame.lines, "Auction") and not find(frame.lines, "Last seen"))
        assert(addon.AuctionHouse:status().pending == 0)
        addon.DataItems[25] = "0;1;0;0;0"
        local noVendor = tooltip()
        addon.Tooltip:add(noVendor, { id = 25, lines = { { leftText = "Soulbound" } } })
        assert(#noVendor.lines == 0)
        addon.DataItems = {}
        GoldPilotDB = { houses = { Horde = {} } }
        local unknown = tooltip()
        addon.Tooltip:add(unknown, { id = 2973, lines = { { leftText = "Soulbound" } } })
        assert(#unknown.lines == 0)
        ITEM_SOULBOUND = nil
    end,
    ["comando bags imprime el resumen"] = function(addon, mock)
        setup()
        C_Container = {
            GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
            GetContainerItemInfo = function() return { itemID = 25, stackCount = 4 } end,
        }
        NUM_BAG_SLOTS = 0
        GoldPilotDB = {
            houses = { Horde = { cut = 0.05 } },
            prices = { Horde = { [25] = { last = { t = 99900, min = 80, p50 = 100, qty = 12, src = "OBS" } } } },
        }
        SlashCmdList.GOLDPILOT("bags")
        assert(#mock.output == 1 and string.find(mock.output[1], "Bags:", 1, true))
        assert(string.find(mock.output[1], "3s 80c", 1, true))
    end,
    ["tooltip con Mayus añade la tendencia diaria"] = function(addon)
        setup()
        GoldPilotDB = { houses = { Horde = {} }, prices = { Horde = { [25] = {
            last = { t = 99900, min = 80, p50 = 112, qty = 12, src = "OBS" }, d = "0:70:100:10" } } } }
        addon.Modules:enableAll()
        IsShiftKeyDown = function() return true end
        local frame = tooltip()
        addon.Tooltip:add(frame, { id = 25 })
        assert(find(frame.lines, "For sale: 12 units") and find(frame.lines, "+12%"))
    end,
}
