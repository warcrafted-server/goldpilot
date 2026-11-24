local function mapFrame(mock, id)
    local canvas = CreateFrame("Frame", nil, UIParent)
    canvas:SetSize(1000, 500)
    local current = id
    local frame = CreateFrame("Frame", "WorldMapFrame", UIParent)
    function frame:GetCanvas() return canvas end
    function frame:GetCanvasScale() return 2 end
    function frame:GetMapID() return current end
    function frame:SetMapID(value) current = value end
    mock.worldMap = frame
    return frame, function(value) current = value end
end

local function stops(count)
    local list = {}
    for index = 1, count do list[index] = { x = index / (count + 1), y = index / (count + 1) } end
    return list
end

return {
    ["route map sin mapa del mundo no da error y no esta disponible"] = function(addon)
        addon.RoutePlan.active = { mapID = 1, route = { stops = stops(3), points = 3 } }
        assert(addon.RouteMap:available() == false)
        assert(addon.RouteMap:refresh() == false)
        assert(addon.RouteMap.frame == nil)
        assert(addon.RouteMap:open(1) == false)
        CreateFrame("Frame", "WorldMapFrame", UIParent)
        assert(addon.RouteMap:available() == false)
        WorldMapFrame = nil
        addon.RoutePlan:clear()
    end,
    ["route map dibuja lineas y paradas, reutiliza el pool y oculta otro mapa"] = function(addon, mock)
        local _, setMap = mapFrame(mock, 7)
        addon.RoutePlan.active = { mapID = 7, kind = "herb", route = { stops = stops(3), points = 8 },
            stats = { own = 2, seed = 3, skill = 1, unpriced = 0 }, skills = { known = true }, yards = 900 }
        assert(addon.RouteMap:available())
        assert(addon.RouteMap:refresh())
        local map = addon.RouteMap
        assert(map.frame and map.frame.parent == map.canvas)
        assert(#map.lines == 3 and #map.dots == 3 and #map.labels == 3)
        assert(map.lines[1].thickness == 1.5)
        assert(map.lines[1].start[3] == 250 and map.lines[1].start[4] == -125)
        assert(map.labels[1].value == "1" and map.labels[3].value == "3")
        assert(map.frame.hidden == false)
        assert(addon.RouteMap:refresh())
        assert(#map.lines == 3 and #map.dots == 3 and #map.labels == 3)
        setMap(8)
        assert(addon.RouteMap:refresh() == false and map.frame.hidden == true)
        addon.RoutePlan:clear()
        assert(map.frame.hidden == true)
    end,
    ["route map no crea nada en combate y se dibuja al salir"] = function(addon, mock)
        mapFrame(mock, 7)
        addon.RoutePlan.active = { mapID = 7, route = { stops = stops(3), points = 3 } }
        mock.combat = true
        assert(addon.RouteMap:refresh() == false)
        assert(addon.RouteMap.frame == nil and addon.RouteMap.pending == true)
        mock.combat = false
        mock.fire("PLAYER_REGEN_ENABLED")
        assert(addon.RouteMap.frame and #addon.RouteMap.lines == 3 and addon.RouteMap.pending == false)
        addon.RoutePlan:clear()
    end,
    ["route map en combate oculta su marco si el plan no es de su mapa"] = function(addon, mock)
        mapFrame(mock, 7)
        addon.RoutePlan.active = { mapID = 7, route = { stops = stops(2), points = 2 } }
        assert(addon.RouteMap:refresh())
        local map = addon.RouteMap
        local lines, dots = #map.lines, #map.dots
        assert(map.frame.hidden == false)
        mock.combat = true
        addon.RoutePlan.active = { mapID = 9, route = { stops = stops(3), points = 3 } }
        assert(addon.RouteMap:refresh() == false)
        assert(map.pending == true and map.frame.hidden == true)
        assert(#map.lines == lines and #map.dots == dots)
        addon.RoutePlan:clear()
        assert(addon.RouteMap:refresh() == false and map.frame.hidden == true)
        assert(#map.lines == lines and #map.dots == dots)
        mock.combat = false
    end,
    ["route plan lee el mapa, el nombre y el aspecto del juego"] = function(addon, mock)
        C_Map = {
            GetBestMapForUnit = function(unit) if unit == "player" then return 7 end end,
            GetMapInfo = function(id) if id == 7 then return { name = "Testland" } end end,
            GetMapWorldSize = function() return 2000, 1000 end,
        }
        assert(addon.RoutePlan.currentMap() == 7)
        assert(addon.RoutePlan.mapName(7) == "Testland" and addon.RoutePlan.mapName(9) == "#9")
        local aspect, width = addon.RoutePlan.aspect(7)
        assert(aspect == 2 and width == 2000)
        C_Map.GetMapWorldSize = function() return 0, 0 end
        aspect, width = addon.RoutePlan.aspect(7)
        assert(aspect == addon.Routes.defaults.aspect and width == nil)
        C_Map.GetBestMapForUnit = nil
        C_Map.GetMapInfo = nil
        assert(addon.RoutePlan.currentMap() == nil and addon.RoutePlan.mapName(9) == "#9")
    end,
    ["route plan calcula la ruta con precios, clasifica y mide en yardas"] = function(addon, mock)
        local originalDB = GoldPilotDB
        mock.items[1000] = { name = "Herb", class = 7, subclass = 9 }
        mock.items[2000] = { name = "Ore", class = 7, subclass = 7 }
        local function priced(value)
            return { last = { t = 199000, min = value, p50 = value, qty = 20 } }
        end
        local house = addon.AuctionHouse.houseKey()
        GoldPilotDB = {
            prices = { [house] = { [1000] = priced(500), [2000] = priced(800) } },
            houses = { [house] = { cut = 0.05 } },
            nodes = { [7] = {
                [100] = { gathers = 1, items = { [1000] = 2 },
                    spots = { { x = 1000, y = 1000, n = 1 }, { x = 4000, y = 2000, n = 1 },
                        { x = 7000, y = 3000, n = 1 } } },
                [200] = { gathers = 1, items = { [2000] = 1 },
                    spots = { { x = 2000, y = 4000, n = 1 }, { x = 5000, y = 5000, n = 1 },
                        { x = 8000, y = 6000, n = 1 } } },
            } },
        }
        C_Map = {
            GetBestMapForUnit = function() return 7 end,
            GetMapInfo = function() return { name = "Testland" } end,
            GetMapWorldSize = function() return 2000, 1000 end,
        }
        local plan = addon.RoutePlan.compute(7)
        assert(plan.mapID == 7 and plan.kind == nil and plan.route ~= nil)
        assert(plan.stats.own == 6 and plan.stats.seed == 0)
        assert(plan.skills.known == false and plan.yards and plan.yards > 0 and plan.at == 200000)
        local herbs = addon.RoutePlan.compute(7, "herb")
        assert(herbs.route and herbs.stats.own == 3)
        local ores = addon.RoutePlan.compute(7, "ore")
        assert(ores.route and ores.stats.own == 3)
        mock.items[1000].subclass = 7
        local mixed = addon.RoutePlan.compute(7, "herb")
        assert(mixed.route == nil and mixed.stats.own == 0)
        GoldPilotDB = originalDB
    end,
}
