local function setup()
    GetInventoryItemID = nil
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

local function setNonGearFixtures(addon, mock)
    for _, itemID in ipairs({ 25, 35, 36, 37, 38, 40, 41, 42 }) do
        mock.items[itemID] = { sell = 1, stack = 1, class = 7, bind = 0 }
    end
end

return {
    ["bags scan suma pilas e ignora huecos"] = function(addon, mock)
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
        assert(addon.AuctionHouse:status().pending >= 2)
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 25)
        assert(addon.AuctionHouse:status().current == 35)
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 35)
        assert(addon.AuctionHouse:status().current == 999999)
        mock.fire("ITEM_SEARCH_RESULTS_UPDATED", 999999)
        assert(addon.AuctionHouse:status().current == 36)
        mock.fire("AUCTION_HOUSE_CLOSED")
        local status = addon.AuctionHouse:status()
        assert(status.current == nil and status.pending == 0)
    end,
    ["resultado de subasta registra OBS con p50 ponderado"] = function(addon, mock)
        setup()
        setNonGearFixtures(addon, mock)
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
        mock.items[999998] = { bind = 1 }
        assert(not addon.AuctionHouse:enqueue(999998, true))
        assert(last.result[999998] == "nodata")
        assert(addon.AuctionHouse:enqueue(999999, true))
        assert(last.result[999999] == nil)
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
    ["subasta sin API se desactiva sin error"] = function(addon, mock)
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
        setNonGearFixtures(addon, mock)
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
    ["escaneo completo registra variantes y no asigna su precio a la clave numérica"] = function(addon, mock)
        setup()
        mock.items[25] = { class = 2 }
        GoldPilotDB = { settings = { fullScan = true } }
        local ads = { { price = 100, bonus = 123 }, { price = 200, bonus = 456 } }
        C_AuctionHouse.ReplicateItems = function() end
        C_AuctionHouse.GetNumReplicateItems = function() return #ads end
        C_AuctionHouse.GetReplicateItemInfo = function(index)
            local ad = ads[index + 1]
            return "n", 1, 1, 1, true, 1, 0, 0, 0, ad.price, 0, false, "", "o", "o", 0, 25, true
        end
        C_AuctionHouse.GetReplicateItemLink = function(index)
            return "item:25::::::::::::1:" .. ads[index + 1].bonus
        end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        mock.fire("REPLICATE_ITEM_LIST_UPDATE")
        for _ = 1, 3 do mock.flushTimers() end
        assert(addon.Prices.get(GoldPilotDB, "Horde", "25:123").min == 100)
        assert(addon.Prices.get(GoldPilotDB, "Horde", "25:456").min == 200)
        assert(addon.Prices.get(GoldPilotDB, "Horde", 25) == nil)
        assert(GoldPilotDB.scan.items == 1 and GoldPilotDB.scan.keys == 2)
    end,
    ["escaneo reintenta enlaces ausentes y descarta los que nunca llegan"] = function(addon, mock)
        setup()
        mock.items[25] = { class = 2 }
        GoldPilotDB = { settings = { fullScan = true } }
        C_AuctionHouse.ReplicateItems = function() end
        C_AuctionHouse.GetNumReplicateItems = function() return 1 end
        C_AuctionHouse.GetReplicateItemInfo = function()
            return "n", 1, 1, 1, true, 1, 0, 0, 0, 100, 0, false, "", "o", "o", 0, 25, true
        end
        local calls = 0
        C_AuctionHouse.GetReplicateItemLink = function()
            calls = calls + 1
            if calls == 2 then return "item:25::::::::::::1:789" end
        end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        mock.fire("REPLICATE_ITEM_LIST_UPDATE")
        for _ = 1, 3 do mock.flushTimers() end
        assert(addon.Prices.get(GoldPilotDB, "Horde", "25:789").min == 100)
        assert(GoldPilotDB.scan.noLink == 0)
        mock.fire("AUCTION_HOUSE_CLOSED")

        setup()
        GoldPilotDB = { settings = { fullScan = true } }
        C_AuctionHouse.ReplicateItems = function() end
        C_AuctionHouse.GetNumReplicateItems = function() return 1 end
        C_AuctionHouse.GetReplicateItemInfo = function()
            return "n", 1, 1, 1, true, 1, 0, 0, 0, 100, 0, false, "", "o", "o", 0, 25, true
        end
        C_AuctionHouse.GetReplicateItemLink = function() return nil end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        mock.fire("REPLICATE_ITEM_LIST_UPDATE")
        for _ = 1, 5 do mock.flushTimers() end
        assert(GoldPilotDB.scan.noLink == 1 and addon.Prices.get(GoldPilotDB, "Horde", 25) == nil)
    end,
    ["cerrar la subasta cancela los reintentos de enlaces"] = function(addon, mock)
        setup()
        mock.items[25] = { class = 2 }
        GoldPilotDB = { settings = { fullScan = true } }
        C_AuctionHouse.ReplicateItems = function() end
        C_AuctionHouse.GetNumReplicateItems = function() return 1 end
        C_AuctionHouse.GetReplicateItemInfo = function()
            return "n", 1, 1, 1, true, 1, 0, 0, 0, 100, 0, false, "", "o", "o", 0, 25, true
        end
        C_AuctionHouse.GetReplicateItemLink = function() return nil end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        mock.fire("REPLICATE_ITEM_LIST_UPDATE")
        mock.fire("AUCTION_HOUSE_CLOSED")
        for _ = 1, 4 do mock.flushTimers() end
        assert(addon.Prices.get(GoldPilotDB, "Horde", 25) == nil and GoldPilotDB.scan.keys == 0)
    end,
    ["búsqueda de objeto registra cada variante de equipo"] = function(addon, mock)
        setup()
        mock.items[25] = { class = 2 }
        GoldPilotDB = { watch = { [25] = true } }
        C_AuctionHouse.GetNumItemSearchResults = function() return 2 end
        C_AuctionHouse.GetItemSearchResultInfo = function(_, index)
            return { buyoutAmount = index * 100, quantity = 1,
                itemLink = "item:25::::::::::::1:" .. (index == 1 and "111" or "222") }
        end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        mock.fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 25 })
        assert(addon.Prices.get(GoldPilotDB, "Horde", "25:111").min == 100)
        assert(addon.Prices.get(GoldPilotDB, "Horde", "25:222").min == 200)
        assert(addon.Prices.get(GoldPilotDB, "Horde", 25) == nil)
    end,
    ["la poda se retrasa al entrar y espera fuera de combate"] = function(addon, mock)
        setup()
        local pruned = 0
        addon.Prices.prune = function(db, stamp)
            pruned = pruned + 1
            assert(db == GoldPilotDB and stamp == 100000)
        end
        GoldPilotDB = {}
        addon.Modules:enableAll()
        mock.fire("PLAYER_ENTERING_WORLD")
        mock.combat = true
        mock.flushTimers()
        assert(pruned == 0)
        mock.combat = false
        mock.flushTimers()
        assert(pruned == 1)
    end,
    ["una búsqueda ajena a la cola también actualiza el precio y saca el objeto de la cola"] = function(addon, mock)
        setup()
        setNonGearFixtures(addon, mock)
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
    ["un objeto sin datos cargados pasa al final, se reintenta y no bloquea la cola"] = function(addon, mock)
        setup()
        GoldPilotDB = { watch = { [25] = true, [35] = true } }
        addon.Bags.scan = function() return {} end
        local loaded, sent = {}, {}
        C_AuctionHouse.GetItemKeyInfo = function(key) if key.itemID ~= 25 or loaded[25] then return { itemName = "x" } end end
        C_AuctionHouse.SendSearchQuery = function(key) sent[#sent + 1] = key.itemID end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(#sent == 0)
        mock.flushTimers()
        assert(#sent == 1 and sent[1] == 35)
        loaded[25] = true
        mock.fire("ITEM_SEARCH_RESULTS_UPDATED", 35)
        assert(sent[2] == 25)
    end,
    ["un objeto que nunca carga se abandona"] = function(addon, mock)
        setup()
        GoldPilotDB = { watch = { [25] = true } }
        addon.Bags.scan = function() return {} end
        C_AuctionHouse.GetItemKeyInfo = function() end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        for _ = 1, 8 do mock.flushTimers() end
        assert(GoldPilotDB.ahLast.result[25] == "noinfo" and addon.AuctionHouse:status().pending == 0)
    end,
    ["lo leído hace menos de 15 minutos no vuelve a la cola"] = function(addon, mock)
        setup()
        GoldPilotDB = { watch = { [25] = true, [35] = true }, prices = { Horde = {
            [25] = { last = { t = 99900, min = 1, p50 = 1, qty = 1 } } } } }
        addon.Bags.scan = function() return {} end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(addon.AuctionHouse:status().current == 35 and addon.AuctionHouse:status().pending == 0)
    end,
    ["la cola omite objetos totalmente ligados aunque estén seguidos"] = function(addon, mock)
        setup()
        NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
        C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end
        C_Container.GetContainerItemInfo = function() return { itemID = 25, stackCount = 2, isBound = true } end
        setNonGearFixtures(addon, mock)
        GoldPilotDB = { watch = { [25] = true } }
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(addon.AuctionHouse:status().current == nil and addon.AuctionHouse:status().pending == 0)
        assert(#GoldPilotDB.ahLast.queued == 0)
    end,
    ["la cola ordena bolsas por cantidad y añade el banco una sola vez"] = function(addon, mock)
        setup()
        NUM_TOTAL_EQUIPPED_BAG_SLOTS = 2
        C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 5 or 0 end
        C_Container.GetContainerItemInfo = function(_, slot)
            return { itemID = 40 + slot, stackCount = slot }
        end
        setNonGearFixtures(addon, mock)
        for id = 41, 45 do mock.items[id] = { sell = 1, class = 7 } end
        GoldPilotDB = { chars = { Tester = { bank = { [35] = 8 } } } }
        local originalScan, scans = addon.Bags.scan, 0
        addon.Bags.scan = function(self) scans = scans + 1; return originalScan(self) end
        addon.Modules:enableAll()
        scans = 0
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(scans == 1)
        local queued = GoldPilotDB.ahLast.queued
        assert(queued[1] == 45 and queued[2] == 44 and queued[3] == 43 and queued[4] == 42 and queued[5] == 41)
        assert(queued[6] == 35 and #queued == 6)
        mock.fire("AUCTION_HOUSE_CLOSED")
    end,
    ["bags scan conserva clave de variante, ligado y enlace del cliente"] = function(addon, mock)
        setup()
        mock.items[100] = { sell = 1, stack = 1, class = 4, bind = 0 }
        C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end
        C_Container.GetContainerItemInfo = function()
            return { itemID = 100, stackCount = 2, isBound = true, hyperlink = "|Hitem:100::::::::::::1:222|h[Test]|h" }
        end
        GoldPilotDB = {}
        local items, bound = addon.Bags:scan()
        assert(items["100:222"] == 2 and bound["100:222"] == 2)
        assert(GoldPilotDB.links["100:222"] == "item:100::::::::::::1:222")
    end,
    ["el escaneo publica lo resuelto y completa las variantes pendientes al cerrar"] = function(addon, mock)
        setup()
        mock.items[25] = { class = 4 }
        GoldPilotDB = { settings = { fullScan = true } }
        local ads = { { id = 25, price = 100, bonus = 1 }, { id = 25, price = 60 }, { id = 35, price = 7 } }
        C_AuctionHouse.ReplicateItems = function() end
        C_AuctionHouse.GetNumReplicateItems = function() return #ads end
        C_AuctionHouse.GetReplicateItemInfo = function(index)
            local ad = ads[index + 1]
            return "n", 1, 1, 1, true, 1, 0, 0, 0, ad.price, 0, false, "", "o", "o", 0, ad.id, true
        end
        C_AuctionHouse.GetReplicateItemLink = function(index)
            local ad = ads[index + 1]
            return ad.bonus and ("item:25::::::::::::1:" .. ad.bonus) or nil
        end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        mock.fire("REPLICATE_ITEM_LIST_UPDATE")
        assert(not addon.FullScan.inProgress and not addon.AuctionHouse.scanning)
        assert(addon.Prices.get(GoldPilotDB, "Horde", 35).min == 7)
        assert(addon.Prices.get(GoldPilotDB, "Horde", "25:1") == nil and addon.FullScan.flush)
        mock.fire("AUCTION_HOUSE_CLOSED")
        for _ = 1, 4 do mock.flushTimers() end
        assert(addon.Prices.get(GoldPilotDB, "Horde", "25:1").min == 100)
        assert(not addon.FullScan.flush and GoldPilotDB.scan.noLink == 1 and GoldPilotDB.scan.late)
    end,
}
