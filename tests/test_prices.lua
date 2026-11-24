return {
    ["prices resume unidades baratas con mediana ponderada"] = function(addon)
        local result = addon.Prices.summarize({
            { price = 1, qty = 1 }, { price = 10, qty = 100 }, { price = 20, qty = 100 },
        })
        assert(result.min == 1 and result.p50 == 10 and result.qty == 201)
        assert(addon.Prices.summarize({}) == nil)
    end,
    ["prices empaqueta y desempaqueta sin pérdida"] = function(addon)
        local entries = { { 4, 10, 12, 20 }, { 5, 8, 9, 30 } }
        local packed = addon.Prices.pack(entries)
        assert(packed == "4:10:12:20;5:8:9:30")
        local decoded = addon.Prices.unpack(packed)
        assert(#decoded == 2 and decoded[1][1] == 4 and decoded[2][4] == 30)
        assert(#addon.Prices.unpack("") == 0 and #addon.Prices.unpack(nil) == 0)
    end,
    ["prices registra por día y conserva el último dato cronológico"] = function(addon)
        local db, day = {}, 100
        addon.Prices.record(db, "h", "i", { min = 10, p50 = 12, qty = 4 }, day * 86400 + 10)
        assert(type(db.prices.h.i) == "string")
        addon.Prices.record(db, "h", "i", { min = 8, p50 = 9, qty = 7 }, day * 86400 + 20)
        local last = addon.Prices.get(db, "h", "i")
        assert(last.t == day * 86400 + 20 and last.min == 8 and last.p50 == 9 and last.src == "OBS")
        local daily = addon.Prices.history(db, "h", "i").daily
        assert(#daily == 1 and daily[1][2] == 8 and daily[1][3] == 9 and daily[1][4] == 7)
        addon.Prices.record(db, "h", "i", { min = 5, p50 = 6, qty = 2 }, (day - 1) * 86400)
        last = addon.Prices.get(db, "h", "i")
        daily = addon.Prices.history(db, "h", "i").daily
        assert(last.t == day * 86400 + 20 and #daily == 2 and daily[1][1] == day - 1)
    end,
    ["prices poda a semanas, elimina antigüedad y es idempotente"] = function(addon)
        local db = { watch = { [25] = true }, prices = { h = {
            [25] = { last = { t = 702 * 86400, p50 = 4 }, d = "699:10:20:4;700:8:10:8;701:6:8:12", w = "90:5:7:2" },
            [26] = { last = { t = 702 * 86400, min = 1, p50 = 4, qty = 1 }, d = "", w = "" },
            removable = { last = { t = 1, p50 = 4 }, d = "", w = "" },
        } } }
        local now = 703 * 86400
        local result = addon.Prices.prune(db, now, { dailyDays = 2, weeklyWeeks = 2, staleDays = 1 })
        local item = db.prices.h[25]
        local history = addon.Prices.history(db, "h", 25)
        assert(result.movedDays == 2 and result.droppedWeeks == 1 and result.droppedItems == 1)
        assert(#history.daily == 1 and history.daily[1][1] == 701 and #history.weekly == 2)
        assert(history.weekly[1][1] == 99 and history.weekly[1][2] == 10 and history.weekly[1][3] == 20 and history.weekly[1][4] == 4)
        assert(history.weekly[2][1] == 100 and history.weekly[2][2] == 8 and history.weekly[2][3] == 10 and history.weekly[2][4] == 8)
        assert(db.prices.h[26] and not db.prices.h.removable)
        assert(type(item) == "string")
        local second = addon.Prices.prune(db, now, { dailyDays = 2, weeklyWeeks = 2, staleDays = 1 })
        assert(second.movedDays == 0 and second.droppedWeeks == 0 and second.droppedItems == 0)
    end,
    ["prices elimina casa vacía"] = function(addon)
        local db = { prices = { empty = {} } }
        addon.Prices.prune(db, 100)
        assert(db.prices.empty == nil)
    end,
    ["prices mantiene presupuesto con mil objetos"] = function(addon)
        local db = { prices = { h = {} } }
        for item = 1, 1000 do
            local daily, weekly = {}, {}
            for day = 20400, 20489 do
                daily[#daily + 1] = { day, 1200000 + item, 1500000 + item, 1000 + item }
            end
            for week = 2900, 2951 do
                weekly[#weekly + 1] = { week, 1200000 + item, 1500000 + item, 1000 + item }
            end
            db.prices.h["item-" .. item] = {
                last = { t = (20489 * 86400) + 43200, min = 1200000 + item, p50 = 1500000 + item, qty = 1000 + item, src = "OBS" },
                d = addon.Prices.pack(daily),
                w = addon.Prices.pack(weekly),
            }
        end
        local function serialize(value)
            if type(value) == "string" then return string.format("%q", value) end
            if type(value) ~= "table" then return tostring(value) end
            local parts = { "{" }
            for key, child in pairs(value) do
                local serializedKey = type(key) == "string" and "[" .. string.format("%q", key) .. "]" or "[" .. tostring(key) .. "]"
                parts[#parts + 1] = serializedKey .. "=" .. serialize(child) .. ","
            end
            parts[#parts + 1] = "}"
            return table.concat(parts)
        end
        local bytes = #("GoldPilotDB = " .. serialize(db))
        assert(bytes < 5 * 1024 * 1024)
    end,
    ["prices calcula la tendencia frente a un día anterior"] = function(addon)
        local db, day = {}, 100
        assert(addon.Prices.trend(db, "h", "i", day * 86400) == nil)
        addon.Prices.record(db, "h", "i", { min = 8, p50 = 100, qty = 4 }, (day - 1) * 86400 + 5)
        assert(addon.Prices.trend(db, "h", "i", (day - 1) * 86400 + 9) == nil)
        addon.Prices.record(db, "h", "i", { min = 8, p50 = 112, qty = 4 }, day * 86400 + 5)
        local trend = addon.Prices.trend(db, "h", "i", day * 86400 + 9)
        assert(trend.percent == 12 and trend.days == 1)
    end,
    ["prices codifica los historiales y lee valores antiguos"] = function(addon)
        local db = {}
        addon.Prices.record(db, "h", 25, { min = 1.9, p50 = 3.8, qty = 2.9 }, 86400)
        assert(db.prices.h[25] == "86400:1:3:2|1:1:3:2|")
        assert(addon.Prices.get(db, "h", 25).src == "OBS")
        local legacy = { last = { t = 7, min = 8, p50 = 9, qty = 10, src = "BAD" }, d = "1:2:3:4", w = "2:3:4:5" }
        db.prices.h[26] = legacy
        assert(addon.Prices.get(db, "h", 26).src == "OBS")
        assert(#addon.Prices.history(db, "h", 26).daily == 1 and #addon.Prices.history(db, "h", 26).weekly == 1)
        addon.Prices.record(db, "h", 26, { min = 1.5, p50 = 2.5, qty = 3.5 }, 8)
        assert(type(db.prices.h[26]) == "string" and addon.Prices.get(db, "h", 26).min == 1)
    end,
    ["prices distingue claves seguidas, numéricas y variantes"] = function(addon)
        local set = addon.Prices.interested({ chars = { c = { bags = { [25] = 1 }, bank = { [26] = 1 }, equipped = { [27] = 1 } } }, watch = { ["28:9"] = true }, reserved = { [29] = 1 } })
        assert(addon.Prices.depth(25, set) == 90 and addon.Prices.depth("25:99", set) == 90)
        assert(addon.Prices.depth(30, set) == 7 and addon.Prices.depth("30:99", set) == 2)
        assert(addon.Prices.depth("28:9", set) == 90 and addon.Prices.depth(29, set) == 90)
    end,
    ["prices poda las variantes sin interés y no acumula semanas"] = function(addon)
        local now = 300 * 86400
        local db = { prices = { h = { ["100:2"] = { last = { t = now, min = 1, p50 = 2, qty = 3 }, d = "290:1:2:3;298:4:5:6", w = "20:1:2:3" } } } }
        addon.Prices.prune(db, now)
        local history = addon.Prices.history(db, "h", "100:2")
        assert(#history.daily == 1 and history.daily[1][1] == 298 and #history.weekly == 0)
    end,
    ["prices usa caducidad de 180 y 30 días"] = function(addon)
        local now = 500 * 86400
        local db = { chars = { c = { bags = { [1] = 1 } } }, prices = { h = {
            [1] = { last = { t = now - 181 * 86400, min = 1, p50 = 1, qty = 1 } },
            [2] = { last = { t = now - 31 * 86400, min = 1, p50 = 1, qty = 1 } },
        } } }
        addon.Prices.prune(db, now)
        assert(db.prices.h == nil)
    end,
    ["prices mantiene bajo 5 MB el conjunto intensivo de claves"] = function(addon)
        local db = { prices = { h = {} } }
        local daily7, daily2 = {}, {}
        for day = 30000, 30006 do daily7[#daily7 + 1] = { day, 120000, 150000, 100 } end
        for day = 30005, 30006 do daily2[#daily2 + 1] = { day, 120000, 150000, 100 } end
        local d7, d2 = addon.Prices.pack(daily7), addon.Prices.pack(daily2)
        for id = 1, 7000 do db.prices.h[id] = "2592000000:120000:150000:100|" .. d7 .. "|" end
        for id = 100000, 128999 do db.prices.h[tostring(id) .. ":1"] = "2592000000:120000:150000:100|" .. d2 .. "|" end
        local bytes = 0
        for key, value in pairs(db.prices.h) do bytes = bytes + #tostring(key) + #value + 10 end
        assert(bytes < 5 * 1024 * 1024)
    end,

}
