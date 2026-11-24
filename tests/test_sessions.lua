local clock = 200000

local function withPrices(entries)
    local db = { prices = { Horde = {} }, houses = { Horde = { cut = 0.05 } } }
    for key, entry in pairs(entries) do
        db.prices.Horde[key] = { last = { t = entry.t or 100000, min = entry.min or entry.p50,
            p50 = entry.p50, qty = entry.qty or 10 } }
    end
    return db
end

local function setupLoot(addon, mock)
    mock.loot = {}
    mock.fishing = false
    mock.mapID, mock.mapX, mock.mapY = 1, 0.5, 0.5
    mock.enableLoot()
    clock = 200000
    time = function() return clock end
    -- Estas pruebas cuentan solo los temporizadores del botín, no los del panel de sesión.
    GoldPilotDB, GoldPilotCharDB = { settings = { hud = false } }, {}
    addon.Modules:enableAll()
end

local function itemSlot(guid, amount, itemID)
    return { link = "item:" .. itemID, sources = { { guid = guid, qty = amount } } }
end

local function moneySlot(guid, amount)
    return { sources = { { guid = guid, qty = amount } } }
end

local function sessionTemplate(lastMap, active)
    local session = { char = "Ana", start = 0, last = 0, active = active, coin = 0, loots = 0, nodes = 0,
        items = {}, lastMap = lastMap, maps = { [lastMap] = { active = 0, coin = 0, items = {} } } }
    return session
end

