return {
    ["inventory combina personajes, banco y limita reservas"] = function(addon)
        addon.DataItems = { [1] = "100;1;0;0;0", [2] = "0;1;0;0;0" }
        local db = { chars = {
            Alice = { bags = { [1] = 4, [2] = 2 }, bank = { [1] = 3 } },
            Bob = { bags = { [1] = 5 }, bank = { [1] = 6 } },
        }, reserved = { [1] = 99 }, prices = { h = { [1] = { last = { t = 2000, p50 = 200, min = 180, qty = 10 } } } } }
        local built = addon.Inventory.build(db, "h", nil, 2100)
        assert(#built.rows == 2)
        local row = built.rows[1]
        assert(row.itemID == 1 and row.qty == 18 and row.qtyReserved == 18 and row.qtySellable == 0)
        assert(#row.breakdown == 4 and built.totals.reserved == 1)
        assert(built.rows[2].itemID == 2 and built.rows[2].action == "none")
        assert(built.totals.withoutPrice == 1)
        local character = addon.Inventory.build(db, "h", "Alice", 2100)
        assert(#character.rows == 2 and character.rows[1].qty == 7)
    end,
    ["inventory ordena valor, reserva vendible y etiqueta antiguedad y comision"] = function(addon)
        addon.DataItems = { [1] = "100;1;0;0;0", [2] = "500;1;0;0;0", [3] = "0;1;0;0;0" }
        local db = { chars = { A = { bags = { [1] = 2, [2] = 1, [3] = 1 } } },
            reserved = { [1] = 1 }, prices = { h = {
                [1] = { last = { t = 200000, p50 = 300, min = 250, qty = 8 } },
                [2] = { last = { t = 1, p50 = 900, min = 800, qty = 2 } },
            } } }
        local built = addon.Inventory.build(db, "h", nil, 200100)
        assert(built.rows[1].itemID == 2 and built.rows[1].action == "vendor")
        assert(built.rows[1].stale and built.rows[1].age == 200099)
        assert(built.rows[2].itemID == 1 and built.rows[2].action == "auction")
        assert(built.rows[2].qtySellable == 1 and built.rows[2].cutAssumed)
        assert(built.rows[3].action == "none")
    end,
}
