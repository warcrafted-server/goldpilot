local function setup()
    NUM_BAG_SLOTS = 2
    local bagContents = {
        [0] = { { itemID = 25, stackCount = 4 }, false, { itemID = 35, stackCount = 2 } },
        [1] = { { itemID = 25, stackCount = 3 }, { itemID = 36, stackCount = 5 } },
        [2] = {},
    }
    C_Container = {
        GetContainerNumSlots = function(bag) return #(bagContents[bag] or {}) end,
        GetContainerItemInfo = function(bag, slot) return (bagContents[bag] or {})[slot] end,
    }
    GetMoney = function() return 1234 end
    UnitName = function() return "Tester" end
    GetRealmName = function() return "Forever" end
    UnitFactionGroup = function() return "Horde" end
    time = function() return 100000 end
    C_AuctionHouse = {
        MakeItemKey = function(id) return { itemID = id } end,
        SendSearchQuery = function() end,
        GetAuctionHouseCut = function() return 0.05 end,
        GetNumCommoditySearchResults = function(id) return id == 25 and 2 or 0 end,
        GetCommoditySearchResultInfo = function(_, index)
            if index == 1 then return { unitPrice = 100, quantity = 3 } end
            return { unitPrice = 200, quantity = 7 }
        end,
    }
end

return {
    ["bags scan suma pilas e ignora huecos"] = function(addon)
        setup()
        local bags = addon.Bags:scan()
        assert(bags[25] == 7 and bags[35] == 2 and bags[36] == 5)
    end,
    ["la cola prioriza watch, ordena bolsas y omite datos ausentes y repetidos"] = function(addon, mock)
        setup()
        GoldPilotDB = { watch = { [35] = true, [25] = true, [999999] = true } }
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(addon.AuctionHouse:status().current == 25)
        assert(addon.AuctionHouse:status().pending == 2)
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 25)
        assert(addon.AuctionHouse:status().current == 35)
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 35)
        assert(addon.AuctionHouse:status().current == 36)
        mock.fire("AUCTION_HOUSE_CLOSED")
        local status = addon.AuctionHouse:status()
        assert(status.current == nil and status.pending == 0)
    end,
    ["resultado de subasta registra OBS con p50 ponderado"] = function(addon, mock)
        setup()
        GoldPilotDB = { watch = { [25] = true } }
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 25)
        local price = addon.Prices.get(GoldPilotDB, "Horde-Forever", 25)
        assert(price and price.src == "OBS" and price.p50 == 100 and price.min == 100)
        assert(price.qty == 10)
    end,
    ["consulta vencida se salta y cerrar vacía la cola"] = function(addon, mock)
        setup()
        GoldPilotDB = { watch = { [25] = true, [35] = true } }
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(addon.AuctionHouse:status().current == 25)
        local timeout = mock.timers[1]
        timeout()
        assert(addon.AuctionHouse:status().current == 35)
        mock.fire("AUCTION_HOUSE_CLOSED")
        local status = addon.AuctionHouse:status()
        assert(status.current == nil and status.pending == 0)
    end,
    ["subasta sin API se desactiva sin error"] = function(addon)
        C_AuctionHouse = nil
        addon.Modules:enableAll()
        local module
        for _, registered in ipairs(addon.Modules.registered) do
            if registered.name == "auctionhouse" then module = registered end
        end
        assert(module and module.enabled == false)
    end,
}
