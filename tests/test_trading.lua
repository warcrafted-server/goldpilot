return {
    ["trading FIFO parcial, venta externa, orden temporal y deposito excluido"] = function(addon)
        local items, totals = addon.Trading.analyze({
            { t = 1, kind = "buy", name = "Ore", qty = 2, gross = 20 },
            { t = 2, kind = "buy", name = "Ore", qty = 3, gross = 60 },
            { t = 3, kind = "sell", name = "Ore", qty = 4, gross = 100, cut = 5, deposit = 40 },
            { t = 0, kind = "sell", name = "Ore", qty = 2, gross = 30, cut = 0 },
        })
        local ore = items[1]
        assert(ore.name == "Ore" and ore.sold == 6 and ore.resold == 4 and ore.other == 2)
        assert(ore.resaleProfit == 35 and ore.otherIncome == 30)
        assert(ore.stock == 1 and ore.stockCost == 20)
        assert(ore.bought == 5 and ore.spent == 80 and ore.income == 125)
        assert(totals.spent == 80 and totals.income == 125 and totals.balance == 45)
        assert(totals.stockCost == 20)
    end,
    ["trading mismo instante compra antes de venta y devoluciones no afectan"] = function(addon)
        local items = addon.Trading.analyze({
            { t = 10, kind = "sell", name = "Same", qty = 1, gross = 30, cut = 2 },
            { t = 10, kind = "buy", name = "Same", qty = 1, gross = 10 },
            { t = 11, kind = "return", name = "Same", qty = 9, gross = 900 },
            { t = 12, kind = "buy", name = "Ignored", qty = 0, gross = 10 },
        })
        local same = items[1]
        assert(same.resold == 1 and same.other == 0 and same.resaleProfit == 18)
        assert(#items == 1)
    end,
    ["trading aparta compras personales de los totales"] = function(addon)
        local items, totals = addon.Trading.analyze({
            { t = 1, kind = "buy", name = "Personal", qty = 2, gross = 50 },
            { t = 2, kind = "sell", name = "Personal", qty = 1, gross = 40, cut = 2 },
            { t = 1, kind = "buy", name = "Trade", qty = 1, gross = 10 },
        }, { Personal = true })
        local byName = {}
        for _, item in ipairs(items) do byName[item.name] = item end
        assert(byName.Personal.personal and totals.personalSpent == 50)
        assert(totals.spent == 10 and totals.income == 0 and totals.balance == -10)
        assert(totals.resaleProfit == 0 and totals.stockCost == 10)
    end,
    ["trading UI registra Comercio, filtra y aparta un objeto personal"] = function(addon)
        local previousDB, previousChar = GoldPilotDB, GoldPilotCharDB
        GoldPilotDB = { ledger = { [1970] = {
            { t = 199990, kind = "buy", name = "Ore", itemID = 25, qty = 2, gross = 20 },
            { t = 199991, kind = "sell", name = "Ore", qty = 1, gross = 30, cut = 1, deposit = 50 },
            { t = 199992, kind = "buy", name = "Potion", itemID = 26, qty = 1, gross = 40 },
        } } }
        GoldPilotCharDB = {}
        addon.Main:show()
        local order = addon.Main.tabOrder
        local ledger, trading
        for i, tab in ipairs(order) do
            if tab == "ledger" then ledger = i elseif tab == "trading" then trading = i end
        end
        assert(ledger and trading == ledger + 1)
        addon.Main.tabsBar:select("trading")
        local ui = addon.TradingUI
        assert(ui.widgets.metrics.items[1].value.value == addon.Theme.money(60))
        assert(ui.widgets.metrics.items[2].value.value == addon.Theme.money(29))
        assert(#ui.widgets.list.data == 2)
        ui.filterButton.scripts.OnClick(ui.filterButton)
        assert(GoldPilotCharDB.tradingFilter == "resale" and #ui.widgets.list.data == 2)
        ui.filterButton.scripts.OnClick(ui.filterButton)
        assert(GoldPilotCharDB.tradingFilter == "stock" and #ui.widgets.list.data == 2)
        ui.filterButton.scripts.OnClick(ui.filterButton)
        assert(GoldPilotCharDB.tradingFilter == "personal" and #ui.widgets.list.data == 0)
        GoldPilotCharDB.tradingFilter = "all"
        ui:refresh()
        local row
        for _, data in ipairs(ui.widgets.list.data) do if data.item.name == "Ore" then row = data end end
        assert(row)
        for _, frame in ipairs(ui.widgets.list.rows) do
            if frame.data and frame.data.item.name == "Ore" then frame.scripts.OnClick(frame); break end
        end
        ui.personalButton.scripts.OnClick(ui.personalButton)
        assert(GoldPilotDB.personal.Ore == true)
        assert(ui.widgets.metrics.items[1].value.value == addon.Theme.money(40))
        assert(#ui.widgets.list.data == 1 and ui.widgets.list.data[1].item.name == "Potion")
        GoldPilotCharDB.tradingFilter = "personal"
        ui:refresh()
        assert(#ui.widgets.list.data == 1 and ui.widgets.list.data[1].item.name == "Ore")
        GoldPilotDB, GoldPilotCharDB = previousDB, previousChar
    end,
}
