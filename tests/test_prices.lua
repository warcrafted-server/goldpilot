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
        assert(db.prices.h.i.w == nil)
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
        local db = { watch = { watched = true }, prices = { h = {
            item = { last = { t = 702 * 86400, p50 = 4 }, d = "699:10:20:4;700:8:10:8;701:6:8:12", w = "90:5:7:2" },
            watched = { last = { t = 1, p50 = 4 }, d = "", w = "" },
            removable = { last = { t = 1, p50 = 4 }, d = "", w = "" },
        } } }
        local now = 703 * 86400
        local result = addon.Prices.prune(db, now, { dailyDays = 2, weeklyWeeks = 2, staleDays = 1 })
        local item = db.prices.h.item
        local history = addon.Prices.history(db, "h", "item")
        assert(result.movedDays == 2 and result.droppedWeeks == 1 and result.droppedItems == 1)
        assert(#history.daily == 1 and history.daily[1][1] == 701 and #history.weekly == 2)
        assert(history.weekly[1][1] == 99 and history.weekly[1][2] == 10 and history.weekly[1][3] == 20 and history.weekly[1][4] == 4)
        assert(history.weekly[2][1] == 100 and history.weekly[2][2] == 8 and history.weekly[2][3] == 10 and history.weekly[2][4] == 8)
        assert(db.prices.h.watched and not db.prices.h.removable)
        assert(item.d ~= nil)
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
}
