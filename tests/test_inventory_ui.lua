return {
    ["inventory construye lista, filtra, cambia ambito y reserva y sigue"] = function(addon, mock)
        addon.DataItems = { [10] = "100;1;0;0;0", [11] = "50;1;0;0;0" }
        GoldPilotDB = { chars = { Player = { bags = { [10] = 2 } }, Other = { bank = { [11] = 3 } } } }
        addon.Main:show()
        local ui = addon.InventoryUI
        local page = addon.Main.pages.inventory
        assert(page and ui.widgets.list.data[1].itemID == 10)
        ui.scopeButton.scripts.OnClick(ui.scopeButton)
        assert(#ui.widgets.list.data == 2)
        ui.filterBox:SetText("[10]")
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
        addon.DataItems = { [10] = "100;1;0;0;0" }
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
}
