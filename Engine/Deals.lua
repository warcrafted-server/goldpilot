local _, addon = ...

local Deals = {}
addon.Deals = Deals

Deals.defaults = { maxAge = 3600, discount = 0.7, minProfit = 100, minDays = 2, minQty = 3, limit = 10 }

local function options(opts)
    local result = {}
    for key, value in pairs(Deals.defaults) do result[key] = value end
    for key, value in pairs(opts or {}) do result[key] = value end
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
        if profit >= 1 then
            return { itemID = item.itemID, kind = "vendor", min = min, ref = vendor, profit = profit,
                percent = math.floor((1 - min / vendor) * 100 + 0.5), t = stamp }
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
    local profit = math.floor(ref * (1 - addon.Sell.CUT)) - min
    if profit < config.minProfit then return nil end
    return { itemID = item.itemID, kind = "resale", min = min, ref = ref, profit = profit,
        percent = math.floor((1 - min / ref) * 100 + 0.5), t = stamp }
end

function Deals.find(items, opts)
    local config, rows = options(opts), {}
    for _, item in ipairs(items or {}) do
        local deal = Deals.evaluate(item, config)
        if deal then rows[#rows + 1] = deal end
    end
    table.sort(rows, function(a, b)
        local ak, bk = a.kind == "vendor" and 1 or 2, b.kind == "vendor" and 1 or 2
        if ak ~= bk then return ak < bk end
        if a.profit ~= b.profit then return a.profit > b.profit end
        return (tonumber(a.itemID) or 0) < (tonumber(b.itemID) or 0)
    end)
    while #rows > math.max(0, tonumber(config.limit) or 0) do table.remove(rows) end
    return rows
end

return Deals
