local function setCards(addon, cards)
    addon.Advice.build = function(context)
        addon.NowUI.lastAdviceContext = context
        return { cards = cards, totals = { now = 25, mail = 10, elsewhere = 15 } }
    end
    addon.NowUI:refresh()
end

local function card(id, fields)
    fields = fields or {}
    fields.id = id
    fields.kind = fields.kind or "action"
    fields.gain = fields.gain or 50
    fields.confidence = fields.confidence or 0.8
    fields.count = fields.count == nil and 2 or fields.count
    fields.items = fields.items or {}
    return fields
end

local function lines(panel)
    local result = {}
    for _, label in ipairs(panel.labels or {}) do
        if not label.hidden then result[#result + 1] = label.value end
    end
    return table.concat(result, " ")
end

return {
    ["Now abre inicialmente y vacía ficha, tarjetas y botón si no hay consejos"] = function(addon)
        GoldPilotDB = { prices = {} }
        addon.Main:show()
        assert(addon.Main.activeTab == "now")
        assert(addon.Main.pages.now.emptyText.value == addon.L.NOW_EMPTY_SCAN)
        assert(addon.NowUI.widgets.cards.width == 420 and addon.NowUI.widgets.cards.height == 356)
        assert(addon.NowUI.widgets.detail.lines and #addon.NowUI.widgets.detail.lines == 0)
        assert(addon.NowUI.inventoryButton.hidden)
        GoldPilotDB.prices = { h = { item = {} } }
        addon.NowUI:refresh()
        assert(addon.Main.pages.now.emptyText.value == addon.L.NOW_EMPTY)
    end,
    ["Now conserva la selección, la pinta y la repone cuando desaparece"] = function(addon)
        addon.Main:show()
        setCards(addon, { card("auction"), card("vendor") })
        local cards = addon.NowUI.widgets.cards
        assert(cards.selectedKey == "auction||")
        assert(cards.items[1].fill.color[1] == 0.2)
        assert(cards.items[2].fill.color[1] == 0.04)
        assert(cards.items[1].title.wordWrap == false and cards.items[1].reason.wordWrap == false)
        cards.items[2].scripts.OnClick(cards.items[2])
        assert(cards.selectedKey == "vendor||")
        assert(cards.items[2].fill.color[1] == 0.2)
        setCards(addon, { card("vendor"), card("auction") })
        assert(cards.selectedKey == "vendor||")
        setCards(addon, { card("auction") })
        assert(cards.selectedKey == "auction||")
    end,
    ["Now limita a seis tarjetas y bloquea refresco durante combate"] = function(addon, mock)
        addon.Main:show()
        local cards = {}
        for i = 1, 8 do cards[i] = card("kind" .. i) end
        setCards(addon, cards)
        local widget = addon.NowUI.widgets.cards
        assert(#widget.data == 6 and #widget.items == 6)
        local count = #widget.items
        mock.combat = true
        assert(not addon.NowUI:refresh())
        assert(#widget.items == count)
        mock.combat = false
    end,
    ["Now dibuja todos los tipos de tarjeta en ambos idiomas"] = function(addon)
        addon.Main:show()
        local originals = addon.L
        local variants = {
            card("auction", { count = 1 }), card("auction", { crowded = true }), card("vendor", { count = 3 }),
            card("mail", { count = 0, gain = 20, seen = 199000 }),
            card("mail", { count = 1, gain = 0, seen = 199000 }),
            card("mail", { count = 2, gain = 20, seen = 0 }), card("mail_other", { char = "Alt", count = 1, gain = 0 }),
            card("elsewhere", { char = "Alt", where = "bank", count = 1, seen = 199000 }),
            card("elsewhere", { char = "Alt", where = "bank", count = 2, seen = 0 }),
            card("elsewhere", { char = "Alt", where = "bags", count = 1, seen = 199000 }),
            card("elsewhere", { char = "Alt", where = "bags", count = 2, seen = 0 }),
            card("trend_up", { kind = "info", gain = 12, count = 1, items = { { itemID = 25, key = "25", qty = 3, value = 12, percent = 18 } } }),
            card("trend_down", { kind = "info", gain = -12, count = 2, items = { { itemID = 25, key = "25", qty = 3, value = -12, percent = -18 } } }),
            card("zone", { kind = "info", gain = 1900, count = 2, active = 3600, mapID = 6,
                items = { { mapID = 6, value = 1900, active = 3600 } } }),
            card("refresh", { kind = "refresh", gain = 0, count = 1 }),
        }
        for _, language in ipairs({ "enUS", "esES" }) do
            addon.L = addon.LocaleStrings[language]
            for _, fixture in ipairs(variants) do
                setCards(addon, { fixture })
                assert(addon.NowUI.widgets.cards.items[1].title.value ~= "")
                assert(addon.NowUI.widgets.cards.items[1].reason.value ~= "")
                assert(#addon.NowUI.widgets.detail.lines > 0)
                if fixture.id == "refresh" then
                    assert(addon.NowUI.widgets.cards.items[1].confidence.value == "")
                    assert(addon.NowUI.widgets.detail.labels[2].value == addon.L.NOW_WHY)
                end
                local shouldShow = fixture.id == "auction" or fixture.id == "vendor" or fixture.id == "elsewhere"
                assert(addon.NowUI.inventoryButton.hidden ~= shouldShow)
            end
            local plural = card("auction", { count = 4 })
            setCards(addon, { plural })
            assert(addon.NowUI.widgets.cards.items[1].title.value == string.format(addon.L.NOW_AUCTION, 4))
            local singular = card("auction", { count = 1 })
            setCards(addon, { singular })
            assert(addon.NowUI.widgets.cards.items[1].title.value == string.format(addon.L.NOW_AUCTION_ONE, 1))
            local vendorPlural = card("vendor", { count = 4 })
            setCards(addon, { vendorPlural })
            assert(addon.NowUI.widgets.cards.items[1].title.value == string.format(addon.L.NOW_VENDOR, 4))
            local vendorSingular = card("vendor", { count = 1 })
            setCards(addon, { vendorSingular })
            assert(addon.NowUI.widgets.cards.items[1].title.value == string.format(addon.L.NOW_VENDOR_ONE, 1))
            local bagsSeen = card("elsewhere", { char = "Alt", where = "bags", count = 1, seen = 199000 })
            setCards(addon, { bagsSeen })
            local bagsWhy = string.format(addon.L.NOW_WHY_ELSEWHERE, "Alt", addon.L.NOW_PLACE_BAGS,
                addon.Theme.age(1000))
            assert(lines(addon.NowUI.widgets.detail):find(bagsWhy, 1, true))
            local seen = card("elsewhere", { char = "Alt", where = "bank", count = 1, seen = 0 })
            setCards(addon, { seen })
            assert(addon.NowUI.widgets.cards.items[1].reason.value == addon.L.NOW_REASON_ELSEWHERE_ONE)
            local bank = addon.L.NOW_PLACE_BANK
            local whereText = string.format(addon.L.NOW_WHY_ELSEWHERE_NEVER, "Alt", bank)
            assert(lines(addon.NowUI.widgets.detail):find(whereText, 1, true))
            seen.count = 3
            setCards(addon, { seen })
            assert(addon.NowUI.widgets.cards.items[1].reason.value == string.format(addon.L.NOW_REASON_ELSEWHERE, 3))
        end
        addon.L = originals
    end,
    ["Now muestra cantidades con multiplicación, limita confianza de refresh y limpia ausencia"] = function(addon)
        addon.Main:show()
        local auction = card("auction", { items = { { itemID = 25, key = "25", qty = 4, value = 100 } } })
        setCards(addon, { auction })
        assert(lines(addon.NowUI.widgets.detail):find("×4", 1, true))
        local refresh = card("refresh", { kind = "refresh", gain = 0 })
        setCards(addon, { refresh })
        assert(addon.NowUI.widgets.cards.items[1].confidence.value == "")
        assert(addon.NowUI.widgets.detail.values[2] == nil or addon.NowUI.widgets.detail.values[2].hidden)
        setCards(addon, {})
        assert(addon.NowUI.selected == nil and addon.NowUI.widgets.cards.selectedKey == nil)
        assert(#addon.NowUI.widgets.detail.lines == 0 and addon.NowUI.inventoryButton.hidden)
    end,
    ["Now abre Inventario y activa cuenta solo para otro personaje"] = function(addon)
        addon.Main:show()
        setCards(addon, { card("elsewhere", { char = "Player", where = "bank" }) })
        addon.NowUI.inventoryButton.scripts.OnClick(addon.NowUI.inventoryButton)
        assert(addon.Main.activeTab == "inventory" and addon.InventoryUI.account == false)
        addon.Main.tabsBar:select("now")
        setCards(addon, { card("elsewhere", { char = "Alt", where = "bags" }) })
        addon.NowUI.inventoryButton.scripts.OnClick(addon.NowUI.inventoryButton)
        assert(addon.Main.activeTab == "inventory" and addon.InventoryUI.account == true)
    end,
    ["Now alterna el ámbito, lo guarda y refresca el texto"] = function(addon)
        local original = GoldPilotCharDB
        GoldPilotCharDB = nil
        addon.Main:show()
        setCards(addon, {})
        local button = addon.NowUI.scopeButton
        assert(GoldPilotCharDB.nowAccount == false)
        assert(button.value == addon.L.INVENTORY_SCOPE_CHARACTER)
        assert(button.width == 150 and button.height == 24 and button.x == 16 and button.y == 20)
        assert(addon.NowUI.lastAdviceContext.account == false)
        assert(button.scripts.OnEnter and button.scripts.OnLeave)
        button.scripts.OnClick(button)
        assert(GoldPilotCharDB.nowAccount == true and button.value == addon.L.INVENTORY_SCOPE_ACCOUNT)
        assert(addon.NowUI.lastAdviceContext.account == true)
        GoldPilotCharDB = original
    end,
    ["Now no alterna el ámbito en combate"] = function(addon, mock)
        local original = GoldPilotCharDB
        GoldPilotCharDB = { nowAccount = false }
        addon.Main:show()
        local button = addon.NowUI.scopeButton
        mock.combat = true
        button.scripts.OnClick(button)
        assert(GoldPilotCharDB.nowAccount == false)
        assert(button.value == addon.L.INVENTORY_SCOPE_CHARACTER)
        mock.combat = false
        GoldPilotCharDB = original
    end,
    ["Now dibuja el consejo de zona con el nombre del mapa y su lista"] = function(addon)
        addon.Main:show()
        local original = C_Map
        C_Map = { GetMapInfo = function(id) return { name = "Zona " .. id } end }
        local zone = card("zone", { kind = "info", gain = 1900, count = 2, active = 3600, mapID = 6,
            confidence = 0.9, items = { { mapID = 6, value = 1900, active = 3600 },
                { mapID = 5, value = 950, active = 1800 } } })
        setCards(addon, { zone })
        local widget = addon.NowUI.widgets.cards
        assert(widget.items[1].title.value == string.format(addon.L.NOW_ZONE, "Zona 6"))
        assert(widget.items[1].amount.value == "+" .. addon.Theme.money(1900) .. addon.L.NOW_PER_HOUR)
        assert(widget.items[1].reason.value == string.format(addon.L.NOW_REASON_ZONE, 60))
        assert(addon.NowUI.inventoryButton.hidden)
        local text = lines(addon.NowUI.widgets.detail)
        assert(text:find(addon.L.NOW_WHY_ZONE, 1, true))
        assert(text:find(addon.L.NOW_ZONES_TOP, 1, true))
        assert(text:find(string.format(addon.L.NOW_ZONE_LINE, "Zona 6", 60), 1, true))
        assert(text:find(string.format(addon.L.NOW_ZONE_LINE, "Zona 5", 30), 1, true))
        C_Map = nil
        setCards(addon, { zone })
        assert(widget.items[1].title.value == string.format(addon.L.NOW_ZONE,
            string.format(addon.L.NOW_ZONE_UNKNOWN, 6)))
        C_Map = original
    end,
    ["Now pasa la sesión y los objetos subastables a los consejos"] = function(addon)
        addon.Main:show()
        GoldPilotCharDB = GoldPilotCharDB or {}
        local session = { char = "Player", last = 200000, maps = {} }
        GoldPilotCharDB.session = session
        setCards(addon, {})
        assert(addon.NowUI.lastAdviceContext.session == session)
        assert(addon.NowUI.lastAdviceContext.auctionable == addon.ItemData.auctionable)
    end,
}
