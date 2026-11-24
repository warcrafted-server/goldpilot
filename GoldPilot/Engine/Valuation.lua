local _, addon = ...

local Valuation = {}
addon.Valuation = Valuation

Valuation.RANK = { OBS = 1, market = 2, auctionator = 3, tsm = 3 }
Valuation.maxAge = 172800

local function rank(candidate)
    if candidate.class == "OBS" then return Valuation.RANK.OBS end
    return Valuation.RANK[candidate.src] or 9
end

function Valuation.choose(candidates, now, maxAge)
    local valid, current, best = {}, {}, nil
    maxAge = tonumber(maxAge) or Valuation.maxAge
    for _, candidate in ipairs(candidates or {}) do
        local price = tonumber(candidate.price)
        if price and price > 0 and candidate.t ~= nil then
            local item = { price = price, class = candidate.class, src = candidate.src, t = candidate.t }
            item.age = now - item.t
            valid[#valid + 1] = item
            if not best or item.t > best.t then best = item end
            if item.age <= maxAge then current[#current + 1] = item end
        end
    end
    if #current == 0 then
        if best then return nil, { reason = "stale", best = best } end
        return nil, { reason = "none" }
    end
    table.sort(current, function(a, b)
        local ar, br = rank(a), rank(b)
        if ar ~= br then return ar < br end
        return a.t > b.t
    end)
    local chosen = current[1]
    return { price = chosen.price, class = chosen.class, src = chosen.src, t = chosen.t, age = chosen.age, inputs = valid }
end

local vendorProvider
function Valuation.registerVendor(fn)
    if type(fn) == "function" then vendorProvider = fn end
end

function Valuation.vendor(key)
    if vendorProvider then
        local ok, price = pcall(vendorProvider, key)
        price = ok and tonumber(price) or nil
        if price and price > 0 then return { price = price, class = "GAME" } end
    end
    return nil
end

local sources = {}
function Valuation.registerSource(src, fn)
    if type(src) == "string" and type(fn) == "function" then sources[src] = fn end
end

function Valuation.reference(db, houseKey, itemKey, now, maxAge)
    local candidates = {}
    local observed = addon.Prices and addon.Prices.get(db, houseKey, itemKey)
    if observed then
        candidates[#candidates + 1] = { class = "OBS", src = observed.src or "OBS", price = observed.p50, t = observed.t }
    end
    for src, fn in pairs(sources) do
        local ok, price, t = pcall(fn, itemKey)
        if ok and price ~= nil then candidates[#candidates + 1] = { class = "EXT", src = src, price = price, t = t } end
    end
    return Valuation.choose(candidates, now, maxAge)
end

function Valuation.value(db, houseKey, itemKey, now, maxAge)
    local ref, why = Valuation.reference(db, houseKey, itemKey, now, maxAge)
    if ref then why = nil end
    return { ref = ref, why = why, vendor = Valuation.vendor(itemKey) }
end
