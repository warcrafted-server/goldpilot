return {
    ["inventory combina personajes, banco y limita reservas"] = function(addon, mock)
        mock.items = { [1] = { sell = 100, stack = 1, class = 0, bind = 0 }, [2] = { sell = nil, stack = 1, class = 0, bind = 0 } }
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
    ["inventory ordena valor, reserva vendible y etiqueta antiguedad y comision"] = function(addon, mock)
        mock.items = { [1] = { sell = 100, stack = 1, class = 0, bind = 0 }, [2] = { sell = 500, stack = 1, class = 0, bind = 0 }, [3] = { sell = nil, stack = 1, class = 0, bind = 0 } }
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
    ["inventory separa variantes, reserva libres y valora ligados solo al vendedor"] = function(addon, mock)
        mock.items = { [100] = { sell = 20, stack = 1, class = 4, bind = 0 } }
        local db = { chars = { A = {
            bags = { ["100:1"] = 3, ["100:2"] = 2 },
            bound = { ["100:1"] = 1, ["100:2"] = 2 },
        } }, reserved = { [100] = 9, ["100:1"] = 1 }, prices = { h = {
            ["100:1"] = { last = { t = 1000, p50 = 100, min = 100, qty = 1 } },
        } } }
        local built = addon.Inventory.build(db, "h", nil, 1100)
        assert(#built.rows == 2)
        local first = built.rows[1].key == "100:1" and built.rows[1] or built.rows[2]
        local second = built.rows[1].key == "100:2" and built.rows[1] or built.rows[2]
        assert(first.qtyBound == 1 and first.qtyReserved == 1 and first.qtyAuction == 1)
        assert(first.valueAuction == 95 and first.valueVendor == 40 and first.valueBest == 115)
        assert(second.qtyBound == 2 and second.action == "vendor" and second.valueAuction == 0)
        assert(second.qtyReserved == 0 and second.valueBest == 40)
    end,
    ["inventory incluye objetos nunca vistos con precio de subasta"] = function(addon, mock)
        mock.items = {}
        local built = addon.Inventory.build({ chars = { Player = { bags = { [2973] = 2 } } },
            prices = { h = { [2973] = { last = { t = 90, p50 = 500, min = 400, qty = 2 } } } } }, "h", nil, 100)
        assert(#built.rows == 1 and built.rows[1].qtyBound == 0)
        assert(built.rows[1].ahUnit == 500 and built.rows[1].action == "auction")
    end,
}
