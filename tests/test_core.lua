return {
    ["migración inicial establece esquema 1 sin tocar datos"] = function(addon)
        local db = { keep = true }
        assert(addon.Migrations:run(db))
        assert(db.schema == 1 and db.keep)
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
        assert(GoldPilotDB.schema == 1 and GoldPilotCharDB and addon.loaded)
    end,
}
