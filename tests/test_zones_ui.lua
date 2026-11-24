local function detailText(panel)
    local values = {}
    for _, label in ipairs(panel.labels or {}) do
        if not label.hidden and label.value then values[#values + 1] = label.value end
    end
    for _, label in pairs(panel.values or {}) do
        if not label.hidden and label.value then values[#values + 1] = label.value end
    end
    return table.concat(values, " ")
end

local function priced(value)
    return { last = { t = 199000, min = value, p50 = value, qty = 20 } }
end

local function setup(addon, mock)
    C_Map = {
        GetBestMapForUnit = function() return 10 end,
        GetMapInfo = function(id) return { name = "Zona " .. id } end,
    }
    local house = addon.AuctionHouse.houseKey()
    mock.items[500] = { name = "Hierba", class = 7, subclass = 9 }
    GoldPilotDB = {
        prices = { [house] = { [500] = priced(1000) } },
        houses = { [house] = { cut = 0.05 } },
        nodes = { [10] = { [100] = { spots = {} } }, [20] = { [200] = { spots = {} } },
            [30] = { [300] = { spots = {} } } },
        sessions = {
            { char = "Ana", start = 100, stop = 200, active = 1200, coin = 500, nodes = 3,
                items = { [500] = 2 }, lastMap = 20,
                maps = { [20] = { active = 1000, coin = 500, items = { [500] = 2 } },
                    [30] = { active = 200, coin = 0, items = {} } } },
            { char = "Ana", start = 50, stop = 80, active = 900, coin = 100, nodes = 1,
                items = {}, lastMap = 20,
                maps = { [20] = { active = 900, coin = 100, items = {} } } },
        },
    }
    GoldPilotCharDB = {
        session = { char = "Ana", start = 300, last = 200000, active = 400, coin = 0, nodes = 2,
            items = {}, lastMap = 10,
            maps = { [10] = { active = 400, coin = 0, items = {} } } },
    }
end

return {
    ["zonas se registra entre libro y ajustes y se abre"] = function(addon)
        addon.Main:show()
        local bar = addon.Main.tabsBar
        assert(#bar.buttons == 5)
        assert(bar.buttons[1].name == "now" and bar.buttons[2].name == "inventory")
        assert(bar.buttons[3].name == "ledger" and bar.buttons[4].name == "zones"
            and bar.buttons[5].name == "settings")
        bar.buttons[4].scripts.OnClick(bar.buttons[4])
        assert(addon.Main.activeTab == "zones" and not addon.Main.pages.zones.hidden)
    end,
    ["zonas lista la actual primero, sin repetir, y mide solo lo suficiente"] = function(addon, mock)
        local originalDB, originalCharDB = GoldPilotDB, GoldPilotCharDB
        setup(addon, mock)
        addon.Main:show()
        addon.Main.tabsBar:select("zones")
        local ui, rows = addon.ZonesUI, addon.ZonesUI.widgets.list.data
        assert(GoldPilotCharDB.zonesView == "zones" and GoldPilotCharDB.routeKind == "all")
        assert(#rows == 3)
        assert(rows[1].mapID == 10 and rows[1].here and rows[1].text:find(addon.L.ZONES_HERE, 1, true))
        local seen = {}
        for _, row in ipairs(rows) do
            assert(not seen[row.mapID], "mapa repetido")
            seen[row.mapID] = true
        end
        local byMap = {}
        for _, row in ipairs(rows) do byMap[row.mapID] = row end
        assert(byMap[20].right == addon.Theme.money(4737) .. addon.L.NOW_PER_HOUR)
        assert(byMap[30].right == addon.L.ZONES_UNMEASURED)
        local metrics = ui.widgets.metrics.items
        assert(metrics[1].value.value == addon.Theme.money(4737) .. addon.L.NOW_PER_HOUR)
        assert(metrics[2].value.value == "2")
        assert(metrics[3].value.value == "41")
        assert(metrics[4].value.value == "6")
        assert(detailText(ui.widgets.detail):find(addon.L.ZONES_MEASURED, 1, true))
        ui.selectedMap = 30
        ui:refresh()
        assert(detailText(ui.widgets.detail):find(addon.L.ZONES_NO_DATA, 1, true))
        ui.kindButton.scripts.OnClick(ui.kindButton)
        assert(GoldPilotCharDB.routeKind == "herb" and ui.kindButton:GetText() == addon.L.ZONES_KIND_HERB)
        ui.kindButton.scripts.OnClick(ui.kindButton)
        assert(GoldPilotCharDB.routeKind == "ore" and ui.kindButton:GetText() == addon.L.ZONES_KIND_ORE)
        ui.kindButton.scripts.OnClick(ui.kindButton)
        assert(GoldPilotCharDB.routeKind == "all" and ui.kindButton:GetText() == addon.L.ZONES_KIND_ALL)
        GoldPilotDB, GoldPilotCharDB = originalDB, originalCharDB
    end,
    ["crear ruta solo calcula al pulsar y quitarla limpia el plan"] = function(addon, mock)
        local originalDB, originalCharDB = GoldPilotDB, GoldPilotCharDB
        setup(addon, mock)
        addon.Main:show()
        addon.Main.tabsBar:select("zones")
        local ui = addon.ZonesUI
        ui.selectedMap = 20
        ui:refresh()
        local calls, plan = 0, nil
        local original = addon.RoutePlan.compute
        addon.RoutePlan.compute = function(mapID, kind)
            calls = calls + 1
            plan = { mapID = mapID, kind = kind, route = {
                stops = { { x = 0.1, y = 0.1 }, { x = 0.5, y = 0.5 }, { x = 0.9, y = 0.9 } }, points = 12 },
                stats = { own = 3, seed = 4, skill = 1, unpriced = 2 }, skills = { known = true },
                yards = 1200, at = 1 }
            return plan
        end
        ui:refresh()
        assert(calls == 0 and addon.RoutePlan.active == nil)
        ui.routeButton.scripts.OnClick(ui.routeButton)
        assert(calls == 1 and addon.RoutePlan.active == plan)
        assert(ui.routeButton:GetText() == addon.L.ZONES_CLEAR_ROUTE)
        local text = detailText(ui.widgets.detail)
        assert(text:find(addon.L.ZONES_ROUTE, 1, true))
        assert(text:find(string.format(addon.L.ZONES_ROUTE_STOPS, 3), 1, true))
        assert(text:find(string.format(addon.L.ZONES_ROUTE_YARDS, 1200), 1, true))
        assert(text:find(addon.L.ZONES_ROUTE_NOTE, 1, true))
        ui.routeButton.scripts.OnClick(ui.routeButton)
        assert(calls == 1 and addon.RoutePlan.active == nil)
        assert(ui.routeButton:GetText() == addon.L.ZONES_CREATE_ROUTE)
        addon.RoutePlan.compute = function(mapID, kind)
            calls = calls + 1
            return { mapID = mapID, kind = kind, route = nil, stats = { own = 0, seed = 0, skill = 2,
                unpriced = 3 }, skills = { known = false }, yards = nil, at = 1 }
        end
        local opened, originalOpen = 0, addon.RouteMap.open
        addon.RouteMap.open = function() opened = opened + 1 return true end
        ui.routeButton.scripts.OnClick(ui.routeButton)
        assert(calls == 2 and addon.RoutePlan.active == nil and opened == 0)
        assert(ui.lastPlan and ui.lastPlan.route == nil)
        assert(ui.routeButton:GetText() == addon.L.ZONES_CREATE_ROUTE)
        text = detailText(ui.widgets.detail)
        assert(text:find(addon.L.ZONES_NO_ROUTE, 1, true))
        assert(text:find(addon.L.ZONES_NO_SKILL, 1, true))
        addon.RouteMap.open = originalOpen
        addon.RoutePlan.compute = original
        GoldPilotDB, GoldPilotCharDB = originalDB, originalCharDB
    end,
    ["sesiones van de la mas nueva a la mas vieja y la actual arriba"] = function(addon, mock)
        local originalDB, originalCharDB = GoldPilotDB, GoldPilotCharDB
        setup(addon, mock)
        addon.Main:show()
        addon.Main.tabsBar:select("zones")
        local ui = addon.ZonesUI
        GoldPilotCharDB.zonesView = "sessions"
        ui:refresh()
        local rows = ui.widgets.list.data
        assert(#rows == 3)
        assert(rows[1].text:find(addon.L.ZONES_ONGOING, 1, true))
        assert(rows[2].entry.session.stop == 200 and rows[3].entry.session.stop == 80)
        assert(ui.viewButton:GetText() == addon.L.ZONES_VIEW_SESSIONS)
        ui.widgets.list.rows[2].scripts.OnClick(ui.widgets.list.rows[2])
        local text = detailText(ui.widgets.detail)
        assert(text:find(addon.L.ZONES_SESSION_CHAR, 1, true) and text:find("Ana", 1, true))
        assert(text:find(addon.Theme.money(2400), 1, true))
        GoldPilotDB.sessions, GoldPilotCharDB.session = {}, nil
        ui:refresh()
        assert(#ui.widgets.list.data == 0
            and addon.Main.pages.zones.emptyText.value == addon.L.ZONES_NO_SESSIONS)
        GoldPilotDB, GoldPilotCharDB = originalDB, originalCharDB
    end,
    ["zonas no refresca ni cambia controles en combate"] = function(addon, mock)
        local originalDB, originalCharDB = GoldPilotDB, GoldPilotCharDB
        setup(addon, mock)
        addon.Main:show()
        addon.Main.tabsBar:select("zones")
        local ui = addon.ZonesUI
        local count = #ui.widgets.list.data
        mock.combat = true
        assert(not ui:refresh())
        ui.viewButton.scripts.OnClick(ui.viewButton)
        ui.kindButton.scripts.OnClick(ui.kindButton)
        ui.routeButton.scripts.OnClick(ui.routeButton)
        assert(GoldPilotCharDB.zonesView == "zones" and GoldPilotCharDB.routeKind == "all")
        assert(addon.RoutePlan.active == nil and #ui.widgets.list.data == count)
        mock.combat = false
        GoldPilotDB, GoldPilotCharDB = originalDB, originalCharDB
    end,
}
