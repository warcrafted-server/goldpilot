local clock = 200000

local function setup(addon, mock, x, y)
    clock = 200000
    mock.mapID, mock.mapX, mock.mapY = 7, x or 0.1, y or 0.1
    mock.enableLoot()
    C_Map.GetMapWorldSize = function() return 1000, 1000 end
    time = function() return clock end
    UnitOnTaxi = function() return false end
    UnitIsDeadOrGhost = function() return false end
    TomTom = nil
    GoldPilotDB, GoldPilotCharDB = {}, {}
    return mock
end

local function plan(kind)
    return { mapID = 7, kind = kind, route = { points = 3, stops = {
        { x = 0.1, y = 0.1, points = { { x = 0.1, y = 0.1, object = 100, kind = "herb" } } },
        { x = 0.5, y = 0.5, points = { { x = 0.5, y = 0.5, object = 101, kind = "ore" } } },
        { x = 0.9, y = 0.9, points = { { x = 0.9, y = 0.9, object = 100, kind = "herb" } } },
    } } }
end

local function move(mock, x, y)
    mock.mapX, mock.mapY = x, y
end

local function cell(addon, kind, x, y)
    return addon.Visits.cell(kind, x, y)
end

return {
    ["route plan clasifica el nodo por semilla, por el mapa activo o por el botin"] = function(addon, mock)
        setup(addon, mock)
        mock.items[55] = { class = 7, subclass = 9 }
        addon.DataNodeSeeds = { "hierba;100;55;1;1;seed" }
        addon.DataNodeSpots = { [7] = { [200] = { kind = "ore", p = "" } } }
        addon.RoutePlan.active = { mapID = 7 }
        assert(addon.RoutePlan.kindOf(100, {}) == "herb")
        assert(addon.RoutePlan.kindOf(200, {}) == "ore")
        assert(addon.RoutePlan.kindOf(300, { [55] = 1 }) == "herb")
        assert(addon.RoutePlan.kindOf(300, {}) == nil)
        addon.RoutePlan.active = { mapID = 8 }
        assert(addon.RoutePlan.kindOf(200, {}) == nil)
    end,
    ["route follow arranca en la parada mas cercana con un solo temporizador"] = function(addon, mock)
        setup(addon, mock, 0.89, 0.89)
        local start = plan()
        assert(addon.RouteFollow:start(start) == 3)
        assert(addon.RouteFollow.plan == start and addon.RouteFollow.next == 3)
        assert(#mock.timers == 1)
        addon.RouteFollow:start(start)
        assert(#mock.timers == 1 and addon.RouteFollow.next == 3)
        addon.RouteFollow:stop()
        mock.flushTimers()
        assert(#mock.timers == 0 and addon.RouteFollow.plan == nil)
        addon.RouteFollow:start(start)
        assert(#mock.timers == 1)
        addon.RouteFollow:stop()
    end,
    ["route follow sin posicion empieza en la primera parada"] = function(addon, mock)
        setup(addon, mock)
        C_Map.GetPlayerMapPosition = function() return nil end
        addon.RouteFollow:start(plan())
        assert(addon.RouteFollow.next == 1)
        addon.RouteFollow:stop()
    end,
    ["route plan arranca y para el seguimiento al mostrar y limpiar"] = function(addon, mock)
        setup(addon, mock)
        local start = plan()
        addon.RoutePlan:show(start)
        assert(addon.RouteFollow.plan == start)
        addon.RoutePlan:clear()
        assert(addon.RouteFollow.plan == nil and addon.RoutePlan.active == nil)
        mock.flushTimers()
        assert(#mock.timers == 0)
    end,
    ["route follow registra una visita sin nodo al salir"] = function(addon, mock)
        setup(addon, mock)
        addon.RouteFollow:start(plan())
        move(mock, 0.105, 0.105)
        mock.flushTimers()
        assert(addon.RouteFollow.visit and addon.RouteFollow.visit.index == 1)
        assert(addon.RouteFollow.next == 2 and GoldPilotDB.routeVisits == nil)
        clock = clock + 4
        move(mock, 0.3, 0.3)
        mock.flushTimers()
        assert(addon.RouteFollow.visit == nil)
        local entry = GoldPilotDB.routeVisits[7][cell(addon, nil, 0.1, 0.1)]
        assert(entry and entry.v == 1 and entry.h == 0 and entry.t == clock)
        addon.RouteFollow:stop()
    end,
    ["route follow apunta el nodo cercano como acierto de la visita"] = function(addon, mock)
        setup(addon, mock)
        mock.items[55] = { class = 7, subclass = 9 }
        addon.RouteFollow:start(plan())
        move(mock, 0.105, 0.105)
        mock.flushTimers()
        assert(addon.Loot.onNode(7, 0.1, 0.1, 100, { [55] = 1 }, clock))
        clock = clock + 4
        move(mock, 0.3, 0.3)
        mock.flushTimers()
        local entry = GoldPilotDB.routeVisits[7][cell(addon, nil, 0.1, 0.1)]
        assert(entry and entry.v == 1 and entry.h == 1)
        addon.RouteFollow:stop()
    end,
    ["route follow no repite la misma parada antes de 300 s"] = function(addon, mock)
        setup(addon, mock)
        addon.RouteFollow:start(plan())
        move(mock, 0.105, 0.105)
        mock.flushTimers()
        clock = clock + 4
        move(mock, 0.3, 0.3)
        mock.flushTimers()
        local key = cell(addon, nil, 0.1, 0.1)
        assert(GoldPilotDB.routeVisits[7][key].v == 1)
        clock = clock + 10
        move(mock, 0.105, 0.105)
        mock.flushTimers()
        clock = clock + 4
        move(mock, 0.3, 0.3)
        mock.flushTimers()
        assert(GoldPilotDB.routeVisits[7][key].v == 1)
        clock = clock + 300
        move(mock, 0.105, 0.105)
        mock.flushTimers()
        clock = clock + 4
        move(mock, 0.3, 0.3)
        mock.flushTimers()
        assert(GoldPilotDB.routeVisits[7][key].v == 2)
        addon.RouteFollow:stop()
    end,
    ["route follow descarta la visita en taxi, muerto o sin posicion"] = function(addon, mock)
        setup(addon, mock)
        addon.RouteFollow:start(plan())
        move(mock, 0.105, 0.105)
        mock.flushTimers()
        assert(addon.RouteFollow.visit)
        UnitOnTaxi = function() return true end
        mock.flushTimers()
        assert(addon.RouteFollow.visit == nil)
        UnitOnTaxi = function() return false end
        clock = clock + 10
        move(mock, 0.3, 0.3)
        mock.flushTimers()
        assert(GoldPilotDB.routeVisits == nil)
        move(mock, 0.105, 0.105)
        mock.flushTimers()
        assert(addon.RouteFollow.visit)
        UnitIsDeadOrGhost = function() return true end
        mock.flushTimers()
        assert(addon.RouteFollow.visit == nil)
        UnitIsDeadOrGhost = function() return false end
        clock = clock + 10
        move(mock, 0.3, 0.3)
        mock.flushTimers()
        assert(GoldPilotDB.routeVisits == nil)
        move(mock, 0.105, 0.105)
        mock.flushTimers()
        assert(addon.RouteFollow.visit)
        C_Map.GetPlayerMapPosition = function() return nil end
        mock.flushTimers()
        assert(addon.RouteFollow.visit == nil)
        C_Map.GetPlayerMapPosition = function() return { GetXY = function() return 0.3, 0.3 end } end
        clock = clock + 10
        mock.flushTimers()
        assert(GoldPilotDB.routeVisits == nil)
        addon.RouteFollow:stop()
    end,
    ["route follow crea un solo punto de TomTom y lo quita al parar"] = function(addon, mock)
        setup(addon, mock)
        local added, removed = {}, {}
        TomTom = {
            AddWaypoint = function(_, mapID, x, y, options)
                added[#added + 1] = { mapID = mapID, x = x, y = y, options = options }
                return "uid" .. #added
            end,
            RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end,
        }
        local start = plan()
        addon.RouteFollow:start(start)
        assert(#added == 1 and added[1].mapID == 7 and added[1].x == 0.1 and added[1].y == 0.1)
        assert(added[1].options.title == string.format(addon.L.ROUTE_WAYPOINT, 1))
        assert(added[1].options.persistent == false and added[1].options.minimap == true
            and added[1].options.world == true and added[1].options.from == "GoldPilot")
        assert(addon.RouteFollow.waypoint == "uid1")
        addon.RouteFollow:stop()
        assert(#removed == 1 and removed[1] == "uid1" and addon.RouteFollow.waypoint == nil)
        TomTom.AddWaypoint = function() error("sin ruta") end
        addon.RouteFollow:start(start)
        assert(addon.RouteFollow.waypoint == nil and addon.RouteFollow.plan == start)
        addon.RouteFollow:stop()
        TomTom = nil
        addon.RouteFollow:start(start)
        addon.RouteFollow:stop()
    end,
    ["route follow respeta el ajuste de TomTom guardado"] = function(addon, mock)
        setup(addon, mock)
        GoldPilotDB.settings = { routeWaypoint = false }
        local added = 0
        TomTom = { AddWaypoint = function() added = added + 1; return "uid" .. added end }
        addon.RouteFollow:start(plan())
        assert(added == 0 and addon.RouteFollow.waypoint == nil)
        addon.RouteFollow:setWaypoint(true)
        assert(added == 1)
        addon.RouteFollow:stop()
        assert(addon.RouteFollow.waypoint == nil)
    end,
    ["route follow no toca TomTom en combate y lo marca despues"] = function(addon, mock)
        setup(addon, mock)
        local added, removed = {}, {}
        TomTom = {
            AddWaypoint = function() added[#added + 1] = true; return "uid" .. #added end,
            RemoveWaypoint = function(_, uid) removed[#removed + 1] = uid end,
        }
        addon.RouteFollow:start(plan())
        assert(#added == 1)
        move(mock, 0.105, 0.105)
        mock.combat = true
        mock.flushTimers()
        assert(addon.RouteFollow.next == 2 and #added == 1 and #removed == 0)
        mock.combat = false
        mock.flushTimers()
        assert(#added == 2 and #removed == 1 and removed[1] == "uid1")
        addon.RouteFollow:stop()
    end,
    ["route follow ignora el botin de otro tipo, mapa, punto o desconocido"] = function(addon, mock)
        setup(addon, mock)
        mock.items[55] = { class = 7, subclass = 9 }
        mock.items[66] = { class = 7, subclass = 7 }
        mock.items[77] = { class = 2, subclass = 0 }
        addon.DataNodeSpots = { [8] = { [501] = { kind = "herb", p = "" } } }
        addon.RouteFollow:start(plan("herb"))
        move(mock, 0.105, 0.105)
        mock.flushTimers()
        assert(not addon.Loot.onNode(7, 0.1, 0.1, 100, { [66] = 1 }, clock))
        assert(not addon.Loot.onNode(8, 0.1, 0.1, 100, { [55] = 1 }, clock))
        assert(not addon.Loot.onNode(7, 0.1, 0.1, 501, { [77] = 1 }, clock))
        assert(not addon.Loot.onNode(7, 0.1, 0.1, 999, { [77] = 1 }, clock))
        assert(not addon.Loot.onNode(7, 0.9, 0.9, 100, { [55] = 1 }, clock))
        assert(addon.Loot.onNode(7, 0.105, 0.1, 100, { [55] = 1 }, clock))
        clock = clock + 4
        move(mock, 0.3, 0.3)
        mock.flushTimers()
        local entry = GoldPilotDB.routeVisits[7][cell(addon, "herb", 0.1, 0.1)]
        assert(entry and entry.v == 1 and entry.h == 1)
        addon.RouteFollow:stop()
    end,
    ["route follow cambia de parada en el mismo tick tras salir"] = function(addon, mock)
        setup(addon, mock)
        addon.RouteFollow:start(plan())
        move(mock, 0.105, 0.105)
        mock.flushTimers()
        clock = clock + 4
        move(mock, 0.505, 0.505)
        mock.flushTimers()
        assert(addon.RouteFollow.visit and addon.RouteFollow.visit.index == 2)
        assert(addon.RouteFollow.next == 3)
        local first = GoldPilotDB.routeVisits[7][cell(addon, nil, 0.1, 0.1)]
        assert(first and first.v == 1)
        addon.RouteFollow:stop()
    end,
    ["route follow cambia a la parada contigua dentro de la visita"] = function(addon, mock)
        setup(addon, mock, 0.2, 0.2)
        local start = { mapID = 7, route = { stops = {
            { x = 0.2, y = 0.2, points = { { x = 0.2, y = 0.2 } } },
            { x = 0.22, y = 0.2, points = { { x = 0.22, y = 0.2 } } },
        } } }
        addon.RouteFollow:start(start)
        assert(addon.RouteFollow.next == 1)
        mock.flushTimers()
        assert(addon.RouteFollow.visit and addon.RouteFollow.visit.index == 1)
        assert(addon.RouteFollow.next == 2)
        clock = clock + 4
        move(mock, 0.21, 0.2)
        mock.flushTimers()
        assert(addon.RouteFollow.visit.index == 1 and addon.RouteFollow.next == 2)
        move(mock, 0.215, 0.2)
        mock.flushTimers()
        assert(addon.RouteFollow.visit and addon.RouteFollow.visit.index == 2)
        assert(addon.RouteFollow.next == 1)
        local first = GoldPilotDB.routeVisits[7][cell(addon, nil, 0.2, 0.2)]
        assert(first and first.v == 1)
        addon.RouteFollow:stop()
    end,
}
