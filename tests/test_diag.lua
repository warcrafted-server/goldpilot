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

return {
    ["diag guarda informe con capacidades presentes y ausentes"] = function(addon, mock)
        withGlobals({
            C_AuctionHouse = { SendSearchQuery = function() end },
            time = function() return 123 end,
            GetBuildInfo = function() return "1.60.1", "70862" end,
            GetLocale = function() return "esES" end,
        }, function()
            addon.Diag:run()
            assert(GoldPilotDB.diag.version == addon.version)
            assert(GoldPilotDB.diag.build == "1.60.1 (70862)")
            assert(GoldPilotDB.diag.locale == "esES" and GoldPilotDB.diag.fecha == 123)
            assert(GoldPilotDB.diag.caps["C_AuctionHouse"] == true)
            assert(GoldPilotDB.diag.caps["C_AuctionHouse.SendSearchQuery"] == true)
            assert(GoldPilotDB.diag.caps["C_AuctionHouse.GetAuctionHouseCut"] == false)
            assert(GoldPilotDB.diag.caps["GetInboxInvoiceInfo"] == false)
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
            SlashCmdList.GOLDPILOT("diag ah 42")
            mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 42)
            local diag = GoldPilotDB.diag
            assert(diag.auction.abierta and diag.auction.cut == 0.05)
            assert(diag.auction.itemID == 42 and diag.auction.eventos[1].resultados == 7)
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
            mock.fire("AUCTION_HOUSE_SHOW")
            assert(GoldPilotDB.diag.auction == nil)
        end)
    end,
}
