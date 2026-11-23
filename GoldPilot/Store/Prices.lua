local _, addon = ...

local Prices = {}
addon.Prices = Prices

Prices.defaults = { share = 0.15, dailyDays = 90, weeklyWeeks = 52, staleDays = 180 }

local function options(opts)
    local result = {}
    for key, value in pairs(Prices.defaults) do result[key] = value end
    for key, value in pairs(opts or {}) do result[key] = value end
    return result
end

local function entryMap(entries)
    local result = {}
    for _, entry in ipairs(entries or {}) do result[entry[1]] = { entry[1], entry[2], entry[3], entry[4] } end
    return result
end

local function sortedEntries(map)
    local keys = {}
    for key in pairs(map) do keys[#keys + 1] = key end
    table.sort(keys)
    local result = {}
    for _, key in ipairs(keys) do result[#result + 1] = map[key] end
    return result
end

function Prices.summarize(listings, share)
    if type(listings) ~= "table" then return nil end
    local sorted, qty = {}, 0
    for _, listing in ipairs(listings) do
        local price, count = tonumber(listing.price), tonumber(listing.qty)
        if price and count and count > 0 then
            sorted[#sorted + 1] = { price = price, qty = count }
            qty = qty + count
        end
    end
    if qty <= 0 then return nil end
    table.sort(sorted, function(a, b) return a.price < b.price end)
    local target = math.max(1, math.ceil(qty * (tonumber(share) or Prices.defaults.share)))
    local medianPosition = math.ceil(target / 2)
    local covered, p50 = 0, nil
    for _, listing in ipairs(sorted) do
        if not p50 and covered + listing.qty >= medianPosition then p50 = listing.price end
        covered = covered + listing.qty
        if covered >= target then break end
    end
    return { min = sorted[1].price, p50 = p50, qty = qty }
end

function Prices.pack(entries)
    local result = {}
    for _, entry in ipairs(entries or {}) do
        result[#result + 1] = string.format("%.0f:%.0f:%.0f:%.0f", entry[1], entry[2], entry[3], entry[4])
    end
    return table.concat(result, ";")
end

function Prices.unpack(value)
    local result = {}
    if type(value) ~= "string" or value == "" then return result end
    for part in string.gmatch(value, "[^;]+") do
        local k, min, p50, qty = string.match(part, "^([^:]+):([^:]+):([^:]+):([^:]+)$")
        if k then
            result[#result + 1] = { tonumber(k), tonumber(min), tonumber(p50), tonumber(qty) }
        end
    end
    return result
end

function Prices.ensure(db, houseKey)
    db.prices = db.prices or {}
    db.prices[houseKey] = db.prices[houseKey] or {}
    return db.prices[houseKey]
end

function Prices.record(db, houseKey, itemKey, summary, now)
    if not summary then return end
    local house = Prices.ensure(db, houseKey)
    local item = house[itemKey] or {}
    house[itemKey] = item
    local day = math.floor(now / 86400)
    local daily = entryMap(Prices.unpack(item.d))
    local current = daily[day]
    if current then
        current[2] = math.min(current[2], summary.min)
        current[3], current[4] = summary.p50, summary.qty
    else
        daily[day] = { day, summary.min, summary.p50, summary.qty }
    end
    item.d = Prices.pack(sortedEntries(daily))
    if not item.last or now >= item.last.t then
        item.last = { t = now, min = summary.min, p50 = summary.p50, qty = summary.qty, src = "OBS" }
    end
end

function Prices.get(db, houseKey, itemKey)
    local house = db and db.prices and db.prices[houseKey]
    local item = house and house[itemKey]
    return item and item.last or nil
end

function Prices.history(db, houseKey, itemKey)
    local house = db and db.prices and db.prices[houseKey]
    local item = house and house[itemKey]
    return { daily = Prices.unpack(item and item.d or ""), weekly = Prices.unpack(item and item.w or "") }
end

local function lowerMedian(values)
    table.sort(values)
    return values[math.floor((#values + 1) / 2)]
end

function Prices.prune(db, now, opts)
    local config = options(opts)
    local today, thisWeek = math.floor(now / 86400), math.floor(math.floor(now / 86400) / 7)
    local stats = { movedDays = 0, droppedWeeks = 0, droppedItems = 0 }
    local prices = db.prices or {}
    for houseKey, house in pairs(prices) do
        for itemKey, item in pairs(house) do
            local daily, weekly = entryMap(Prices.unpack(item.d)), entryMap(Prices.unpack(item.w))
            local moved = {}
            for day, entry in pairs(daily) do
                if day < today - config.dailyDays then
                    daily[day] = nil
                    local week = math.floor(day / 7)
                    moved[week] = moved[week] or {}
                    moved[week][#moved[week] + 1] = entry
                    stats.movedDays = stats.movedDays + 1
                end
            end
            for week, entries in pairs(moved) do
                local old = weekly[week]
                local mins, medians, totalQty, count = {}, {}, 0, 0
                if old then
                    mins[#mins + 1], medians[#medians + 1] = old[2], old[3]
                    totalQty, count = old[4], 1
                end
                for _, entry in ipairs(entries) do
                    mins[#mins + 1], medians[#medians + 1] = entry[2], entry[3]
                    totalQty, count = totalQty + entry[4], count + 1
                end
                table.sort(mins)
                weekly[week] = { week, mins[1], lowerMedian(medians), math.floor(totalQty / count) }
            end
            for week in pairs(weekly) do
                if week < thisWeek - config.weeklyWeeks then
                    weekly[week] = nil
                    stats.droppedWeeks = stats.droppedWeeks + 1
                end
            end
            item.d = Prices.pack(sortedEntries(daily))
            item.w = Prices.pack(sortedEntries(weekly))
            if item.d == "" then item.d = nil end
            if item.w == "" then item.w = nil end
            if item.last and item.last.t < now - config.staleDays * 86400 and not (db.watch and db.watch[itemKey]) then
                house[itemKey] = nil
                stats.droppedItems = stats.droppedItems + 1
            end
        end
        if next(house) == nil then prices[houseKey] = nil end
    end
    return stats
end