return {
    ["sesiones suman tiempo hasta el tope de 180 s y lo atribuyen al mapa anterior"] = function(addon)
        local session = addon.Sessions.add(nil, { char = "Ana", mapID = 1, coin = 10, items = { [25] = 1 } }, 1000)
        assert(session.start == 1000 and session.last == 1000 and session.active == 0)
        assert(session.lastMap == 1 and session.coin == 10 and session.loots == 1 and session.items[25] == 1)
        assert(addon.Sessions.add(session, { char = "Ana", mapID = 2, coin = 5, items = { [25] = 1 } }, 1300) == session)
        assert(session.active == 180 and session.maps[1].active == 180 and session.maps[2].active == 0)
        assert(session.maps[1].coin == 10 and session.maps[2].coin == 5 and session.maps[2].items[25] == 1)
        assert(session.coin == 15 and session.loots == 2 and session.items[25] == 2)
        assert(session.last == 1300 and session.lastMap == 2)
        assert(addon.Sessions.active(session, 1400) == 280)
        local duplicate = addon.Sessions.add(session, { mapID = 3, coin = 0, items = {} }, 1500)
        assert(duplicate == session and session.last == 1300 and session.loots == 2 and session.maps[3] == nil)
        assert(addon.Sessions.add(nil, { mapID = 1 }, 1000) == nil)
        assert(addon.Sessions.add(session, { mapID = 2, coin = 1, node = true }, 1301) == session)
        assert(session.nodes == 1 and session.loots == 3)
    end,
    ["cerrar descarta sesiones cortas, añade la cola y conserva cincuenta"] = function(addon)
        local db = {}
        local short = sessionTemplate(3, 100)
        assert(addon.Sessions.close(db, short, 100) == false)
        assert(short.active == 200 and short.maps[3].active == 100 and short.stop == 0 and db.sessions == nil)
        local long = sessionTemplate(3, 200)
        assert(addon.Sessions.close(db, long, 1000) == true)
        assert(long.active == 380 and long.maps[3].active == 180 and long.stop == 0)
        assert(#db.sessions == 1 and db.sessions[1] == long)
        for index = 1, 55 do
            assert(addon.Sessions.close(db, sessionTemplate(4, 400), index) == true)
            db.sessions[#db.sessions].start = index
        end
        assert(#db.sessions == 50 and db.sessions[1].start == 6 and db.sessions[50].start == 55)
        assert(addon.Sessions.close(db, nil, 0) == false)
        assert(addon.Sessions.expired({ last = 0 }, 900) == true)
        assert(addon.Sessions.expired({ last = 0 }, 899) == false)
        assert(addon.Sessions.expired(nil, 900) == false)
    end,
    ["valor distingue subasta neta, vendedor, ligado, poco listado, sin precio y dinero"] = function(addon)
        addon.Valuation.registerVendor(function(key)
            local itemID = addon.ItemKey.itemID(key)
            return ({ [200] = 300, [300] = 400 })[itemID]
        end)
        local db = withPrices({
            [100] = { p50 = 1000, qty = 10 },
            [200] = { p50 = 1000, qty = 1 },
            [300] = { p50 = 1000, qty = 10 },
        })
        local auctionable = function(itemID) return itemID ~= 300 end
        local price, kind = addon.Sessions.unit(db, "Horde", 100, 100000, auctionable)
        assert(price == 950 and kind == "auction")
        price, kind = addon.Sessions.unit(db, "Horde", 200, 100000, auctionable)
        assert(price == 300 and kind == "vendor")
        price, kind = addon.Sessions.unit(db, "Horde", 300, 100000, auctionable)
        assert(price == 400 and kind == "vendor")
        price, kind = addon.Sessions.unit(db, "Horde", 400, 100000, auctionable)
        assert(price == nil and kind == "none")
        local value = addon.Sessions.value(db, "Horde",
            { coin = 1234, items = { [100] = 2, [200] = 1, [300] = 1, [400] = 1 } }, 100000, auctionable)
        assert(value.coin == 1234 and value.auction == 1900 and value.vendor == 700 and value.unpriced == 1)
        assert(value.total == 3834 and #value.rows == 4)
        assert(value.rows[1].key == 100 and value.rows[1].itemID == 100 and value.rows[1].qty == 2)
        assert(value.rows[1].unit == 950 and value.rows[1].value == 1900 and value.rows[1].kind == "auction")
        assert(value.rows[2].key == 300 and value.rows[2].value == 400)
        assert(value.rows[3].key == 200 and value.rows[3].value == 300 and value.rows[3].kind == "vendor")
        assert(value.rows[4].key == 400 and value.rows[4].value == 0 and value.rows[4].kind == "none")
        assert(addon.Sessions.rate(3600, 3600) == 3600 and addon.Sessions.rate(10, 0) == nil)
    end,
    ["zonas filtran por personaje, ignoran mapas vacíos y no mutan la sesión en curso"] = function(addon)
        local db = withPrices({ [100] = { p50 = 1000, qty = 10 } })
        db.sessions = {
            { char = "Ana", maps = { [1] = { active = 1300, coin = 1300, items = { [100] = 1 } } } },
            { char = "Beto", maps = { [1] = { active = 1000, coin = 1000, items = {} },
                [2] = { active = 1300, coin = 0, items = { [100] = 1 } } } },
            { char = "Ana", maps = { [3] = { active = 1199, coin = 1199, items = {} } } },
            { char = "Ana", maps = { [0] = { active = 5000, coin = 5000, items = {} } } },
        }
        local current = { char = "Ana", last = 200000 - 60, lastMap = 2,
            maps = { [2] = { active = 1300, coin = 0, items = { [100] = 1 } } } }
        local zones = addon.Sessions.zones(db, "Horde", 200000, { char = "Ana", current = current })
        assert(#zones == 2)
        assert(zones[1].mapID == 1 and zones[1].active == 1300 and zones[1].sessions == 1)
        assert(zones[1].total == 2250 and zones[1].rate == 6231)
        assert(zones[2].mapID == 2 and zones[2].active == 1360 and zones[2].sessions == 1)
        assert(zones[2].total == 950 and zones[2].rate == 2515 and zones[2].unpriced == 0)
        assert(current.maps[2].active == 1300 and current.last == 200000 - 60)
        local all = addon.Sessions.zones(db, "Horde", 200000, {})
        assert(#all == 2 and all[1].mapID == 1 and all[1].active == 2300)
        assert(all[1].sessions == 2 and all[1].total == 3250 and all[1].rate == 5087)
        assert(all[2].mapID == 2 and all[2].active == 1300 and all[2].sessions == 1 and all[2].total == 950)
    end,
    ["nodos fusionan posiciones cercanas, separan las lejanas y limitan a 150 puntos"] = function(addon)
        local db = {}
        assert(addon.Nodes.record(db, 1, 100, 0.5, 0.5, 100))
        local node = db.nodes[1][100]
        assert(node.n == 1 and node.first == 100 and node.last == 100)
        assert(#node.spots == 1 and node.spots[1].x == 5000 and node.spots[1].y == 5000 and node.spots[1].n == 1)
        assert(addon.Nodes.record(db, 1, 100, 0.5002, 0.5002, 200))
        assert(node.n == 2 and node.last == 200 and #node.spots == 1)
        assert(node.spots[1].n == 2 and node.spots[1].t == 200)
        assert(node.spots[1].x == 5001 and node.spots[1].y == 5001)
        assert(addon.Nodes.record(db, 1, 100, 0.9, 0.9, 300))
        assert(#node.spots == 2 and node.spots[2].x == 9000 and node.spots[2].n == 1)
        assert(addon.Nodes.record(db, 1, 100, 0, 0, 400))
        assert(node.n == 4 and #node.spots == 2)
        assert(addon.Nodes.record(db, 1, 200, nil, nil, 500))
        assert(db.nodes[1][200].n == 1 and #db.nodes[1][200].spots == 0)
        assert(addon.Nodes.record(db, 0, 200, 0.1, 0.1, 500) == false)
        assert(addon.Nodes.record(db, 1, 1.5, 0.1, 0.1, 500) == false)
        for index = 1, 160 do assert(addon.Nodes.record(db, 1, 300, index / 200, 0.5, index)) end
        local many = db.nodes[1][300]
        assert(many.n == 160 and #many.spots == 150)
        local oldest = 10000
        for _, spot in ipairs(many.spots) do if spot.t < oldest then oldest = spot.t end end
        assert(oldest == 11)
    end,
    ["Loot duplicado no suma y el desuello del mismo GUID añade su objeto"] = function(addon, mock)
        setupLoot(addon, mock)
        local notified = 0
        addon.Loot.onLoot = function() notified = notified + 1 end
        local guid = "GameObject-0-1-2-3-500"
        mock.loot = { itemSlot(guid, 2, 100) }
        mock.fire("LOOT_READY")
        local session = GoldPilotCharDB.session
        assert(session and session.loots == 1 and session.items[100] == 2 and notified == 1)
        assert(GoldPilotDB.nodes[1][500].n == 1 and GoldPilotDB.nodes[1][500].spots[1].x == 5000)
        mock.fire("LOOT_READY")
        assert(GoldPilotCharDB.session == session and session.loots == 1 and session.items[100] == 2)
        assert(notified == 1)
        mock.loot = { itemSlot(guid, 1, 200) }
        mock.fire("LOOT_READY")
        assert(session.loots == 2 and session.items[100] == 2 and session.items[200] == 1)
        assert(GoldPilotDB.nodes[1][500].n == 1 and notified == 2)
    end,
    ["Loot de área suma varios GUID y el dinero sin enlace es cobre"] = function(addon, mock)
        setupLoot(addon, mock)
        mock.loot = {
            { link = "item:100", sources = { { guid = "GameObject-0-1-2-3-501", qty = 1 },
                { guid = "Creature-0-1-2-3-777", qty = 2 } } },
            moneySlot("GameObject-0-1-2-3-501", 1500),
        }
        mock.fire("LOOT_READY")
        local session = GoldPilotCharDB.session
        assert(session.items[100] == 3 and session.coin == 1500 and session.loots == 1)
        assert(session.nodes == 1 and GoldPilotDB.nodes[1][501].n == 1 and GoldPilotDB.nodes[1][777] == nil)
        mock.mapFields = true
        mock.mapX, mock.mapY = 0.25, 0.75
        mock.loot = { itemSlot("GameObject-0-1-2-3-502", 1, 101) }
        mock.fire("LOOT_READY")
        local spot = GoldPilotDB.nodes[1][502].spots[1]
        assert(spot.x == 2500 and spot.y == 7500)
    end,
    ["Loot ignora GUID de objeto y la pesca no crea nodo"] = function(addon, mock)
        setupLoot(addon, mock)
        mock.loot = { itemSlot("Item-0-1-2-3-900", 1, 100) }
        mock.fire("LOOT_READY")
        assert(GoldPilotCharDB.session == nil)
        mock.fishing = true
        mock.loot = { itemSlot("GameObject-0-1-2-3-901", 1, 100) }
        mock.fire("LOOT_READY")
        assert(GoldPilotCharDB.session.items[100] == 1 and GoldPilotDB.nodes == nil)
    end,
    ["Loot respeta el modo seguro y no crea nodos de criaturas"] = function(addon, mock)
        setupLoot(addon, mock)
        addon.safeMode = true
        mock.loot = { itemSlot("Creature-0-1-2-3-777", 1, 100) }
        mock.fire("LOOT_READY")
        assert(GoldPilotCharDB.session == nil)
        addon.safeMode = false
        mock.fire("LOOT_READY")
        assert(GoldPilotCharDB.session.items[100] == 1 and GoldPilotDB.nodes == nil)
    end,
    ["Loot cierra la sesión expirada al llegar un botín nuevo"] = function(addon, mock)
        setupLoot(addon, mock)
        GoldPilotCharDB.session = addon.Sessions.add(nil, { char = "Player", mapID = 7, coin = 10 }, clock)
        GoldPilotCharDB.session.active = 400
        local finished
        addon.Loot.onFinish = function(session, saved) finished = { session = session, saved = saved } end
        clock = clock + 901
        mock.loot = { itemSlot("Creature-0-1-2-3-778", 1, 250) }
        mock.fire("LOOT_READY")
        assert(#GoldPilotDB.sessions == 1 and GoldPilotDB.sessions[1].lastMap == 7)
        assert(GoldPilotDB.sessions[1].active == 580 and GoldPilotDB.sessions[1].stop == 200000)
        assert(finished and finished.saved == true and finished.session == GoldPilotDB.sessions[1])
        local current = GoldPilotCharDB.session
        assert(current and current.start == clock and current.loots == 1 and current.items[250] == 1)
    end,
    ["Loot comprueba la caducidad con un único temporizador que se detiene al cerrar"] = function(addon, mock)
        setupLoot(addon, mock)
        mock.loot = { itemSlot("Creature-0-1-2-3-779", 1, 100) }
        mock.fire("LOOT_READY")
        assert(GoldPilotCharDB.session and #mock.timers == 1)
        clock = clock + 901
        mock.flushTimers()
        assert(GoldPilotCharDB.session == nil and #mock.timers == 0)
        assert(GoldPilotDB.sessions == nil)
        mock.loot = { itemSlot("Creature-0-1-2-3-780", 1, 100) }
        mock.fire("LOOT_READY")
        assert(GoldPilotCharDB.session and #mock.timers == 1)
        mock.fire("LOOT_READY")
        assert(#mock.timers == 1)
    end,
}
