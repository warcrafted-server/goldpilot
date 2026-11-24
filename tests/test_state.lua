local function setup()
    NUM_BAG_SLOTS = 2
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = nil
    NUM_BANKBAGSLOTS = nil
    BANK_CONTAINER = nil
    Enum = nil
    local bagContents = {
        [0] = { { itemID = 25, stackCount = 4 }, false, { itemID = 35, stackCount = 2 } },
        [1] = { { itemID = 25, stackCount = 3 }, { itemID = 36, stackCount = 5 } },
        [2] = {},
        [-1] = { { itemID = 37, stackCount = 3 } },
        [3] = { { itemID = 38, stackCount = 2 } },
        [5] = { { itemID = 999998, stackCount = 4 } },
        [6] = { { itemID = 40, stackCount = 6 } },
        [12] = { { itemID = 41, stackCount = 7 } },
        [-3] = { { itemID = 42, stackCount = 8 } },
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
        assert(bags[25] == 7 and bags[35] == 2 and bags[36] == 5 and bags[999998] == 4)
    end,
    ["la cola prioriza watch, ordena bolsas y omite datos ausentes y repetidos"] = function(addon, mock)
        setup()
        NUM_TOTAL_EQUIPPED_BAG_SLOTS = 2
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
        local price = addon.Prices.get(GoldPilotDB, "Horde", 25)
        assert(price and price.src == "OBS" and price.p50 == 100 and price.min == 100)
        assert(price.qty == 10)
        assert(GoldPilotDB.ahLast.result[25] == "ok")
    end,
    ["clave de casa no incluye reino y banco se guarda solo al abrirse"] = function(addon, mock)
        setup()
        GoldPilotDB = { chars = { Tester = { bank = { [25] = 8 }, bankSeen = 12 } } }
        addon.Modules:enableAll()
        assert(addon.AuctionHouse.houseKey() == "Horde")
        assert(GoldPilotDB.chars.Tester.bank[25] == 8)
        mock.fire("BANKFRAME_OPENED")
        mock.timers[1]()
        assert(GoldPilotDB.chars.Tester.bank[37] == 3 and GoldPilotDB.chars.Tester.bank[40] == 6)
        assert(GoldPilotDB.chars.Tester.bank[41] == 7 and GoldPilotDB.chars.Tester.bank[42] == 8)
        assert(GoldPilotDB.chars.Tester.bankSeen == 100000)
    end,
    ["scanBank usa ids de banco definidos por constantes"] = function(addon, mock)
        setup()
        NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4
        NUM_BANKBAGSLOTS = 2
        BANK_CONTAINER = -1
        Enum = { BagIndex = { Reagentbank = -3 } }
        addon.Modules:enableAll()
        mock.fire("BANKFRAME_OPENED")
        mock.timers[1]()
        local bank = GoldPilotDB.chars.Tester.bank
        assert(bank[37] == 3 and bank[999998] == 4 and bank[40] == 6 and bank[42] == 8)
        assert(bank[41] == nil)
    end,
    ["cola incluye banco propio y otros personajes después de las bolsas"] = function(addon, mock)
        setup()
        NUM_TOTAL_EQUIPPED_BAG_SLOTS = 2
        GoldPilotDB = { watch = { [35] = true }, chars = {
            Tester = { bank = { [37] = 1 } },
            Older = { seen = 10, bags = { [38] = 5 }, bank = { [36] = 3 } },
            Newer = { seen = 20, bags = { [25] = 99 }, bank = { [35] = 9 } },
        } }
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(addon.AuctionHouse:status().current == 35)
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 35)
        assert(addon.AuctionHouse:status().current == 25)
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 25)
        assert(addon.AuctionHouse:status().current == 36)
        mock.fire("ITEM_SEARCH_RESULTS_UPDATED", 36)
        assert(addon.AuctionHouse:status().current == 37)
        mock.fire("ITEM_SEARCH_RESULTS_UPDATED", 37)
        assert(addon.AuctionHouse:status().current == 38)
        mock.fire("AUCTION_HOUSE_CLOSED")
    end,
    ["ahLast registra respuestas vacías y nodata"] = function(addon, mock)
        setup()
        GoldPilotDB = { watch = { [35] = true } }
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        local last = GoldPilotDB.ahLast
        assert(last.houseKey == "Horde" and last.queued[1] == 35)
        addon.AuctionHouse:enqueue(999999, true)
        assert(last.result[999999] == "nodata")
        mock.fire("ITEM_SEARCH_RESULTS_UPDATED", 35)
        assert(last.result[35] == "empty")
        assert(not addon.AuctionHouse:enqueue(35, true))
    end,
    ["consulta vencida se salta y cerrar vacía la cola"] = function(addon, mock)
        setup()
        GoldPilotDB = { watch = { [25] = true, [35] = true } }
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(addon.AuctionHouse:status().current == 25)
        local timeout = mock.timers[1]
        timeout()
        assert(GoldPilotDB.ahLast.result[25] == "timeout")
        assert(addon.AuctionHouse:status().current == 35)
        mock.fire("AUCTION_HOUSE_CLOSED")
        local status = addon.AuctionHouse:status()
        assert(status.current == nil and status.pending == 0)
    end,
    ["fallo de clave o envío queda registrado"] = function(addon, mock)
        setup()
        C_AuctionHouse.MakeItemKey = function() return nil end
        GoldPilotDB = { watch = { [25] = true } }
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(GoldPilotDB.ahLast.result[25] == "senderror")
        mock.fire("AUCTION_HOUSE_CLOSED")
        setup()
        C_AuctionHouse.SendSearchQuery = function() error("send failed") end
        GoldPilotDB = { watch = { [25] = true } }
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(GoldPilotDB.ahLast.result[25] == "senderror")
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
    ["escaneo completo registra todos los objetos, vacía la cola y respeta el límite de 15 min"] = function(addon, mock)
        setup()
        GoldPilotDB = { watch = { [35] = true, [36] = true }, settings = { fullScan = true } }
        local ads = {
            { count = 3, buyout = 300, itemID = 25 }, { count = 7, buyout = 1400, itemID = 25 },
            { count = 1, buyout = 500, itemID = 35 }, { count = 1, buyout = 0, itemID = 36 },
            { count = 1, buyout = 9, itemID = 999999 }, { count = 1, buyout = 7, itemID = 82800 },
        }
        local replicated, readCalls = 0, 0
        C_AuctionHouse.ReplicateItems = function() replicated = replicated + 1 end
        C_AuctionHouse.GetNumReplicateItems = function() return #ads end
        C_AuctionHouse.GetReplicateItemInfo = function(index)
            readCalls = readCalls + 1
            local ad = ads[index + 1]
            return "n", 1, ad.count, 1, true, 1, 0, 0, 0, ad.buyout, 0, false, "", "o", "o", 0, ad.itemID, true
        end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(replicated == 1 and addon.AuctionHouse.scanning and addon.AuctionHouse:status().current == nil)
        mock.fire("REPLICATE_ITEM_LIST_UPDATE")
        mock.fire("REPLICATE_ITEM_LIST_UPDATE")
        mock.fire("REPLICATE_ITEM_LIST_UPDATE")
        for _ = 1, 5 do mock.flushTimers() end
        assert(readCalls == #ads)
        assert(not addon.FullScan.inProgress and not addon.AuctionHouse.scanning)
        assert(addon.Prices.get(GoldPilotDB, "Horde", 25).p50 == 100)
        assert(addon.Prices.get(GoldPilotDB, "Horde", 35).min == 500)
        assert(addon.Prices.get(GoldPilotDB, "Horde", 36) == nil)
        assert(addon.Prices.get(GoldPilotDB, "Horde", 999999).min == 9 and addon.Prices.get(GoldPilotDB, "Horde", 82800) == nil)
        assert(GoldPilotDB.ahLast.result[36] == "empty" and addon.AuctionHouse:status().pending == 0)
        mock.fire("AUCTION_HOUSE_CLOSED")
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(replicated == 1)
        local started, reason = addon.FullScan:start(true)
        assert(not started and reason == "cooldown")
    end,
    ["escaneo completo vacío vuelve a la cola por objetos"] = function(addon, mock)
        setup()
        GoldPilotDB = { watch = { [25] = true }, settings = { fullScan = true } }
        C_AuctionHouse.ReplicateItems = function() end
        C_AuctionHouse.GetNumReplicateItems = function() return 0 end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        mock.fire("REPLICATE_ITEM_LIST_UPDATE")
        assert(not addon.AuctionHouse.scanning and addon.AuctionHouse:status().current == 25)
    end,
    ["una búsqueda ajena a la cola también actualiza el precio y saca el objeto de la cola"] = function(addon, mock)
        setup()
        GoldPilotDB = { watch = { [35] = true, [25] = true } }
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(addon.AuctionHouse:status().current == 25)
        local pending = addon.AuctionHouse:status().pending
        C_AuctionHouse.GetNumItemSearchResults = function() return 1 end
        C_AuctionHouse.GetItemSearchResultInfo = function() return { buyoutAmount = 70, quantity = 1 } end
        mock.fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 35 })
        assert(addon.Prices.get(GoldPilotDB, "Horde", 35).min == 70)
        assert(addon.AuctionHouse:status().pending == pending - 1 and addon.AuctionHouse:status().current == 25)
    end,
    ["los objetos equipados entran en la cola"] = function(addon, mock)
        setup()
        GetInventoryItemID = function(_, slot) return slot == 16 and 36 or nil end
        GoldPilotDB = {}
        addon.Modules:enableAll()
        assert(addon.Bags:scanEquipped()[36] == 1)
        mock.fire("AUCTION_HOUSE_SHOW")
        local last = GoldPilotDB.ahLast
        local found
        for _, id in ipairs(last.queued) do if id == 36 then found = true end end
        assert(found)
    end,
}
