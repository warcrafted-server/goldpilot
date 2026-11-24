local function near(a, b, epsilon)
    return math.abs(a - b) <= (epsilon or 1e-9)
end

local function unitAll(value)
    return function() return value end
end

return {
    ["kinds lee la semilla, ignora otros tipos y conserva el item no nulo"] = function(addon)
        addon.DataNodeSeeds = {
            "hierba;100;3;12;4;seed",
            "mineral;101;0;12;2;obs",
            "banco de pesca;102;0;12;1;seed",
            "hierba;100;7;13;1;seed",
        }
        local kinds = addon.Routes.kinds()
        assert(kinds[100].kind == "herb" and kinds[100].itemID == 3)
        assert(kinds[101].kind == "ore" and kinds[101].itemID == nil)
        assert(kinds[102] == nil)
        addon.DataNodeSeeds = { "hierba;200;9;12;1;seed" }
        assert(addon.Routes.kinds() == kinds and addon.Routes.kinds()[200] == nil)
    end,
    ["kinds sin semilla devuelve una tabla vacía"] = function(addon)
        addon.DataNodeSeeds = nil
        local kinds = addon.Routes.kinds()
        assert(type(kinds) == "table" and next(kinds) == nil)
        addon.DataNodeSeeds = {}
        assert(addon.Routes.kinds() == kinds)
    end,
    ["puntos valoran por recogida y los propios mandan sobre la semilla"] = function(addon)
        addon.DataNodeSeeds = {
            "hierba;100;10;1;1;seed",
            "mineral;200;20;1;1;seed",
        }
        local db = { nodes = { [1] = {
            [100] = { n = 5, gathers = 2, items = { [10] = 4 },
                spots = { { x = 1000, y = 1000, n = 2 } } },
            [200] = { n = 2, gathers = 1, items = { [20] = 1 },
                spots = { { x = 5000, y = 5000, n = 1 }, { x = 6000, y = 5000, n = 1 } } },
        } } }
        local spots = { [1] = {
            [100] = { kind = "herb", skill = 1, p = "1000,1000;1050,1050;9000,9000" },
            [200] = { kind = "ore", skill = 1, p = "5000,5000" },
        } }
        local points, stats = addon.Routes.points(db, 1, { spots = spots,
            unit = function(key) return ({ [10] = 300, [20] = 100 })[key] end })
        assert(#points == 4 and stats.own == 3 and stats.seed == 1)
        assert(stats.unpriced == 0 and stats.skill == 0)
        assert(points[1].source == "own" and points[1].object == 100 and near(points[1].weight, 600))
        assert(points[1].x == 0.1 and points[1].y == 0.1 and points[1].n == 2 and points[1].kind == "herb")
        assert(points[2].object == 200 and near(points[2].weight, 100))
        assert(points[3].object == 200 and points[3].x == 0.6)
        assert(points[4].source == "seed" and points[4].object == 100 and points[4].x == 0.9)
        assert(near(points[4].weight, 600))
    end,
    ["puntos clasifican por las claves del botín"] = function(addon)
        addon.DataNodeSeeds = nil
        local db = { nodes = { [1] = {
            [400] = { gathers = 1, items = { [55] = 2 }, spots = { { x = 1000, y = 1000, n = 1 } } },
            [401] = { gathers = 1, items = { [66] = 1 }, spots = { { x = 5000, y = 5000, n = 1 } } },
        } } }
        local classify = function(key) if key == 55 then return "herb" end return nil end
        local points, stats = addon.Routes.points(db, 1, {
            classify = classify,
            unit = function(key) if key == 55 then return 50 end return nil end,
        })
        assert(#points == 1 and points[1].object == 400 and points[1].kind == "herb")
        assert(near(points[1].weight, 100) and stats.unpriced == 0)
    end,
    ["puntos descuentan los objetos sin precio"] = function(addon)
        addon.DataNodeSeeds = { "hierba;400;55;1;1;seed" }
        local db = { nodes = { [1] = {
            [400] = { gathers = 1, items = { [55] = 2 }, spots = { { x = 1000, y = 1000, n = 1 } } },
        } } }
        local points, stats = addon.Routes.points(db, 1, { unit = unitAll(nil) })
        assert(#points == 0 and stats.unpriced == 1)
    end,
    ["puntos filtran por la habilidad conocida y la profesión ausente"] = function(addon)
        addon.DataNodeSeeds = {
            "hierba;100;10;1;1;seed",
            "mineral;200;20;1;1;seed",
            "hierba;300;30;1;1;seed",
        }
        local db = { nodes = { [1] = {
            [100] = { gathers = 1, items = { [10] = 1 }, spots = { { x = 1000, y = 1000, n = 1 } } },
            [200] = { gathers = 1, items = { [20] = 1 },
                spots = { { x = 5000, y = 5000, n = 1 }, { x = 6000, y = 5000, n = 1 } } },
            [300] = { gathers = 1, items = { [30] = 1 }, spots = { { x = 8000, y = 8000, n = 1 } } },
        } } }
        local spots = { [1] = {
            [100] = { kind = "herb", skill = 50, p = "3000,3000" },
            [300] = { kind = "herb", skill = 100, p = "7000,7000;7100,7100" },
        } }
        local points, stats = addon.Routes.points(db, 1, { spots = spots, unit = unitAll(100),
            skills = { herb = 40, ore = 60, known = true } })
        assert(#points == 2 and stats.own == 2 and stats.seed == 0 and stats.skill == 5)
        points, stats = addon.Routes.points(db, 1, { spots = spots, unit = unitAll(100),
            skills = { herb = 80, ore = 60, known = true } })
        assert(#points == 4 and stats.own == 3 and stats.seed == 1 and stats.skill == 3)
        points, stats = addon.Routes.points(db, 1, { spots = spots, unit = unitAll(100),
            skills = { herb = 80, known = true } })
        assert(#points == 2 and stats.own == 1 and stats.seed == 1 and stats.skill == 5)
        points, stats = addon.Routes.points(db, 1, { spots = spots, unit = unitAll(100),
            skills = { ore = 66, known = true } })
        assert(#points == 2 and stats.own == 2 and stats.skill == 5)
    end,
    ["puntos sin habilidad conocida no filtran"] = function(addon)
        addon.DataNodeSeeds = { "hierba;100;10;1;1;seed", "hierba;300;30;1;1;seed" }
        local db = { nodes = { [1] = {
            [100] = { gathers = 1, items = { [10] = 1 }, spots = { { x = 1000, y = 1000, n = 1 } } },
            [300] = { gathers = 1, items = { [30] = 1 }, spots = { { x = 8000, y = 8000, n = 1 } } },
        } } }
        local spots = { [1] = {
            [100] = { kind = "herb", skill = 50, p = "3000,3000" },
            [300] = { kind = "herb", skill = 100, p = "7000,7000;7100,7100" },
        } }
        local points, stats = addon.Routes.points(db, 1, { spots = spots, unit = unitAll(100),
            skills = { known = false } })
        assert(#points == 5 and stats.own == 2 and stats.seed == 3 and stats.skill == 0)
        points, stats = addon.Routes.points(db, 1, { spots = spots, unit = unitAll(100) })
        assert(#points == 5 and stats.skill == 0)
    end,
    ["puntos aplican el factor y el filtro de tipo"] = function(addon)
        addon.DataNodeSeeds = { "hierba;100;10;1;1;seed", "mineral;200;20;1;1;seed" }
        local db = { nodes = { [1] = {
            [100] = { gathers = 1, items = { [10] = 1 }, spots = { { x = 1000, y = 1000, n = 1 } } },
            [200] = { gathers = 1, items = { [20] = 1 }, spots = { { x = 5000, y = 5000, n = 1 } } },
        } } }
        local points = addon.Routes.points(db, 1, { unit = unitAll(100), kind = "herb",
            factor = function(x) if x == 0.1 then return 2 end return nil end })
        assert(#points == 1 and points[1].object == 100 and near(points[1].weight, 200))
        points = addon.Routes.points(db, 1, { unit = unitAll(100) })
        assert(#points == 2 and near(points[1].weight, 100))
    end,
    ["puntos limitan a maxPoints, priorizan propios en empates y son deterministas"] = function(addon)
        addon.Routes.defaults.maxPoints = 3
        addon.DataNodeSeeds = { "hierba;100;10;1;1;seed" }
        local db = { nodes = { [1] = {
            [100] = { gathers = 1, items = { [10] = 1 }, spots = { { x = 5000, y = 5000, n = 1 } } },
        } } }
        local spots = { [1] = {
            [100] = { kind = "herb", p = "100,100;200,100;300,100;400,100;500,100" },
        } }
        local first, stats = addon.Routes.points(db, 1, { spots = spots, unit = unitAll(100) })
        local second = addon.Routes.points(db, 1, { spots = spots, unit = unitAll(100) })
        assert(#first == 3 and stats.own == 1 and stats.seed == 2)
        assert(first[1].source == "own" and first[1].x == 0.5)
        assert(first[2].x == 0.01 and first[3].x == 0.02)
        assert(#second == 3)
        for index = 1, 3 do
            assert(first[index].x == second[index].x and first[index].y == second[index].y)
        end
    end,
    ["build agrupa vecinos en paradas"] = function(addon)
        local points = {}
        for _, center in ipairs({ 0.1, 0.5, 0.9 }) do
            points[#points + 1] = { x = center, y = 0.1, weight = 10, object = 100 }
            points[#points + 1] = { x = center + 0.001, y = 0.1, weight = 10, object = 100 }
        end
        local route = addon.Routes.build(points, { aspect = 1 })
        assert(route and #route.stops == 3 and route.points == 6 and near(route.weight, 60))
        for _, stop in ipairs(route.stops) do assert(stop.count == 2 and stop.objects[100] == 2) end
        assert(near(route.length, 1.6, 1e-6))
    end,
    ["build deshace un cruce con 2-opt"] = function(addon)
        addon.Routes.defaults.minStops = 5
        local coordinates = { { 0.05, 0.05 }, { 0.05, 0.1 }, { 0.05, 0.2 }, { 0.1, 0.05 },
            { 0.15, 0.2 } }
        local points = {}
        for _, coordinate in ipairs(coordinates) do
            points[#points + 1] = { x = coordinate[1], y = coordinate[2], weight = 1, object = 100 }
        end
        local route = addon.Routes.build(points, { aspect = 1 })
        assert(route and #route.stops == 5 and near(route.length, 0.458113883008419, 1e-9))
        local expected = { { 0.1, 0.05 }, { 0.05, 0.05 }, { 0.05, 0.1 }, { 0.05, 0.2 },
            { 0.15, 0.2 } }
        for index, coordinate in ipairs(expected) do
            assert(route.stops[index].x == coordinate[1] and route.stops[index].y == coordinate[2])
        end
        local again = addon.Routes.build(points, { aspect = 1 })
        assert(again and near(again.length, route.length))
        for index = 1, 5 do
            assert(again.stops[index].x == route.stops[index].x
                and again.stops[index].y == route.stops[index].y)
        end
    end,
    ["build poda la parada lejana y pobre"] = function(addon)
        local points = {}
        for _, data in ipairs({ { 0.10, 0.10, 100 }, { 0.15, 0.10, 100 }, { 0.20, 0.10, 100 },
            { 0.10, 0.15, 100 }, { 0.15, 0.15, 100 }, { 0.90, 0.90, 1 } }) do
            points[#points + 1] = { x = data[1], y = data[2], weight = data[3], object = 100 }
        end
        local route = addon.Routes.build(points, { aspect = 1 })
        assert(route and #route.stops >= 3)
        for _, stop in ipairs(route.stops) do
            assert(not (near(stop.x, 0.9, 1e-9) and near(stop.y, 0.9, 1e-9)))
        end
        assert(#route.stops == 4 and route.points == 4)
    end,
    ["build devuelve nil con menos de tres paradas y tolera entradas vacías"] = function(addon)
        assert(addon.Routes.build(nil) == nil)
        assert(addon.Routes.build({}) == nil)
        assert(addon.Routes.build({ { x = 0, y = 0, weight = 1 }, { x = 1, y = 1, weight = 1 } }) == nil)
        assert(addon.Routes.build({ { x = 0, y = 0 }, { x = 1, y = 1 }, { x = 1, y = 0 } }) == nil)
        local points, stats = addon.Routes.points(nil, nil, nil)
        assert(#points == 0 and stats.own == 0 and stats.seed == 0 and stats.unpriced == 0
            and stats.skill == 0)
        points, stats = addon.Routes.points({}, 1, { spots = {} })
        assert(#points == 0 and stats.own == 0)
        points = addon.Routes.points({ nodes = { [1] = { [100] = {} } } }, 1, {})
        assert(#points == 0)
        assert(addon.Routes.build({}) == nil)
    end,
}
