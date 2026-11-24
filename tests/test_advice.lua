local function price(t, p50, qty)
    return { last = { t = t, p50 = p50, min = p50, qty = qty } }
end

local function inventoryDB(bags, prices, bank, chars)
    return {
        chars = chars or { A = { bags = bags or {}, bank = bank or {} } },
        prices = { h = prices or {} },
    }
end

local function card(result, id, where, char)
    for _, value in ipairs(result.cards) do
        if value.id == id and (where == nil or value.where == where)
            and (char == nil or value.char == char) then return value end
    end
end

return {
    ["consejos de subasta, correo, otros sitios y totales"] = function(addon, mock)
        mock.items = {
            [1] = { sell = 10, stack = 1, class = 0, bind = 0 },
            [2] = { sell = 20, stack = 1, class = 4, bind = 1 },
        }
        local db = inventoryDB({ [1] = 2, [2] = 1 }, { [1] = price(99990, 1000, 10) }, { [1] = 1 })
        db.chars.A.bound = { [2] = 1 }
        db.chars.A.seen = 80
        db.mailPending = { A = { t = 995, money = 500, items = 2 } }
        local inv = addon.Inventory.build(db, "h", "A", 1000, { where = "bags" })
        assert(#inv.rows == 2)
        local result = addon.Advice.build({ db = db, houseKey = "h", char = "A", now = 1000 })
        local auction, mail, bank = card(result, "auction"), card(result, "mail"), card(result, "elsewhere", "bank", "A")
        assert(auction and mail and bank)
        assert(mail.count == 2 and mail.gain == 500 and mail.confidence == 0.95)
        assert(bank.where == "bank" and bank.char == "A" and bank.seen == 80)
        assert(auction.items[1].forSale == 10 and db.chars.A.bags[1] == 2)
        assert(result.totals.now == auction.gain + mail.gain)
    end,
    ["inventario filtra sitio y timestamp"] = function(addon)
        local db = inventoryDB({ [1] = 1 }, { [1] = price(900, 1000, 10) }, { [1] = 2 })
        local bags = addon.Inventory.build(db, "h", "A", 1000, { where = "bags" })
        local bank = addon.Inventory.build(db, "h", "A", 1000, { where = "bank" })
        assert(#bags.rows == 1 and bags.rows[1].qty == 1 and bags.rows[1].t == 900)
        assert(#bank.rows == 1 and bank.rows[1].qty == 2 and bank.rows[1].t == 900)
    end,
    ["vendedor excluye ligados y sin precio vigente e incluye calidad cero"] = function(addon, mock)
        mock.items = {
            [1] = { sell = 100, stack = 1, class = 0 },
            [2] = { sell = 200, stack = 1, class = 0 },
            [3] = { sell = 300, stack = 1, class = 0 },
        }
        addon.Valuation.registerVendor(function(key) return ({ [1] = 100, [2] = 200, [3] = 300 })[key] end)
        local db = inventoryDB({ [1] = 2, [2] = 1, [3] = 1 }, {
            [1] = price(999, 100, 1), [2] = price(1, 1000, 1),
        })
        db.chars.A.bound = { [1] = 2 }
        local result = addon.Advice.build({ db = db, houseKey = "h", char = "A", now = 1000,
            quality = function(key) if key == 3 then return 0 end end })
        local vendor = card(result, "vendor")
        assert(vendor and vendor.count == 1 and vendor.gain == 300)
        assert(vendor.confidence == 1 and vendor.items[1].key == 3 and vendor.oldest == nil)
    end,
    ["dato caducado no genera subasta"] = function(addon, mock)
        mock.items[1] = { sell = 0, stack = 1, class = 0 }
        local db = inventoryDB({ [1] = 1 }, { [1] = price(1, 1000, 25) })
        local result = addon.Advice.build({ db = db, houseKey = "h", char = "A", now = 200000 })
        assert(card(result, "auction") == nil)
    end,
    ["orden por ganancia ponderada y minimo de ganancia"] = function(addon, mock)
        mock.items[1] = { sell = 1, stack = 1, class = 0 }
        mock.items[2] = { sell = 600, stack = 1, class = 0 }
        addon.Valuation.registerVendor(function(key) if key == 2 then return 600 end end)
        local db = inventoryDB({ [1] = 1, [2] = 1 }, { [1] = price(999, 1000, 1) })
        local result = addon.Advice.build({ db = db, houseKey = "h", char = "A", now = 1000,
            quality = function(key) if key == 2 then return 0 end end })
        assert(result.cards[1].id == "vendor" and result.cards[2].id == "auction")
        local low = inventoryDB({ [1] = 1 }, { [1] = price(999, 100, 1) })
        local hidden = addon.Advice.build({ db = low, houseKey = "h", char = "A", now = 1000,
            opts = { minGain = 1000 } })
        assert(card(hidden, "auction") == nil and hidden.totals.now == 0)
    end,
    ["refresh primero y despues de acciones"] = function(addon, mock)
        mock.items[1] = { sell = 1, stack = 1, class = 0 }
        mock.items[2] = { sell = 1, stack = 1, class = 0 }
        mock.items[3] = { sell = 1, stack = 1, class = 0 }
        local db = inventoryDB({ [1] = 1, [2] = 1, [3] = 1 }, {
            [1] = price(100000, 1000, 10), [2] = price(110000, 1000, 10), [3] = price(190000, 1000, 10),
        })
        local first = addon.Advice.build({ db = db, houseKey = "h", char = "A", now = 200000 })
        assert(first.cards[1].id == "refresh" and first.cards[1].count == 2 and first.cards[1].oldest == 100000)
        db.prices.h[1] = price(99990, 1000, 10)
        db.prices.h[2] = price(99995, 1000, 10)
        db.prices.h[3] = price(1, 1000, 10)
        local later = addon.Advice.build({ db = db, houseKey = "h", char = "A", now = 100000 })
        assert(later.cards[1].id == "auction" and later.cards[#later.cards].id == "refresh")
    end,
    ["limite de sitios conserva el total completo"] = function(addon, mock)
        mock.items[1] = { sell = 1, stack = 1, class = 0 }
        local chars = {
            A = { bags = {}, bank = { [1] = 1 } },
            B = { bags = { [1] = 2 }, bank = { [1] = 3 } },
            C = { bags = { [1] = 4 }, bank = {} },
        }
        local db = inventoryDB({}, { [1] = price(999, 1000, 10) }, nil, chars)
        local result = addon.Advice.build({ db = db, houseKey = "h", char = "A", now = 1000,
            opts = { maxPlaces = 1 } })
        assert(result.totals.elsewhere == 9500)
        local count = 0
        for _, value in ipairs(result.cards) do if value.id == "elsewhere" then count = count + 1 end end
        assert(count == 1)
    end,
    ["correo solo con oro y correo de otro personaje"] = function(addon)
        local db = { mailPending = {
            A = { t = 10, money = 50, items = 0 }, B = { t = 9, money = 70, items = 0 },
        } }
        local result = addon.Advice.build({ db = db, char = "A", now = 100 })
        assert(card(result, "mail") and card(result, "mail").count == 0)
        assert(card(result, "mail_other", nil, "B") and card(result, "mail_other").gain == 70)
        assert(result.totals.now == 50 and result.totals.mail == 120)
    end,
    ["tendencias usan unidades en venta y valor del cambio"] = function(addon, mock)
        mock.items[1] = { sell = 1, stack = 1, class = 0 }
        mock.items[2] = { sell = 1, stack = 1, class = 0 }
        mock.items[3] = { sell = 1, stack = 1, class = 0 }
        local now = 10 * 86400 + 100
        local db = inventoryDB({ [1] = 1, [2] = 1, [3] = 1 }, {})
        for key, values in pairs({ [1] = { 120, 20 }, [2] = { 80, 25 }, [3] = { 150, 19 } }) do
            local current, qty = values[1], values[2]
            addon.Prices.record(db, "h", key, { min = 100, p50 = 100, qty = qty }, now - 2 * 86400)
            addon.Prices.record(db, "h", key, { min = current, p50 = current, qty = qty }, now)
        end
        local result = addon.Advice.build({ db = db, houseKey = "h", char = "A", now = now })
        local up, down = card(result, "trend_up"), card(result, "trend_down")
        assert(up and up.count == 1 and up.gain == 20 and up.oldest == now)
        assert(up.items[1].value == 20 and up.items[1].percent == 20 and up.items[1].forSale == 20)
        assert(down and down.count == 1 and down.gain == -20)
        assert(down.items[1].value == -20 and down.items[1].percent == -20 and down.items[1].forSale == 25)
    end,
    ["consejos vacios y correo expirado"] = function(addon)
        local empty = addon.Advice.build({ db = {}, char = "A", now = 1000 })
        assert(#empty.cards == 0 and empty.totals.now == 0 and empty.totals.mail == 0)
        local expired = addon.Advice.build({ db = { mailPending = {
            A = { t = 1, money = 100, items = 1, expires = 999 },
        } }, char = "A", now = 1000 })
        assert(#expired.cards == 0 and expired.totals.mail == 0)
    end,
    ["no muta la base de datos"] = function(addon, mock)
        mock.items[1] = { sell = 1, stack = 1, class = 0 }
        local db = inventoryDB({ [1] = 2 }, { [1] = price(999, 1000, 10) })
        local beforeT, beforeBags = db.prices.h[1].last.t, db.chars.A.bags[1]
        addon.Advice.build({ db = db, houseKey = "h", char = "A", now = 1000 })
        assert(db.prices.h[1].last.t == beforeT and db.chars.A.bags[1] == beforeBags)
    end,
    ["foto del buzón" ] = function(addon, mock)
        local oldCount, oldHeader = GetInboxNumItems, GetInboxHeaderInfo
        local oldTime, oldUnit = time, UnitName
        local mails = {
            { money = 25, hasItem = 1, cod = 0, daysLeft = 2 },
            { money = 0, hasItem = 1, cod = 50, daysLeft = 1 },
        }
        GetInboxNumItems = function() return #mails, 8 end
        GetInboxHeaderInfo = function(i)
            local m = mails[i]
            return nil, nil, "S", nil, m.money, m.cod, m.daysLeft, m.hasItem
        end
        time = function() return 1000 end
        UnitName = function() return "A" end
        GoldPilotDB = {}
        addon.Modules:enableAll()
        mock.fire("MAIL_SHOW")
        mock.fire("MAIL_INBOX_UPDATE")
        assert(GoldPilotDB.mailPending.A.money == 25 and GoldPilotDB.mailPending.A.items == 1)
        assert(GoldPilotDB.mailPending.A.total == 8 and GoldPilotDB.mailPending.A.expires == 173800)
        mock.fire("MAIL_CLOSED")
        mails[1].money = 99
        mock.fire("MAIL_INBOX_UPDATE")
        assert(GoldPilotDB.mailPending.A.money == 25)
        GetInboxNumItems, GetInboxHeaderInfo, time, UnitName = oldCount, oldHeader, oldTime, oldUnit
    end,
}
