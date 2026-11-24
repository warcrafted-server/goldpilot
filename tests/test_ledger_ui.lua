local function detailText(panel)
    local values = {}
    for _, label in ipairs(panel.labels or {}) do
        if not label.hidden then values[#values + 1] = label.value end
    end
    return table.concat(values, " ")
end

return {
    ["ledger UI calcula metricas y filas segun periodo y personaje"] = function(addon)
        local originalDB, originalCharDB = GoldPilotDB, GoldPilotCharDB
        GoldPilotDB = { ledger = { [1970] = {
            { t = 100, char = "Player", kind = "sell", name = "Mixed", itemID = 25, qty = 3,
                gross = 300, deposit = 30, cut = 15, net = 315 },
            { t = 110, char = "Alt", kind = "buy", name = "Mixed", itemID = 25, qty = 2,
                gross = 100, net = -100 },
            { t = -800000, char = "Player", kind = "sell", name = "Old", qty = 1,
                gross = 500, cut = 25, net = 475 },
        } } }
        GoldPilotCharDB = {}
        addon.Main:show()
        addon.Main.tabsBar:select("ledger")
        local ui = addon.LedgerUI
        assert(ui.period == 30 and ui.account and GoldPilotCharDB.ledgerAccount == true)
        assert(ui.widgets.metrics.items[1].value.value == addon.Theme.money(800))
        assert(ui.widgets.metrics.items[2].value.value == addon.Theme.money(40))
        assert(ui.widgets.metrics.items[3].value.value == addon.Theme.money(100))
        assert(ui.widgets.metrics.items[4].value.value:sub(1, 1) == "+")
        local row
        for _, value in ipairs(ui.widgets.list.data) do if value.item.name == "Mixed" then row = value end end
        assert(row.item.name == "Mixed" and row.right:sub(1, 1) == "+")
        assert(row.rightColor[1] == 0.35)
        ui.periodButton.scripts.OnClick(ui.periodButton)
        assert(GoldPilotCharDB.ledgerPeriod == 0)
        ui.periodButton.scripts.OnClick(ui.periodButton)
        assert(GoldPilotCharDB.ledgerPeriod == 7 and #ui.widgets.list.data == 1)
        ui.scopeButton.scripts.OnClick(ui.scopeButton)
        assert(GoldPilotCharDB.ledgerAccount == false and #ui.widgets.list.data == 1)
        assert(ui.widgets.list.data[1].item.balance == 315)
        GoldPilotDB, GoldPilotCharDB = originalDB, originalCharDB
    end,
    ["ledger UI muestra fichas mixtas, devoluciones, seleccion y textos vacios"] = function(addon)
        local originalDB, originalCharDB = GoldPilotDB, GoldPilotCharDB
        GoldPilotDB = { ledger = { [1970] = {
            { t = 199900, char = "Alt", kind = "sell", name = "Mixed", itemID = 25, qty = 3,
                gross = 300, deposit = 30, cut = 15, net = 315 },
            { t = 199910, char = "Player", kind = "buy", name = "Mixed", itemID = 25, qty = 2,
                gross = 100, net = -100 },
            { t = 199920, char = "Alt", kind = "return", name = "Mixed", qty = 1, net = 0 },
            { t = 199930, char = "Player", kind = "sell", name = "SaleOnly", qty = 1,
                gross = 40, deposit = 2, cut = 2, net = 40 },
            { t = 199940, char = "Player", kind = "buy", name = "BuyOnly", qty = 1,
                gross = 20, net = -20 },
            { t = 199950, char = "Player", kind = "return", name = "ReturnOnly", qty = 1, net = 0 },
        } } }
        GoldPilotCharDB = { ledgerAccount = true, ledgerPeriod = 30 }
        addon.Main:show()
        addon.Main.tabsBar:select("ledger")
        local ui, list = addon.LedgerUI, addon.LedgerUI.widgets.list
        local function selectItem(name)
            for _, row in ipairs(list.rows) do
                if row.data and row.data.item.name == name then row.scripts.OnClick(row); return end
            end
            error("No se encontro " .. name)
        end
        selectItem("Mixed")
        local text = detailText(ui.widgets.detail)
        assert(text:find(addon.L.LEDGER_SALES, 1, true) and text:find(addon.L.LEDGER_PURCHASES, 1, true), text)
        assert(text:find(addon.L.LEDGER_BY_CHARACTER, 1, true) and text:find(addon.L.LEDGER_RECENT, 1, true))
        assert(text:find(string.format(addon.L.LEDGER_SALE, 3), 1, true))
        assert(text:find(string.format(addon.L.LEDGER_PURCHASE, 2), 1, true))
        assert(text:find(string.format(addon.L.LEDGER_RETURN, 1), 1, true))
        assert(ui.selectedName == "Mixed")
        selectItem("SaleOnly")
        text = detailText(ui.widgets.detail)
        assert(text:find(addon.L.LEDGER_SALES, 1, true) and not text:find(addon.L.LEDGER_PURCHASES, 1, true))
        selectItem("BuyOnly")
        text = detailText(ui.widgets.detail)
        assert(text:find(addon.L.LEDGER_PURCHASES, 1, true) and not text:find(addon.L.LEDGER_SALES, 1, true))
        selectItem("ReturnOnly")
        text = detailText(ui.widgets.detail)
        assert(text:find(addon.L.LEDGER_RETURNED, 1, true))
        selectItem("Mixed")
        local original = addon.L
        for _, language in ipairs({ "enUS", "esES" }) do
            addon.L = addon.LocaleStrings[language]
            ui:refresh()
            assert(ui.widgets.detail.labels[1].value == "Mixed")
        end
        addon.L = original
        GoldPilotDB.ledger[1970] = {}
        ui:refresh()
        assert(ui.selectedName == nil and addon.Main.pages.ledger.emptyText.value == addon.L.LEDGER_EMPTY,
            tostring(ui.selectedName) .. ":" .. tostring(addon.Main.pages.ledger.emptyText.value))
        GoldPilotDB.ledger[1970][1] = { t = -5000000, char = "Alt", kind = "sell", name = "Old",
            qty = 1, gross = 100, net = 95 }
        ui:refresh()
        assert(addon.Main.pages.ledger.emptyText.value == addon.L.LEDGER_EMPTY_PERIOD)
        GoldPilotDB, GoldPilotCharDB = originalDB, originalCharDB
    end,
    ["ledger UI no modifica controles ni refresca durante combate"] = function(addon, mock)
        local originalDB, originalCharDB = GoldPilotDB, GoldPilotCharDB
        GoldPilotDB = { ledger = { [1970] = { { t = 199900, char = "Player", kind = "sell",
            name = "Item", qty = 1, gross = 10, cut = 1, net = 9 } } } }
        GoldPilotCharDB = { ledgerAccount = true, ledgerPeriod = 30 }
        addon.Main:show()
        addon.Main.tabsBar:select("ledger")
        local ui = addon.LedgerUI
        local count = #ui.widgets.list.rows
        mock.combat = true
        assert(not ui:refresh())
        ui.scopeButton.scripts.OnClick(ui.scopeButton)
        ui.periodButton.scripts.OnClick(ui.periodButton)
        assert(GoldPilotCharDB.ledgerAccount and GoldPilotCharDB.ledgerPeriod == 30)
        assert(#ui.widgets.list.rows == count)
        mock.combat = false
        GoldPilotDB, GoldPilotCharDB = originalDB, originalCharDB
    end,
}
