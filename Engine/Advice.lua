local _, addon = ...

local Advice = {}
addon.Advice = Advice

Advice.defaults = { maxAge = 172800, refreshAge = 86400, minGain = 100, crowded = 200,
    scarce = 3, trendPercent = 15, trendMinQty = 20, trendDays = 3, maxPlaces = 2 }

local function config(opts)
    local result = {}
    for key, value in pairs(Advice.defaults) do result[key] = value end
    for key, value in pairs(opts or {}) do result[key] = value end
    return result
end

local function quality(ctx, key)
    if type(ctx.quality) ~= "function" then return nil end
    local ok, value = pcall(ctx.quality, key)
    return ok and tonumber(value) or nil
end

local function summarize(rows, kind, where, char, seen, ctx, opts)
    local card = { kind = "action", class = kind == "vendor" and "GAME" or "OBS",
        gain = 0, confidence = 0, count = 0, items = {}, _oldest = nil }
    local weighted, weight = 0, 0
    for _, row in ipairs(rows) do
        local take = false
        if kind == "vendor" then
            take = row.action == "vendor" and row.qtyAuction > 0 and row.vendorUnit ~= nil
                and (row.ahUnit ~= nil or quality(ctx, row.key) == 0)
        else
            take = row.action == "auction" and row.qtyAuction > 0 and row.ahUnit ~= nil
        end
        if take then
            local unit = kind == "vendor" and row.vendorUnit or row.unitBest
            local value = unit * row.qtyAuction
            local entry = { key = row.key, itemID = row.itemID, qty = row.qtyAuction, value = value,
                t = row.t, forSale = (addon.Prices.get(ctx.db, ctx.houseKey, row.key) or {}).qty }
            card.gain = card.gain + value
            card.count = card.count + 1
            if row.t and (kind ~= "vendor" or row.ahUnit ~= nil)
                and (not card._oldest or row.t < card._oldest) then card._oldest = row.t end
            local confidence = 1
            if kind == "auction" then
                confidence = 0.9
                if row.age and row.age > opts.refreshAge then confidence = confidence * 0.8 end
                if entry.forSale and entry.forSale >= opts.crowded then confidence = confidence * 0.7 end
                if entry.forSale and entry.forSale < opts.scarce then confidence = confidence * 0.6 end
            end
            weighted, weight = weighted + confidence * value, weight + value
            card.items[#card.items + 1] = entry
            if kind == "auction" and entry.forSale and entry.forSale >= opts.crowded then card.crowded = true end
        end
    end
    table.sort(card.items, function(a, b)
        if math.abs(a.value) ~= math.abs(b.value) then return math.abs(a.value) > math.abs(b.value) end
        return tostring(a.key) < tostring(b.key)
    end)
    while #card.items > 5 do table.remove(card.items) end
    card.confidence = weight > 0 and weighted / weight or 0
    card.oldest, card.where, card.char, card.seen = card._oldest, where, char, seen
    card._oldest = nil
    return card
end

local function inventory(ctx, char, where, opts)
    return addon.Inventory.build(ctx.db, ctx.houseKey, char, ctx.now, { where = where, maxAge = opts.maxAge })
end

function Advice.build(ctx)
    ctx = ctx or {}
    local db, now = ctx.db or {}, tonumber(ctx.now) or 0
    local normalized = { db = db, houseKey = ctx.houseKey, char = ctx.char, now = now, quality = ctx.quality,
        session = ctx.session, auctionable = ctx.auctionable }
    local opts = config(ctx.opts)
    local cards, totals = {}, { now = 0, mail = 0, elsewhere = 0 }
    local function add(card) if card.count > 0 then cards[#cards + 1] = card end end
    local bags = inventory(normalized, ctx.char, "bags", opts)
    local auctions = summarize(bags.rows, "auction", nil, nil, nil, normalized, opts)
    auctions.id = "auction"
    local vendors = summarize(bags.rows, "vendor", nil, nil, nil, normalized, opts)
    vendors.id = "vendor"
    if auctions.gain >= opts.minGain then add(auctions); totals.now = totals.now + auctions.gain end
    if vendors.gain >= opts.minGain then add(vendors); totals.now = totals.now + vendors.gain end

    local pending = db.mailPending or {}
    local otherMail = {}
    for char, mail in pairs(pending) do
        local money, items = tonumber(mail.money), tonumber(mail.items)
        if (money or 0) > 0 or (items or 0) > 0 then
            local expires = tonumber(mail.expires)
            if (ctx.account ~= false or char == ctx.char) and (not expires or expires > now) then
                totals.mail = totals.mail + (money or 0)
                local card = { id = char == ctx.char and "mail" or "mail_other", kind = "action", gain = money or 0,
                    confidence = char == ctx.char and 0.95 or 0.8, class = "OBS", count = items or 0, items = {},
                    char = char, seen = tonumber(mail.t), oldest = tonumber(mail.t),
                    mails = mail.list, mailCount = tonumber(mail.counted) }
                if char == ctx.char then totals.now = totals.now + card.gain; cards[#cards + 1] = card
                else otherMail[#otherMail + 1] = card end
            end
        end
    end
    table.sort(otherMail, function(a,b) if a.gain ~= b.gain then return a.gain > b.gain end return tostring(a.char) < tostring(b.char) end)
    for i=1, math.min(#otherMail, opts.maxPlaces) do cards[#cards + 1] = otherMail[i] end

    local places = {}
    for char, data in pairs(db.chars or {}) do
        for _, where in ipairs({ "bags", "bank" }) do
            if (char == ctx.char and where == "bank") or (char ~= ctx.char and ctx.account ~= false) then
                local built = inventory(normalized, char, where, opts)
                local seen = where == "bank" and data.bankSeen or data.seen
                local card = summarize(built.rows, "auction", where, char, seen, normalized, opts)
                card.id, card.confidence = "elsewhere", card.confidence * 0.8
                if card.gain >= opts.minGain then
                    totals.elsewhere = totals.elsewhere + card.gain
                    places[#places + 1] = card
                end
            end
        end
    end
    table.sort(places, function(a, b)
        if a.gain ~= b.gain then return a.gain > b.gain end
        if tostring(a.char) ~= tostring(b.char) then return tostring(a.char) < tostring(b.char) end
        return a.where < b.where
    end)
    for i=1, math.min(#places, opts.maxPlaces) do add(places[i]) end

    local combined = inventory(normalized, ctx.char, nil, opts)
    local trends, staleCount, totalCount, oldest = {}, 0, 0, nil
    for _, row in ipairs(combined.rows) do
        if row.qtyAuction > 0 then
            totalCount = totalCount + 1
            local staleAge = row.age and row.age > opts.refreshAge
                or not row.age and (not db.scan or not tonumber(db.scan.t)
                    or type(db.scan.items) ~= "number" or now - db.scan.t > opts.refreshAge)
            if staleAge then
                staleCount = staleCount + 1
                if row.t and (not oldest or row.t < oldest) then oldest = row.t end
            end
            if row.ahUnit then
                local trend = addon.Prices.trend(db, ctx.houseKey, row.key, now)
                local forSale = (addon.Prices.get(db, ctx.houseKey, row.key) or {}).qty
                if trend and math.abs(trend.percent) >= opts.trendPercent and trend.days <= opts.trendDays
                    and (tonumber(forSale) or 0) >= opts.trendMinQty and trend.percent > -100 then
                    local value = row.ahUnit * row.qtyAuction
                    local change = value - math.floor(value / (1 + trend.percent / 100))
                    local id = trend.percent > 0 and "trend_up" or "trend_down"
                    trends[id] = trends[id] or {
                        id = id, kind = "info", class = "OBS", gain = 0,
                        confidence = 1, count = 0, items = {},
                    }
                    local card = trends[id]
                    card.gain, card.count = card.gain + change, card.count + 1
                    if row.t and (not card.oldest or row.t < card.oldest) then card.oldest = row.t end
                    card.items[#card.items + 1] = { key = row.key, itemID = row.itemID, qty = row.qtyAuction,
                        value = change, t = row.t, forSale = forSale, percent = trend.percent }
                end
            end
        end
    end
    local refresh = totalCount > 0 and staleCount > 0 and {
        id = "refresh", kind = "refresh", class = "OBS", gain = 0,
        confidence = 1, count = staleCount, items = {}, oldest = oldest,
        share = staleCount / totalCount,
    } or nil
    local actions, infos = {}, {}
    for _, card in ipairs(cards) do if card.kind == "action" then actions[#actions + 1] = card end end
    table.sort(actions, function(a, b)
        local av, bv = a.gain * a.confidence, b.gain * b.confidence
        if av ~= bv then return av > bv end
        if a.id ~= b.id then return a.id < b.id end
        if tostring(a.char or "") ~= tostring(b.char or "") then
            return tostring(a.char or "") < tostring(b.char or "")
        end
        return tostring(a.where or "") < tostring(b.where or "")
    end)
    for _, id in ipairs({ "trend_up", "trend_down" }) do
        local card = trends[id]
        if card then
            table.sort(card.items, function(a,b)
                if math.abs(a.value) ~= math.abs(b.value) then return math.abs(a.value) > math.abs(b.value) end
                return tostring(a.key) < tostring(b.key)
            end)
            while #card.items > 5 do table.remove(card.items) end
            infos[#infos + 1] = card
        end
    end
    local result = {}
    if refresh and (refresh.share > 0.5 or #actions == 0) then result[#result+1]=refresh end
    for _, card in ipairs(actions) do result[#result+1]=card end
    if refresh and result[1] ~= refresh then result[#result+1]=refresh end
    local zones = addon.Sessions.zones(db, normalized.houseKey, now, {
        char = ctx.account == false and ctx.char or nil,
        current = normalized.session,
        auctionable = normalized.auctionable,
    })
    if #zones > 0 and (zones[1].rate or 0) > 0 then
        local zone = { id = "zone", kind = "info", per = "hour", class = "OBS",
            gain = zones[1].rate, confidence = zones[1].active >= 3600 and 0.9 or 0.6,
            count = #zones, mapID = zones[1].mapID, active = zones[1].active, items = {} }
        for index = 1, math.min(#zones, 5) do
            local item = zones[index]
            zone.items[#zone.items + 1] = { mapID = item.mapID, value = item.rate, active = item.active }
        end
        result[#result+1] = zone
    end
    for _, card in ipairs(infos) do result[#result+1]=card end
    return { cards = result, totals = totals }
end

return Advice
