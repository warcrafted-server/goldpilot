local function withGlobals(values, callback)
    local old = {}
    for name, value in pairs(values) do
        old[name] = _G[name]
        _G[name] = value
    end
    local ok, err = pcall(callback)
    for name in pairs(values) do _G[name] = old[name] end
    if not ok then error(err) end
end

local function enable(addon, mock)
    mock.fire("PLAYER_LOGIN")
end

local function said(mock, text)
    for _, line in ipairs(mock.output) do
        if string.find(line, text, 1, true) then return true end
    end
    return false
end

return {
    ["diag guarda informe con capacidades presentes y ausentes"] = function(addon, mock)
        withGlobals({
            C_AuctionHouse = { SendSearchQuery = function() end },
            time = function() return 123 end,
            GetBuildInfo = function() return "1.60.1", "70862" end,
            GetLocale = function() return "esES" end,
        }, function()
            GoldPilotDB = { diag = { auction = { abierta = true }, mail = { n = 4 }, loot = { n = 2 }, profs = { recetas = 9 } } }
            addon.Diag:run()
            assert(GoldPilotDB.diag.version == addon.version)
            assert(GoldPilotDB.diag.build == "1.60.1 (70862)")
            assert(GoldPilotDB.diag.locale == "esES" and GoldPilotDB.diag.fecha == 123)
            assert(GoldPilotDB.diag.caps["C_AuctionHouse"] == true)
            assert(GoldPilotDB.diag.caps["C_AuctionHouse.SendSearchQuery"] == true)
            assert(GoldPilotDB.diag.caps["C_AuctionHouse.GetAuctionHouseCut"] == false)
            assert(GoldPilotDB.diag.caps["GetInboxInvoiceInfo"] == false)
            assert(GoldPilotDB.diag.bags[-3] == 0 and GoldPilotDB.diag.bags[-1] == 0)
            assert(GoldPilotDB.diag.bags[0] == 0 and GoldPilotDB.diag.bags[12] == 0)
            assert(GoldPilotDB.diag.bags[-2] == nil)
            assert(GoldPilotDB.diag.auction.abierta and GoldPilotDB.diag.mail.n == 4)
            assert(GoldPilotDB.diag.loot.n == 2 and GoldPilotDB.diag.profs.recetas == 9)
            assert(#mock.output > 0)
        end)
    end,
    ["sondas guardan subasta correo botín y profesiones sin datos personales"] = function(addon, mock)
        withGlobals({
            time = function() return 456 end,
            InCombatLockdown = function() return false end,
            C_AuctionHouse = {
                GetAuctionHouseCut = function() return 0.05 end,
                MakeItemKey = function(itemID) return { itemID = itemID } end,
                SendSearchQuery = function(key) assert(key.itemID == 42) end,
                GetCommoditySearchResultsQuantity = function() return 7 end,
            },
            GetInboxNumItems = function() return 1 end,
            GetInboxInvoiceInfo = function() return 2, "Nombre privado", "Jugador privado", 90 end,
            GetNumLootItems = function() return 1 end,
            GetLootSourceInfo = function() return "Creature-0-1-2-3-4-ABC", 1 end,
            C_TradeSkillUI = { GetAllRecipeIDs = function() return { 10, 20 } end },
        }, function()
            enable(addon, mock)
            mock.fire("AUCTION_HOUSE_SHOW")
            mock.fire("MAIL_SHOW")
            mock.fire("LOOT_READY")
            mock.fire("TRADE_SKILL_SHOW")
            mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 42)
            local diag = GoldPilotDB.diag
            assert(diag.auction.abierta and diag.auction.cut == 0.05)
            assert(diag.auction.eventos[1].resultados == 7)
            assert(diag.mail.abierto and diag.mail.n == 1 and diag.mail.facturas[1].tipo == 2)
            assert(diag.mail.facturas[1].campos[2].tipo == "string")
            assert(diag.mail.facturas[1].campos[2].valor == nil)
            assert(diag.loot.n == 1 and diag.loot.ranuras[1].guid == "Creature-0-1-2-3-4-ABC")
            assert(diag.loot.ranuras[1].prefijo == "Creature")
            assert(diag.profs.abierta and diag.profs.recetas == 2)
            assert(diag.auction.fecha == 456 and diag.mail.fecha == 456)
        end)
    end,
    ["sondas toleran APIs ausentes"] = function(addon, mock)
        withGlobals({ InCombatLockdown = function() return false end }, function()
            enable(addon, mock)
            mock.fire("AUCTION_HOUSE_SHOW")
            mock.fire("MAIL_SHOW")
            mock.fire("LOOT_READY")
            mock.fire("TRADE_SKILL_SHOW")
            assert(GoldPilotDB.diag.auction.abierta)
            assert(GoldPilotDB.diag.mail.n == nil)
            assert(GoldPilotDB.diag.loot.n == nil)
            assert(GoldPilotDB.diag.profs.recetas == nil)
        end)
    end,
    ["diag ah avisa si la subasta está cerrada"] = function(addon, mock)
        withGlobals({
            InCombatLockdown = function() return false end,
            time = function() return 500 end,
        }, function()
            enable(addon, mock)
            SlashCmdList.GOLDPILOT("diag ah")
            assert(addon.Diag.ahSession == nil)
            assert(said(mock, addon.L.DIAG_AH_CLOSED))
            assert(GoldPilotDB == nil or GoldPilotDB.diag == nil or GoldPilotDB.diag.ah == nil)
        end)
    end,
    ["diag ah recoge estructura y eventos y guarda al repetir"] = function(addon, mock)
        local clock = 1000
        withGlobals({
            time = function() return clock end,
            InCombatLockdown = function() return false end,
            C_AuctionHouse = {
                GetNumOwnedAuctions = function() return 1 end,
                GetOwnedAuctionInfo = function() return "itemKey", 100, 2, "owner", 5000 end,
            },
            AuctionHouseFrame = {
                GetObjectType = function() return "Frame" end,
                GetWidth = function() return 500 end,
                GetHeight = function() return 400 end,
                IsShown = function() return true end,
                GetDisplayMode = function() return "Commodities" end,
                CommoditiesSellFrame = {
                    GetObjectType = function() return "Frame" end,
                    PriceInput = {
                        GetObjectType = function() return "EditBox" end,
                        SetAmount = function() end,
                        GetAmount = function() end,
                    },
                },
            },
        }, function()
            enable(addon, mock)
            mock.fire("AUCTION_HOUSE_SHOW")
            SlashCmdList.GOLDPILOT("diag ah")
            local session = addon.Diag.ahSession
            assert(session and session.inicio == 1000)
            assert(said(mock, addon.L.DIAG_AH_START))

            local structure = session.estructura
            assert(structure.AuctionHouseFrame.existe)
            assert(structure.AuctionHouseFrame.tipo == "Frame")
            assert(structure.AuctionHouseFrame.ancho == 500 and structure.AuctionHouseFrame.alto == 400)
            assert(structure.AuctionHouseFrame.visible == true)
            assert(structure.AuctionHouseFrame.metodos[1] == "GetDisplayMode")
            assert(structure.CommoditiesSellFrame.existe)
            local price
            for _, field in ipairs(structure.CommoditiesSellFrame.detalle) do
                if field.nombre == "PriceInput" then price = field end
            end
            assert(price and price.tipo == "EditBox")
            assert(price.metodos[1] == "SetAmount" and price.metodos[2] == "GetAmount")

            clock = 1010
            mock.fire("ITEM_SEARCH_RESULTS_UPDATED", 42)
            mock.fire("UI_ERROR_MESSAGE", "No puedes pujar", 1, "extra")
            mock.fire("AUCTION_HOUSE_SHOW_ERROR", "Error interno", 7)
            assert(session.eventos["ITEM_SEARCH_RESULTS_UPDATED"].n == 1)
            assert(session.eventos["ITEM_SEARCH_RESULTS_UPDATED"].primero == 1010)
            assert(session.eventos["ITEM_SEARCH_RESULTS_UPDATED"].ultimo == 1010)
            assert(session.eventos["UI_ERROR_MESSAGE"].n == 1)
            assert(session.eventos["UI_ERROR_MESSAGE"].ejemplos[1][1] == "No puedes pujar")
            assert(session.eventos["UI_ERROR_MESSAGE"].ejemplos[1][2] == "extra")
            assert(session.eventos["AUCTION_HOUSE_SHOW_ERROR"].n == 1)
            assert(session.eventos["AUCTION_HOUSE_SHOW_ERROR"].ejemplos[1][1] == "Error interno")

            clock = 1200
            SlashCmdList.GOLDPILOT("diag ah")
            local ah = GoldPilotDB.diag.ah
            assert(addon.Diag.ahSession == nil)
            assert(ah and ah.inicio == 1000 and ah.fin == 1200)
            assert(ah.eventos["ITEM_SEARCH_RESULTS_UPDATED"].n == 1)
            assert(ah.subastas[1][1] == "itemKey" and ah.subastas[1][5] == "5000")
            assert(ah.modo == "Commodities")
            assert(said(mock, addon.L.DIAG_AH_SAVED))

            mock.fire("ITEM_SEARCH_RESULTS_UPDATED", 42)
            assert(GoldPilotDB.diag.ah.eventos["ITEM_SEARCH_RESULTS_UPDATED"].n == 1)
        end)
    end,
    ["diag ah guarda al cerrar la subasta"] = function(addon, mock)
        withGlobals({
            InCombatLockdown = function() return false end,
            time = function() return 700 end,
        }, function()
            enable(addon, mock)
            mock.fire("AUCTION_HOUSE_SHOW")
            SlashCmdList.GOLDPILOT("diag ah")
            mock.fire("AUCTION_HOUSE_CLOSED")
            mock.flushTimers()
            local ah = GoldPilotDB.diag.ah
            assert(addon.Diag.ahSession == nil)
            assert(ah.eventos["AUCTION_HOUSE_CLOSED"].n == 1)
            assert(said(mock, addon.L.DIAG_AH_SAVED))
        end)
    end,
    ["diag ah tolera un AuctionHouseFrame ausente"] = function(addon, mock)
        withGlobals({
            InCombatLockdown = function() return false end,
            time = function() return 600 end,
        }, function()
            enable(addon, mock)
            mock.fire("AUCTION_HOUSE_SHOW")
            SlashCmdList.GOLDPILOT("diag ah")
            SlashCmdList.GOLDPILOT("diag ah")
            local ah = GoldPilotDB.diag.ah
            assert(ah.estructura.AuctionHouseFrame.existe == false)
            assert(ah.estructura.CommoditiesSellFrame.existe == false)
            assert(ah.modo == nil)
            assert(addon.Diag.ahSession == nil)
        end)
    end,
    ["comando diag guarda el informe y no actúa en combate"] = function(addon, mock)
        withGlobals({ time = function() return 789 end }, function()
            SlashCmdList.GOLDPILOT("diag")
            assert(GoldPilotDB.diag and GoldPilotDB.diag.fecha == 789)
        end)
        withGlobals({ InCombatLockdown = function() return true end }, function()
            enable(addon, mock)
            local previous = GoldPilotDB.diag
            SlashCmdList.GOLDPILOT("diag")
            assert(GoldPilotDB.diag == previous)
            SlashCmdList.GOLDPILOT("diag ah")
            assert(addon.Diag.ahSession == nil)
            mock.fire("AUCTION_HOUSE_SHOW")
            assert(GoldPilotDB.diag.auction == nil)
        end)
    end,
}
