return {
    ["inventory construye lista, filtra, cambia ambito y reserva y sigue"] = function(addon, mock)
        mock.items = { [10] = { sell = 100, stack = 1, class = 0, bind = 0 }, [11] = { sell = 50, stack = 1, class = 0, bind = 0 } }
        GoldPilotDB = { chars = { Player = { bags = { [10] = 2 } }, Other = { bank = { [11] = 3 } } } }
        addon.Main:show()
        local ui = addon.InventoryUI
        local page = addon.Main.pages.inventory
        assert(page and ui.widgets.list.data[1].itemID == 10)
        ui.scopeButton.scripts.OnClick(ui.scopeButton)
        assert(#ui.widgets.list.data == 2)
        ui.filterBox:SetText("10")
        ui.filterBox.scripts.OnTextChanged(ui.filterBox)
        assert(#ui.widgets.list.data == 1)
        ui.filterBox:SetText("")
        ui.filterBox.scripts.OnTextChanged(ui.filterBox)
        local row = ui.widgets.list.rows[1]
        row.scripts.OnClick(row)
        ui.reserveButton.scripts.OnClick(ui.reserveButton)
        assert(GoldPilotDB.reserved[10] == 2)
        ui.watchButton.scripts.OnClick(ui.watchButton)
        assert(GoldPilotDB.watch[10] == true)
        ui.reserveButton.scripts.OnClick(ui.reserveButton)
        assert(GoldPilotDB.reserved[10] == nil)
        assert(#ui.widgets.detail.lines > 0)
    end,
    ["inventory muestra estado vacio y no cambia datos en combate"] = function(addon, mock)
        mock.items = { [10] = { sell = 100, stack = 1, class = 0, bind = 0 } }
        GoldPilotDB = { chars = {} }
        addon.Main:show()
        local ui = addon.InventoryUI
        assert(addon.Main.pages.inventory.emptyText.value == addon.L.INVENTORY_EMPTY_PRICES)
        local original = ui.account
        mock.combat = true
        ui.scopeButton.scripts.OnClick(ui.scopeButton)
        assert(ui.account == original)
        assert(not ui:refresh())
    end,
    ["inventory reserva variante por clave y limpia selección al desaparecer"] = function(addon, mock)
        mock.items = { [100] = { sell = 1, stack = 1, class = 4, bind = 0 } }
        GoldPilotDB = { chars = { Player = { bags = { ["100:222"] = 2 } } }, links = {
            ["100:222"] = "item:100::::::::::::1:222",
        } }
        addon.Main:show()
        local ui = addon.InventoryUI
        assert(ui.widgets.list.data[1].key == "100:222")
        ui.widgets.list.rows[1].scripts.OnClick(ui.widgets.list.rows[1])
        ui.reserveButton.scripts.OnClick(ui.reserveButton)
        assert(GoldPilotDB.reserved["100:222"] == 2 and GoldPilotDB.reserved[100] == nil)
        GoldPilotDB.chars.Player.bags["100:222"] = nil
        ui:refresh()
        assert(ui.selected == nil)
    end,
}
