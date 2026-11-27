return {
    ["merchant registra, filtra y deshace ventas y Comercio calcula la ganancia"] = function(addon, mock)
        local oldContainer, oldHook, oldBuyback, oldBuybackInfo = C_Container, hooksecurefunc, BuybackItem, GetBuybackItemInfo
        local oldDB = GoldPilotDB
        local ok, err = pcall(function()
            local info = { itemID = 77, stackCount = 3, hyperlink = "|cffffffff|Hitem:77|h[Ore]|h|r", isLocked = false }
            C_Container = {
                UseContainerItem = function() end,
                GetContainerItemInfo = function() return info end,
            }
            BuybackItem = function() end
            GetBuybackItemInfo = function() return "Ore", "texture", 15, 3 end
            hooksecurefunc = function(target, method, callback)
                if type(target) == "table" then mock.containerHook = callback
                else mock.buybackHook = method end
            end
            addon.Valuation.registerVendor(function(itemID) return itemID == 77 and 5 or 6 end)
            local merchant
            for _, module in ipairs(addon.Modules.registered) do if module.name == "merchant" then merchant = module end end
            assert(merchant and merchant.onEnable)
            merchant.onEnable()
            local db = { ledger = { [1970] = {
                { t = 199990, char = "Player", kind = "buy", name = "Ore", itemID = 77, qty = 3, gross = 9 },
            } } }
            GoldPilotDB = db
            mock.fire("MERCHANT_SHOW")
            mock.containerHook(0, 1)
            local sale = db.ledger[1970][2]
            assert(sale and sale.venue == "vendor" and sale.gross == 15 and sale.net == 15 and sale.qty == 3)
            mock.containerHook(0, 1)
            assert(#db.ledger[1970] == 2)

            mock.fire("MERCHANT_CLOSED")
            mock.containerHook(0, 1)
            assert(#db.ledger[1970] == 2)

            mock.fire("MERCHANT_SHOW")
            info.itemID, info.hyperlink = 88, "|cffffffff|Hitem:88|h[Unknown]|h|r"
            mock.containerHook(0, 2)
            assert(#db.ledger[1970] == 2)

            mock.buybackHook(1)
            assert(#db.ledger[1970] == 1)
            local items = addon.Trading.analyze(db.ledger[1970])
            assert(#items == 1 and items[1].vendorSold == 0)

            info.itemID, info.hyperlink = 77, "|cffffffff|Hitem:77|h[Ore]|h|r"
            mock.containerHook(0, 1)
            items = addon.Trading.analyze(db.ledger[1970])
            assert(items[1].vendorSold == 3 and items[1].vendorIncome == 15 and items[1].resaleProfit == 6)
        end)
        C_Container, hooksecurefunc, BuybackItem, GetBuybackItemInfo, GoldPilotDB = oldContainer, oldHook, oldBuyback, oldBuybackInfo, oldDB
        assert(ok, err)
    end,
}
