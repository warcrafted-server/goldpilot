return {
    ["migración inicial establece esquema 2 sin tocar datos"] = function(addon)
        local db = { keep = true }
        assert(addon.Migrations:run(db))
        assert(db.schema == 2 and db.keep)
    end,
    ["migración 2 renombra claves y resuelve colisiones por observación reciente"] = function(addon)
        local db = {
            schema = 1,
            prices = {
                ["Alliance-unknown"] = { [25] = { last = { t = 20 } }, [35] = { last = { t = 30 } } },
                ["Alliance-Forever"] = { [25] = { last = { t = 10 } }, [36] = { last = { t = 40 } } },
                ["Horde-unknown"] = { [25] = { last = { t = 50 } } },
                ["Horde-Forever"] = { [25] = { last = { t = 60 } }, [35] = { last = { t = 55 } } },
            },
            houses = { ["Alliance-unknown"] = { lastSeen = 30 }, Alliance = { lastSeen = 20 } },
            chars = { ["Warren-unknown"] = { seen = 10 }, Warren = { seen = 20 } },
        }
        assert(addon.Migrations:run(db) and db.schema == 2)
        assert(db.prices.Alliance[25].last.t == 20 and db.prices.Alliance[36].last.t == 40)
        assert(db.prices.Horde[25].last.t == 60 and db.prices.Horde[35].last.t == 55)
        assert(db.prices["Alliance-unknown"] == nil and db.prices["Alliance-Forever"] == nil)
        assert(db.prices["Horde-unknown"] == nil and db.prices["Horde-Forever"] == nil)
        assert(db.houses.Alliance.lastSeen == 30 and db.chars.Warren.seen == 20)
    end,
    ["migración fallida conserva copia y activa modo seguro"] = function(addon)
        addon.Migrations.steps[2] = function() error("fallo") end
        local db = { schema = 1, keep = true }
        assert(not addon.Migrations:run(db))
        assert(addon.safeMode and db.backup.keep)
    end,
    ["módulo con capacidad ausente se desactiva sin romper el resto"] = function(addon)
        local started
        local bad = { requires = { "NoExiste.Api" }, onEnable = function() error("no debe ejecutarse") end }
        addon.Modules:register("malo", bad)
        addon.Modules:register("bueno", { requires = { "string.format" }, onEnable = function() started = true end })
        addon.Modules:enableAll()
        assert(bad.enabled == false and started)
    end,
    ["/gp version y /gp help usan la localización"] = function(addon, mock)
        SlashCmdList.GOLDPILOT("version")
        SlashCmdList.GOLDPILOT("help")
        local text = table.concat(mock.output, "\n")
        assert(text:find("GoldPilot " .. addon.version, 1, true))
        assert(text:find(addon.L.HELP, 1, true))
    end,
    ["ADDON_LOADED crea las bases y migra"] = function(addon, mock)
        mock.fire("ADDON_LOADED", "GoldPilot")
        assert(GoldPilotDB.schema == 2 and GoldPilotCharDB and addon.loaded)
    end,
}
