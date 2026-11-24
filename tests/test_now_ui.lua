local function setCards(addon, cards)
    addon.Advice.build = function()
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
        assert(addon.NowUI.widgets.cards.width == 420 and addon.NowUI.widgets.cards.height == 390)
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
}
