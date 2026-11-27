local _, addon = ...

local Deals = {}
addon.Deals = Deals

Deals.defaults = { maxAge = 3600, discount = 0.7, minProfit = 100, vendorMinProfit = 50, minDays = 2, minQty = 3, limit = 6 }

local function options(opts)
    local result = {}
    for key, value in pairs(Deals.defaults) do result[key] = value end
    for key, value in pairs(opts or {}) do result[key] = value end
    if result.small then result.minProfit, result.vendorMinProfit = 1, 1 end
    return result
end

local function lowerMedian(values)
    table.sort(values)
    return values[math.floor((#values + 1) / 2)]
end

function Deals.evaluate(item, opts)
    if type(item) ~= "table" then return nil end
    local config = options(opts)
    local now, min, stamp = tonumber(config.now), tonumber(item.min), tonumber(item.t)
    if not now or not min or not stamp or now - stamp > config.maxAge then return nil end
    local vendor = tonumber(item.vendor)
    if vendor and vendor > min then
        local profit = vendor - min
        if profit >= config.vendorMinProfit then
            return { itemID = item.itemID, kind = "vendor", min = min, ref = vendor, profit = profit,
                maxPay = vendor - config.vendorMinProfit, percent = math.floor((1 - min / vendor) * 100 + 0.5), t = stamp }
        end
    end
    local today, medians = math.floor(now / 86400), {}
    for _, entry in ipairs(item.history or {}) do
        local day, p50 = tonumber(entry[1]), tonumber(entry[3])
        if day and day < today and p50 and p50 > 0 then medians[#medians + 1] = p50 end
    end
    if #medians < config.minDays or (tonumber(item.qty) or 0) < config.minQty then return nil end
    local ref = lowerMedian(medians)
    if min > ref * config.discount then return nil end
    local afterCut = math.floor(ref * (1 - addon.Sell.CUT))
    local profit = afterCut - min
    if profit < config.minProfit then return nil end
    return { itemID = item.itemID, kind = "resale", min = min, ref = ref, profit = profit,
        maxPay = math.min(math.floor(ref * config.discount), afterCut - config.minProfit),
        percent = math.floor((1 - min / ref) * 100 + 0.5), t = stamp }
end

function Deals.find(items, opts)
    local config, rows = options(opts), { resale = {}, vendor = {} }
    for _, item in ipairs(items or {}) do
        local deal = Deals.evaluate(item, config)
        if deal then rows[deal.kind][#rows[deal.kind] + 1] = deal end
    end
    local function sortAndLimit(list)
        table.sort(list, function(a, b)
            if a.profit ~= b.profit then return a.profit > b.profit end
            return (tonumber(a.itemID) or 0) < (tonumber(b.itemID) or 0)
        end)
        while #list > math.max(0, tonumber(config.limit) or 0) do table.remove(list) end
    end
    sortAndLimit(rows.resale)
    sortAndLimit(rows.vendor)
    return rows
end

function Deals.check(deal, current)
    current = tonumber(current)
    if type(deal) ~= "table" or not current then return nil end
    local gain = deal.kind == "vendor" and (tonumber(deal.ref) or 0) - current
        or math.floor((tonumber(deal.ref) or 0) * (1 - addon.Sell.CUT)) - current
    return { price = current, gain = gain, good = current <= (tonumber(deal.maxPay) or 0) }
end

return Deals
