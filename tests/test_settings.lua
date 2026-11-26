return {
    ["los ajustes devuelven sus valores por defecto sin base de datos"] = function(addon)
        GoldPilotDB = nil
        local keys = {
            "minimap", "tooltip", "fullScan", "hud", "routeWaypoint",
            "tooltipFields.vendor", "tooltipFields.last", "tooltipFields.median", "tooltipFields.advice",
            "appPrices",
        }
        for _, key in ipairs(keys) do
            assert(addon.Settings.get(key) == true, key)
        end
        assert(GoldPilotDB == nil)
        local sections = addon.Settings.sections()
        assert(#sections == 4)
    end,
    ["los ajustes se guardan en los mismos campos de siempre"] = function(addon)
        assert(addon.Settings.set("minimap", false) == true)
        assert(GoldPilotDB.settings.minimap.hidden == true)
        assert(addon.Settings.get("minimap") == false)
        assert(addon.Settings.set("minimap", true) == true)
        assert(GoldPilotDB.settings.minimap.hidden == false)
        assert(addon.Settings.set("tooltip", false) == true)
        assert(GoldPilotDB.settings.tooltip == false)
        assert(addon.Settings.set("tooltipFields.vendor", false) == true)
        assert(GoldPilotDB.settings.tooltipFields.vendor == false)
        assert(addon.Settings.get("tooltipFields.vendor") == false)
        assert(addon.Settings.set("fullScan", false) == true)
        assert(GoldPilotDB.settings.fullScan == false)
        assert(addon.Settings.set("appPrices", false) == true)
        assert(GoldPilotDB.settings.appPrices == false)
    end,
    ["un tipo equivocado o una clave desconocida no cambian nada"] = function(addon)
        assert(addon.Settings.set("fullScan", "off") == false)
        assert(not GoldPilotDB or not GoldPilotDB.settings or GoldPilotDB.settings.fullScan == nil)
        assert(addon.Settings.set("desconocido", true) == false)
        assert(addon.Settings.get("desconocido") == nil)
    end,
    ["aplicar un ajuste llama al módulo que lo usa"] = function(addon)
        local minimapVisible, hud, waypoint
        addon.Minimap.setVisible = function(_, visible) minimapVisible = visible end
        addon.SessionHUD.setEnabled = function(_, enabled) hud = enabled end
        addon.RouteFollow.setWaypoint = function(_, enabled) waypoint = enabled end
        addon.Settings.set("minimap", false)
        addon.Settings.set("hud", false)
        addon.Settings.set("routeWaypoint", false)
        assert(minimapVisible == false and hud == false and waypoint == false)
        addon.Settings.set("hud", true)
        assert(hud == true)
    end,
    ["cambiar un ajuste avisa a los demás módulos"] = function(addon)
        local changed
        addon.Events:subscribe("prueba", "GOLDPILOT_SETTING_CHANGED", function(key, value)
            changed = { key = key, value = value }
        end)
        addon.Settings.set("appPrices", false)
        assert(changed and changed.key == "appPrices" and changed.value == false)
    end,
    ["la lista de una sección respeta el orden de sus ajustes"] = function(addon)
        local fields = addon.Settings.list("fields")
        assert(#fields == 4)
        assert(fields[1].key == "tooltipFields.vendor" and fields[4].key == "tooltipFields.advice")
        local prices = addon.Settings.list("prices")
        assert(#prices == 1 and prices[1].key == "appPrices" and prices[1].default == true)
        assert(#addon.Settings.list("gathering") == 3)
    end,
    ["/gpilot set lista, cambia y avisa de las claves o valores incorrectos"] = function(addon, mock)
        SlashCmdList.GOLDPILOT("set fullScan off")
        assert(GoldPilotDB.settings.fullScan == false)
        assert(mock.output[#mock.output]:find("fullScan", 1, true))
        SlashCmdList.GOLDPILOT("set")
        local listed = false
        for _, line in ipairs(mock.output) do
            if line:find(addon.L.SETTINGS_LIST_HEADER, 1, true) then listed = true end
        end
        assert(listed)
        SlashCmdList.GOLDPILOT("set desconocido on")
        assert(mock.output[#mock.output]:find(string.format(addon.L.SETTINGS_UNKNOWN, "desconocido"), 1, true))
        SlashCmdList.GOLDPILOT("set fullScan quizá")
        assert(mock.output[#mock.output]:find(string.format(addon.L.SETTINGS_INVALID, "fullScan"), 1, true))
        assert(GoldPilotDB.settings.fullScan == false)
    end,
    ["Valuation ignora las fuentes externas si se desactivan sus precios"] = function(addon)
        addon.Valuation.registerSource("app", function() return 100, 1000 end)
        local ref = addon.Valuation.reference({}, "casa", 25, 1000)
        assert(ref and ref.class == "EXT" and ref.price == 100)
        assert(addon.Settings.set("appPrices", false) == true)
        assert(addon.Valuation.reference({}, "casa", 25, 1000) == nil)
    end,
}
