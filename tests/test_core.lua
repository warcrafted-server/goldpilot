return {
    ["migración inicial establece esquema 3 sin tocar datos"] = function(addon)
        local db = { keep = true }
        assert(addon.Migrations:run(db))
        assert(db.schema == 3 and db.keep)
    end,
    ["migración 2 renombra claves y resuelve colisiones por observación reciente"] = function(addon)
        local function observation(t, d, w)
            return { last = { t = t, min = 4, p50 = 5, qty = 6, src = "OBS" }, d = d or "", w = w or "" }
        end
        local db = {
            schema = 1,
            prices = {
                ["Alliance-unknown"] = { [25] = observation(20, "1:2:3:4", "2:3:4:5"), [35] = observation(30) },
                ["Alliance-Forever"] = { [25] = observation(10), [36] = observation(40) },
                ["Horde-unknown"] = { [25] = observation(50) },
                ["Horde-Forever"] = { [25] = observation(60), [35] = observation(55) },
            },
            houses = { ["Alliance-unknown"] = { lastSeen = 30 }, Alliance = { lastSeen = 20 } },
            chars = { ["Warren-unknown"] = { seen = 10 }, Warren = { seen = 20 } },
        }
        assert(addon.Migrations:run(db) and db.schema == 3)
        assert(addon.Prices.get(db, "Alliance", 25).t == 20 and addon.Prices.get(db, "Alliance", 36).t == 40)
        assert(addon.Prices.get(db, "Horde", 25).t == 60 and addon.Prices.get(db, "Horde", 35).t == 55)
        assert(db.prices.Alliance[25] == "20:4:5:6|1:2:3:4|2:3:4:5")
        assert(db.prices["Horde-unknown"] == nil and db.prices["Horde-Forever"] == nil)
        assert(db.prices["Alliance-unknown"] == nil and db.prices["Alliance-Forever"] == nil)
        assert(db.houses.Alliance.lastSeen == 30 and db.chars.Warren.seen == 20)
    end,
    ["migración 3 descarta equipo, conserva desconocidos y datos ajenos"] = function(addon, mock)
        mock.items = { [100] = { sell = 1, stack = 1, class = 2 }, [101] = { sell = 1, stack = 1, class = 4 }, [102] = { sell = 1, stack = 1, class = 0 } }
        local db = { schema = 2, prices = { empty = {}, h = {
            [100] = { last = { t = 1, min = 2, p50 = 3, qty = 4 }, d = "10:2:3:4", w = "1:2:3:4" },
            [101] = { last = { t = 1, min = 2, p50 = 3, qty = 4 } },
            [102] = { last = { t = 2, min = 3, p50 = 4, qty = 5 }, d = "10:6:7:8", w = "1:9:10:11" },
            [999] = { last = { t = 3, min = 4, p50 = 5, qty = 6 } },
        } }, ledger = { keep = true }, mailSeen = { keep = true } }
        assert(addon.Migrations:run(db) and db.schema == 3)
        assert(db.prices.empty and not db.prices.h[100] and not db.prices.h[101])
        assert(db.prices.h[102] == "2:3:4:5|10:6:7:8|1:9:10:11" and db.prices.h[999] == "3:4:5:6||")
        assert(db.ledger.keep and db.mailSeen.keep)
        local bare = { schema = 2 }
        assert(addon.Migrations:run(bare) and bare.schema == 3)
    end,
    ["migración fallida conserva copia y activa modo seguro"] = function(addon)
        local previous = addon.Migrations.steps[3]
        addon.Migrations.steps[3] = function() error("fallo") end
        local prices = { h = { [1] = "value" } }
        local db = { schema = 2, prices = prices, keep = true }
        assert(not addon.Migrations:run(db))
        assert(db.prices == prices and db.backup.keep and addon.safeMode)
        addon.Migrations.steps[3] = previous
    end,
    ["migración 3 fallida a mitad conserva los precios"] = function(addon)
        local original = addon.ItemKey.itemID
        local count = 0
        addon.ItemKey.itemID = function(key)
            count = count + 1
            if count == 2 then error("fallo parcial") end
            return original(key)
        end
        local prices = { h = { [1] = "1:2:3:4||", [2] = "2:3:4:5||" } }
        local db = { schema = 2, prices = prices }
        assert(not addon.Migrations:run(db))
        assert(count == 2 and db.prices == prices)
        addon.ItemKey.itemID = original
    end,
    ["módulo con capacidad ausente se desactiva sin romper el resto"] = function(addon)
        local started
        local bad = { requires = { "NoExiste.Api" }, onEnable = function() error("no debe ejecutarse") end }
        addon.Modules:register("malo", bad)
        addon.Modules:register("bueno", { requires = { "string.format" }, onEnable = function() started = true end })
        addon.Modules:enableAll()
        assert(bad.enabled == false and started)
    end,
    ["/gpilot version y /gpilot help usan la localización"] = function(addon, mock)
        SlashCmdList.GOLDPILOT("version")
        SlashCmdList.GOLDPILOT("help")
        local text = table.concat(mock.output, "\n")
        assert(text:find("GoldPilot " .. addon.version, 1, true))
        assert(text:find(addon.L.HELP, 1, true))
    end,
    ["/gpilot route guarda el estado de la ruta sin mapa del mundo"] = function(addon, mock)
        WorldMapFrame = nil
        GoldPilotDB = {}
        addon.RoutePlan.active = { mapID = 7, points = 2,
            route = { stops = { { x = 0.1, y = 0.1 }, { x = 0.9, y = 0.9 } }, points = 2 } }
        SlashCmdList.GOLDPILOT("route")
        local line = mock.output[#mock.output]
        assert(line and line:find("7", 1, true))
        local saved = GoldPilotDB.diag.route
        assert(type(saved) == "table" and saved.planMap == 7 and saved.stops == 2)
        assert(saved.available == false and saved.rect == nil)
        for _, value in pairs(saved) do
            local kind = type(value)
            assert(kind == "boolean" or kind == "number" or kind == "string")
        end
        addon.RoutePlan:clear()
    end,
    ["ADDON_LOADED crea las bases y migra"] = function(addon, mock)
        mock.fire("ADDON_LOADED", "GoldPilot")
        assert(GoldPilotDB.schema == 3 and GoldPilotCharDB and addon.loaded)
    end,
    ["gp watch alterna el seguimiento con enlace o número"] = function(addon, mock)
        mock.items = { [25] = { sell = 1, stack = 1, class = 0, bind = 0 } }
        GoldPilotDB = {}
        SlashCmdList.GOLDPILOT("watch |cff0070dd|Hitem:25::::|h[Algo]|h|r")
        assert(GoldPilotDB.watch[25] == true)
        SlashCmdList.GOLDPILOT("watch 25")
        assert(GoldPilotDB.watch[25] == nil)
        SlashCmdList.GOLDPILOT("watch 999")
        SlashCmdList.GOLDPILOT("watch")
        assert(GoldPilotDB.watch[999] == true)
        SlashCmdList.GOLDPILOT("watch 999")
        assert(GoldPilotDB.watch[999] == nil)
    end,
    ["un temporizador cancelado no ejecuta su función"] = function(addon, mock)
        local calls = 0
        local handle = addon.Timer.after(1, function() calls = calls + 1 end, "prueba")
        assert(handle:active())
        handle:cancel()
        assert(not handle:active())
        mock.flushTimers()
        assert(calls == 0)
    end,
    ["cancelAll cancela solo los temporizadores de su dueño"] = function(addon, mock)
        local calls = { dueno = 0, otro = 0 }
        addon.Timer.after(1, function() calls.dueno = calls.dueno + 1 end, "dueno")
        addon.Timer.after(1, function() calls.otro = calls.otro + 1 end, "otro")
        addon.Timer.cancelAll("dueno")
        mock.flushTimers()
        assert(calls.dueno == 0 and calls.otro == 1)
    end,
    ["every se repite hasta que la función devuelve false"] = function(addon, mock)
        local calls = 0
        addon.Timer.every(1, function()
            calls = calls + 1
            return calls < 3
        end, "repite")
        for _ = 1, 4 do mock.flushTimers() end
        assert(calls == 3)
    end,
    ["un error en la función del temporizador se registra y no rompe"] = function(addon, mock)
        local before = #mock.output
        addon.Timer.after(1, function() error("fallo del temporizador") end)
        mock.flushTimers()
        local text = table.concat(mock.output, "\n", before + 1)
        assert(text:find("fallo del temporizador", 1, true))
    end,
    ["send entrega argumentos y no registra el mensaje en el frame"] = function(addon, mock)
        local received
        addon.Events:subscribe("emisor", "GOLDPILOT_PRUEBA", function(a, b) received = a + b end)
        assert(mock.events["GOLDPILOT_PRUEBA"] == nil)
        addon.Events:send("GOLDPILOT_PRUEBA", 2, 3)
        assert(received == 5)
    end,
    ["unsubscribe quita solo el suscriptor indicado"] = function(addon, mock)
        local first, second = 0, 0
        addon.Events:subscribe("uno", "GOLDPILOT_PRUEBA", function() first = first + 1 end)
        addon.Events:subscribe("dos", "GOLDPILOT_PRUEBA", function() second = second + 1 end)
        addon.Events:unsubscribe("uno", "GOLDPILOT_PRUEBA")
        addon.Events:send("GOLDPILOT_PRUEBA")
        assert(first == 0 and second == 1)
    end,
}
