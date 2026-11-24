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

local function integer(value)
    return math.max(1, math.floor(tonumber(value) or 1))
end

local function encoded(last, daily, weekly)
    return string.format("%.0f:%.0f:%.0f:%.0f|%s|%s", last.t, integer(last.min), integer(last.p50),
        integer(last.qty), daily or "", weekly or "")
end

local function decode(value)
    if type(value) == "table" then
        local last = value.last
        if type(last) ~= "table" then return nil, value.d or "", value.w or "" end
        return last, value.d or "", value.w or ""
    end
    if type(value) ~= "string" then return nil, "", "" end
    local last, daily, weekly = string.match(value, "^([^|]*)|([^|]*)|([^|]*)$")
    if not last then return nil, "", "" end
    local t, min, p50, qty = string.match(last, "^([^:]+):([^:]+):([^:]+):([^:]+)$")
    if not t then return nil, daily, weekly end
    return { t = tonumber(t), min = tonumber(min), p50 = tonumber(p50), qty = tonumber(qty), src = "OBS" }, daily, weekly
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
        result[#result + 1] = string.format("%.0f:%.0f:%.0f:%.0f", entry[1], integer(entry[2]), integer(entry[3]), integer(entry[4]))
    end
    return table.concat(result, ";")
end

function Prices.unpack(value)
    local result = {}
    if type(value) ~= "string" or value == "" then return result end
    for part in string.gmatch(value, "[^;]+") do
        local k, min, p50, qty = string.match(part, "^([^:]+):([^:]+):([^:]+):([^:]+)$")
        if k then result[#result + 1] = { tonumber(k), tonumber(min), tonumber(p50), tonumber(qty) } end
    end
    return result
end

function Prices.ensure(db, houseKey)
    db.prices = db.prices or {}
    db.prices[houseKey] = db.prices[houseKey] or {}
    return db.prices[houseKey]
end

local function itemKeyID(key)
    if addon.ItemKey then return addon.ItemKey.itemID(key) end
    return tonumber(key) or tonumber(type(key) == "string" and string.match(key, "^(%d+):"))
end

function Prices.interested(db)
    local interested = {}
    local function mark(key)
        local id = itemKeyID(key)
        if id then interested[id] = true end
    end
    for _, char in pairs(db.chars or {}) do
        for _, inventory in ipairs({ char.bags or {}, char.bank or {}, char.equipped or {} }) do
            for key, quantity in pairs(inventory) do
                if (tonumber(quantity) or (quantity and 1) or 0) > 0 then mark(key) end
            end
        end
    end
    for key, value in pairs(db.watch or {}) do if value then mark(key) end end
    for key, value in pairs(db.reserved or {}) do if (tonumber(value) or 0) > 0 then mark(key) end end
    return interested
end

function Prices.depth(itemKey, set, dailyDays)
    local itemID = itemKeyID(itemKey)
    if itemID and set and set[itemID] then return dailyDays or Prices.defaults.dailyDays end
    if type(itemKey) == "number" or (type(itemKey) == "string" and tonumber(itemKey)) then return 7 end
    return 2
end

function Prices.record(db, houseKey, itemKey, summary, now)
    if not summary then return end
    local house = Prices.ensure(db, houseKey)
    local last, dailyText, weeklyText = decode(house[itemKey])
    local day = math.floor(now / 86400)
    local daily = entryMap(Prices.unpack(dailyText))
    local current = daily[day]
    local min, p50, qty = integer(summary.min), integer(summary.p50), integer(summary.qty)
    if current then
        current[2] = math.min(current[2], min)
        current[3], current[4] = p50, qty
    else
        daily[day] = { day, min, p50, qty }
    end
    local observation = last
    if not observation or not tonumber(observation.t) or now >= observation.t then
        observation = { t = now, min = min, p50 = p50, qty = qty }
    end
    house[itemKey] = encoded(observation, Prices.pack(sortedEntries(daily)), weeklyText)
end

function Prices.get(db, houseKey, itemKey)
    local house = db and db.prices and db.prices[houseKey]
    local value = house and house[itemKey]
    if type(value) == "string" then
        local fields, daily, weekly = string.match(value, "^([^|]*)|([^|]*)|([^|]*)$")
        if not fields then return nil end
        local t, min, p50, qty = string.match(fields, "^([^:]+):([^:]+):([^:]+):([^:]+)$")
        if not t then return nil end
        return { t = tonumber(t), min = tonumber(min), p50 = tonumber(p50), qty = tonumber(qty), src = "OBS" }
    end
    if type(value) ~= "table" or type(value.last) ~= "table" then return nil end
    local last = value.last
    return { t = last.t, min = last.min, p50 = last.p50, qty = last.qty, src = "OBS" }
end

-- Cambio de la mediana respecto al dato más reciente de un día anterior al actual.
function Prices.trend(db, houseKey, itemKey, now)
    local last = Prices.get(db, houseKey, itemKey)
    if not last or not (tonumber(last.p50) and last.p50 > 0) then return nil end
    local today = math.floor(now / 86400)
    local previous
    for _, entry in ipairs(Prices.history(db, houseKey, itemKey).daily) do
        if entry[1] < today and (not previous or entry[1] > previous[1]) then previous = entry end
    end
    if not previous or previous[3] <= 0 then return nil end
    return { percent = math.floor((last.p50 - previous[3]) / previous[3] * 100 + 0.5), days = today - previous[1] }
end

function Prices.history(db, houseKey, itemKey)
    local house = db and db.prices and db.prices[houseKey]
    local _, daily, weekly = decode(house and house[itemKey])
    return { daily = Prices.unpack(daily), weekly = Prices.unpack(weekly) }
end

local function lowerMedian(values)
    table.sort(values)
    return values[math.floor((#values + 1) / 2)]
end

function Prices.prune(db, now, opts)
    local config = options(opts)
    local today, thisWeek = math.floor(now / 86400), math.floor(math.floor(now / 86400) / 7)
    local stats = { movedDays = 0, droppedWeeks = 0, droppedItems = 0 }
    local prices, interested = db.prices or {}, Prices.interested(db)
    for houseKey, house in pairs(prices) do
        for itemKey, value in pairs(house) do
            local last, dailyText, weeklyText = decode(value)
            local depth = Prices.depth(itemKey, interested, config.dailyDays)
            local daily, weekly = entryMap(Prices.unpack(dailyText)), entryMap(Prices.unpack(weeklyText))
            local moved = {}
            for day, entry in pairs(daily) do
                if day < today - depth then
                    daily[day] = nil
                    if interested[itemKeyID(itemKey)] then
                        local week = math.floor(day / 7)
                        moved[week] = moved[week] or {}
                        moved[week][#moved[week] + 1] = entry
                        stats.movedDays = stats.movedDays + 1
                    end
                end
            end
            for week, entries in pairs(moved) do
                local old = weekly[week]
                local mins, medians, totalQty, count = {}, {}, 0, 0
                if old then mins[#mins + 1], medians[#medians + 1], totalQty, count = old[2], old[3], old[4], 1 end
                for _, entry in ipairs(entries) do
                    mins[#mins + 1], medians[#medians + 1] = entry[2], entry[3]
                    totalQty, count = totalQty + entry[4], count + 1
                end
                table.sort(mins)
                weekly[week] = { week, mins[1], lowerMedian(medians), math.floor(totalQty / count) }
            end
            for week in pairs(weekly) do
                if not interested[itemKeyID(itemKey)] or week < thisWeek - config.weeklyWeeks then
                    weekly[week] = nil
                    stats.droppedWeeks = stats.droppedWeeks + 1
                end
            end
            local dailyPacked, weeklyPacked = Prices.pack(sortedEntries(daily)), Prices.pack(sortedEntries(weekly))
            if last then
                if not interested[itemKeyID(itemKey)] and last.t < now - 30 * 86400 then
                    house[itemKey] = nil
                    stats.droppedItems = stats.droppedItems + 1
                elseif interested[itemKeyID(itemKey)] and last.t < now - config.staleDays * 86400 then
                    house[itemKey] = nil
                    stats.droppedItems = stats.droppedItems + 1
                else
                    house[itemKey] = encoded(last, dailyPacked, weeklyPacked)
                end
            elseif dailyPacked ~= "" or weeklyPacked ~= "" then
                house[itemKey] = nil
                stats.droppedItems = stats.droppedItems + 1
            end
        end
        if next(house) == nil then prices[houseKey] = nil end
    end
    return stats
end
