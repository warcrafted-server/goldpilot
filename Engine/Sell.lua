local _, addon = ...

local Sell = {}
addon.Sell = Sell

Sell.CUT = 0.05

function Sell.suggest(info)
    info = info or {}
    local minPrice, ref = tonumber(info.min), tonumber(info.ref)
    if not minPrice and not ref then return nil end
    local base, basis
    if minPrice then base, basis = minPrice - 1, "undercut"
    else base, basis = ref, "reference" end
    local price = math.max(1, base)
    local vendor = tonumber(info.vendor)
    local floor = vendor and math.ceil(vendor / (1 - Sell.CUT)) or nil
    local warning
    if floor and price < floor then warning = "vendor"
    elseif minPrice and ref and minPrice < 0.7 * ref then warning = "crashed" end
    local quantity = math.max(1, tonumber(info.quantity) or 1)
    return {
        price = price, floor = floor,
        net = math.floor(price * quantity * (1 - Sell.CUT)) - (tonumber(info.deposit) or 0),
        warning = warning, basis = basis,
    }
end

function Sell.otherMin(listings)
    local minimum
    for _, listing in ipairs(listings or {}) do
        local own = listing.own
        local hasOthers
        if type(own) == "boolean" then
            hasOthers = not own
        else
            hasOthers = (tonumber(listing.qty) or 1) - (tonumber(own) or 0) > 0
        end
        local price = tonumber(listing.price)
        if hasOthers and price and price > 0 and (not minimum or price < minimum) then minimum = price end
    end
    return minimum
end

return Sell
