local function near(a, b, epsilon)
    return math.abs(a - b) <= (epsilon or 1e-9)
end

return {
    ["visits redondean la celda, separan el tipo y toleran datos inválidos"] = function(addon)
        assert(addon.Visits.cell(nil, 0.15, 0.25) == "all:7:12")
        assert(addon.Visits.cell("herb", 0.15, 0.25) == "herb:7:12")
        assert(addon.Visits.cell("ore", 1, 1) == "ore:50:50")
        assert(addon.Visits.cell("otro", 0, 0) == "all:0:0")
        assert(addon.Visits.cell("herb", -0.1, 0.5) == nil)
        assert(addon.Visits.cell("herb", 0.5, 1.1) == nil)
        assert(addon.Visits.cell("herb", nil, 0.5) == nil)
        local db = {}
        assert(addon.Visits.record(db, 0, {}, {}, 10) == false)
        assert(addon.Visits.record(db, 1, nil, {}, 10) == false)
        assert(db.routeVisits == nil)
        assert(addon.Visits.factor(nil, 1, "herb", 0.5, 0.5) == 1)
        local visits, hits = addon.Visits.totals(db, 1, "herb")
        assert(visits == 0 and hits == 0)
        assert(addon.Visits.prune(nil, 10) == false)
    end,
    ["visits cuentan visitas y aciertos y el factor premia los nodos"] = function(addon)
        local db = {}
        local a = addon.Visits.cell(nil, 0.15, 0.25)
        local b = addon.Visits.cell(nil, 0.55, 0.55)
        assert(addon.Visits.record(db, 7, { [a] = true, [b] = true }, { [a] = true }, 100))
        local first, second = db.routeVisits[7][a], db.routeVisits[7][b]
        assert(first.v == 1 and first.h == 1 and first.t == 100)
        assert(second.v == 1 and second.h == 0 and second.t == 100)
        assert(near(addon.Visits.factor(db, 7, nil, 0.15, 0.25), 1))
        assert(near(addon.Visits.factor(db, 7, "all", 0.55, 0.55), 2 / 3))
        assert(near(addon.Visits.factor(db, 7, "herb", 0.55, 0.55), 1))
        addon.Visits.record(db, 7, { [a] = true, [b] = true }, { [a] = true }, 200)
        assert(first.v == 2 and first.h == 2 and first.t == 200)
        assert(second.v == 2 and second.h == 0 and second.t == 200)
        local visits, hits = addon.Visits.totals(db, 7, nil)
        assert(visits == 4 and hits == 2)
        assert(select(1, addon.Visits.totals(db, 7, "herb")) == 0)
        assert(first.h <= first.v and second.h <= second.v)
    end,
    ["visits ignoran los aciertos de celdas no visitadas y reducen al llegar al tope"] = function(addon)
        local db = {}
        local a = addon.Visits.cell("ore", 0.15, 0.25)
        local other = addon.Visits.cell("ore", 0.75, 0.75)
        addon.Visits.record(db, 3, { [a] = true }, { [other] = true }, 1)
        assert(db.routeVisits[3][a].v == 1 and db.routeVisits[3][a].h == 0)
        assert(db.routeVisits[3][other] == nil)
        for index = 2, 20 do
            addon.Visits.record(db, 3, { [a] = true }, { [a] = true }, index)
        end
        local entry = db.routeVisits[3][a]
        assert(entry.v == 10 and entry.h == 9 and entry.t == 20)
        addon.Visits.record(db, 3, { [a] = true }, { [a] = true }, 21)
        assert(entry.v == 11 and entry.h == 10)
    end,
    ["visits podan celdas viejas y mapas vacíos"] = function(addon)
        local db = {}
        local now = 1000000
        local day = 86400
        local old = addon.Visits.cell(nil, 0.15, 0.25)
        local fresh = addon.Visits.cell(nil, 0.55, 0.55)
        local elsewhere = addon.Visits.cell("ore", 0.5, 0.5)
        addon.Visits.record(db, 7, { [old] = true }, {}, now - 61 * day)
        addon.Visits.record(db, 7, { [fresh] = true }, {}, now - 59 * day)
        addon.Visits.record(db, 8, { [elsewhere] = true }, {}, now - 61 * day)
        assert(addon.Visits.prune(db, now))
        assert(db.routeVisits[7][old] == nil and db.routeVisits[7][fresh] ~= nil)
        assert(db.routeVisits[8] == nil)
        assert(addon.Visits.prune(db, now + 2 * day))
        assert(db.routeVisits == nil)
    end,
}
