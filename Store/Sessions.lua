local _, addon = ...

local Sessions = {}
addon.Sessions = Sessions

Sessions.defaults = { idle = 180, close = 900, minActive = 300, keep = 50, minListed = 3, zoneActive = 1200 }

local function mapID(value)
    value = tonumber(value)
    if value and value > 0 and value == math.floor(value) then return value end
    return 0
end

local function quantity(value)
    value = math.floor(tonumber(value) or 0)
    if value > 0 then return value end
    return 0
end

local function zone(session, id)
    session.maps = session.maps or {}
    local map = session.maps[id]
    if not map then
        map = { active = 0, coin = 0, items = {} }
        session.maps[id] = map
    end
    map.active, map.coin, map.items = tonumber(map.active) or 0, tonumber(map.coin) or 0, map.items or {}
    return map
end

local function tail(session, now)
    return math.min(math.max(0, now - (tonumber(session.last) or now)), Sessions.defaults.idle)
end

function Sessions.add(session, loot, now)
    loot = loot or {}
    now = tonumber(now) or 0
    local id = mapID(loot.mapID)
    local coin = quantity(loot.coin)
    local items, any = {}, coin > 0
    for key, value in pairs(loot.items or {}) do
        local amount = quantity(value)
        if amount > 0 then
            items[key] = amount
            any = true
        end
    end
    if not any then return session end
    if not session then
        session = { char = loot.char, start = now, last = now, active = 0, coin = 0, loots = 0,
            nodes = 0, items = {}, lastMap = id, maps = {} }
    else
        local seconds = tail(session, now)
        session.active = (tonumber(session.active) or 0) + seconds
        local previous = zone(session, mapID(session.lastMap))
        previous.active = previous.active + seconds
        session.char = session.char or loot.char
    end
    session.coin = (tonumber(session.coin) or 0) + coin
    session.items = session.items or {}
    for key, amount in pairs(items) do session.items[key] = (tonumber(session.items[key]) or 0) + amount end
    session.loots = (tonumber(session.loots) or 0) + 1
    if loot.node then session.nodes = (tonumber(session.nodes) or 0) + 1 end
    local current = zone(session, id)
    current.coin = current.coin + coin
    for key, amount in pairs(items) do current.items[key] = (tonumber(current.items[key]) or 0) + amount end
    if now > (tonumber(session.last) or 0) then session.last = now end
    session.lastMap = id
    return session
end

function Sessions.active(session, now)
    if not session then return 0 end
    return (tonumber(session.active) or 0) + tail(session, tonumber(now) or 0)
end

function Sessions.expired(session, now)
    if not session then return false end
    return (tonumber(now) or 0) - (tonumber(session.last) or 0) >= Sessions.defaults.close
end

function Sessions.close(db, session, now)
    if not session then return false end
    db, now = db or {}, tonumber(now) or 0
    local seconds = tail(session, now)
    session.active = (tonumber(session.active) or 0) + seconds
    local previous = zone(session, mapID(session.lastMap))
    previous.active = previous.active + seconds
    session.stop = tonumber(session.last) or 0
    if session.active < Sessions.defaults.minActive then return false end
    db.sessions = db.sessions or {}
    db.sessions[#db.sessions + 1] = session
    while #db.sessions > Sessions.defaults.keep do table.remove(db.sessions, 1) end
    return true
end

function Sessions.unit(db, houseKey, key, now, auctionable)
    db = db or {}
    local value = addon.Valuation.value(db, houseKey, key, now)
    local price
    if value.ref then
        local itemID = addon.ItemKey.itemID(key)
        if type(auctionable) ~= "function" or auctionable(itemID) ~= false then
            local observed = addon.Prices.get(db, houseKey, key)
            local listed = observed and tonumber(observed.qty) or 0
            if value.ref.class ~= "OBS" or listed >= Sessions.defaults.minListed then
                price = value.ref.price
            end
        end
    end
    local house = db.houses and db.houses[houseKey]
    local recommendation = addon.Advisor.recommend(value.vendor and value.vendor.price, price, house and house.cut)
    if recommendation.action == "auction" then return recommendation.net, "auction" end
    if recommendation.action == "vendor" then return recommendation.vendor, "vendor" end
    return nil, "none"
end

function Sessions.value(db, houseKey, bucket, now, auctionable)
    bucket = bucket or {}
    local coin = math.floor(tonumber(bucket.coin) or 0)
    local result = { total = coin, coin = coin, auction = 0, vendor = 0, unpriced = 0, rows = {} }
    for key, value in pairs(bucket.items or {}) do
        local amount = math.floor(tonumber(value) or 0)
        if amount > 0 then
            local unit, kind = Sessions.unit(db, houseKey, key, now, auctionable)
            local total = (tonumber(unit) or 0) * amount
            if kind == "auction" then result.auction = result.auction + total
            elseif kind == "vendor" then result.vendor = result.vendor + total
            else result.unpriced = result.unpriced + 1 end
            result.rows[#result.rows + 1] = { key = key, itemID = addon.ItemKey.itemID(key),
                qty = amount, unit = unit or 0, value = total, kind = kind }
        end
    end
    result.total = result.coin + result.auction + result.vendor
    table.sort(result.rows, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return tostring(a.key) < tostring(b.key)
    end)
    return result
end

function Sessions.rate(total, active)
    active = tonumber(active) or 0
    if active <= 0 then return nil end
    return math.floor((tonumber(total) or 0) / active * 3600 + 0.5)
end

function Sessions.zones(db, houseKey, now, opts)
    db, opts, now = db or {}, opts or {}, tonumber(now) or 0
    local zones = {}
    local function zoneOf(id)
        id = mapID(id)
        if id == 0 then return nil end
        local item = zones[id]
        if not item then
            item = { mapID = id, active = 0, coin = 0, items = {}, sessions = 0 }
            zones[id] = item
        end
        return item
    end
    local function absorb(session, extraMap, extra)
        local touched = {}
        for id, map in pairs(session.maps or {}) do
            local item = zoneOf(id)
            if item then
                item.active = item.active + (tonumber(map.active) or 0)
                item.coin = item.coin + (tonumber(map.coin) or 0)
                for key, value in pairs(map.items or {}) do
                    item.items[key] = (item.items[key] or 0) + (tonumber(value) or 0)
                end
                touched[mapID(id)] = true
            end
        end
        if extra and extra > 0 then
            local item = zoneOf(extraMap)
            if item then
                item.active = item.active + extra
                touched[mapID(extraMap)] = true
            end
        end
        for id in pairs(touched) do zones[id].sessions = zones[id].sessions + 1 end
    end
    for _, session in ipairs(db.sessions or {}) do
        if not opts.char or session.char == opts.char then absorb(session) end
    end
    local current = opts.current
    if current and (not opts.char or current.char == opts.char) then
        absorb(current, current.lastMap, tail(current, now))
    end
    local result = {}
    local minActive = tonumber(opts.minActive) or Sessions.defaults.zoneActive
    for _, item in pairs(zones) do
        if item.active >= minActive then
            local value = Sessions.value(db, houseKey, { coin = item.coin, items = item.items }, now, opts.auctionable)
            result[#result + 1] = { mapID = item.mapID, active = item.active, sessions = item.sessions,
                total = value.total, rate = Sessions.rate(value.total, item.active),
                unpriced = value.unpriced, rows = value.rows }
        end
    end
    table.sort(result, function(a, b)
        if a.rate ~= b.rate then return a.rate > b.rate end
        return a.mapID < b.mapID
    end)
    return result
end
