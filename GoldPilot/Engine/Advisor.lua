local _, addon = ...

addon.Advisor = {}

function addon.Advisor.recommend(vendorPrice, ahPrice, cut, opts)
    opts = opts or {}
    vendorPrice, ahPrice = tonumber(vendorPrice), tonumber(ahPrice)
    cut = tonumber(cut)
    local assumed = cut == nil
    if assumed then cut = 0.05 end
    local net = ahPrice and math.floor(ahPrice * (1 - cut)) or nil
    local vendor = vendorPrice and math.floor(vendorPrice) or nil
    local margin = net and vendor and net - vendor or 0
    local gain = tonumber(opts.minGain) or 0.10
    if net and (not vendor or net > vendor * (1 + gain)) then
        return { action = "auction", net = net, vendor = vendor, margin = margin, cutAssumed = assumed }
    end
    if vendor then return { action = "vendor", net = net, vendor = vendor, margin = margin, cutAssumed = assumed } end
    if net then return { action = "auction", net = net, vendor = nil, margin = 0, cutAssumed = assumed } end
    return { action = "none", net = nil, vendor = nil, margin = 0, cutAssumed = assumed }
end

function addon.Advisor.bagsValue(bags, priceFor)
    local result = { vendor = 0, auction = 0, best = 0, items = 0, withoutPrice = 0 }
    for itemID, quantity in pairs(bags or {}) do
        quantity = tonumber(quantity) or 0
        if quantity > 0 then
            result.items = result.items + 1
            local prices = type(priceFor) == "function" and priceFor(itemID) or nil
            local recommendation = addon.Advisor.recommend(
                prices and prices.vendorPrice, prices and prices.ahPrice, prices and prices.cut
            )
            local vendor = recommendation.vendor
            local auction = recommendation.net
            if vendor then result.vendor = result.vendor + vendor * quantity end
            if auction then result.auction = result.auction + auction * quantity end
            if not vendor and not auction then result.withoutPrice = result.withoutPrice + 1 end
            result.best = result.best + math.max(vendor or 0, auction or 0) * quantity
        end
    end
    return result
end
