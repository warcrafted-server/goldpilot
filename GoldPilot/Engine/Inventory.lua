local _, addon = ...

local Inventory = {}
addon.Inventory = Inventory

local function addBreakdown(row, charName, where, quantity, bound)
    quantity, bound = tonumber(quantity) or 0, tonumber(bound) or 0
    if quantity <= 0 then return end
    row.qty = row.qty + quantity
    row.qtyBound = row.qtyBound + math.min(quantity, bound)
    row.breakdown[#row.breakdown + 1] = { char = charName, where = where, qty = quantity }
end

function Inventory.build(db, houseKey, scope, now, opts)
    db, opts = db or {}, opts or {}
    local grouped = {}
    for charName, character in pairs(db.chars or {}) do
        if scope == nil or scope == charName then
            for _, where in ipairs({ "bags", "bank" }) do
                for key, quantity in pairs(character[where] or {}) do
                    local itemID = addon.ItemKey.itemID(key)
                    quantity = tonumber(quantity) or 0
                    if itemID and quantity > 0 and (addon.Valuation.known(key) or addon.Prices.get(db, houseKey, key)) then
                        local row = grouped[key] or { key = key, itemID = itemID, qty = 0, qtyBound = 0, breakdown = {} }
                        grouped[key] = row
                        addBreakdown(row, charName, where, quantity, character[where == "bags" and "bound" or "bankBound"] and character[where == "bags" and "bound" or "bankBound"][key])
                    end
                end
            end
        end
    end

    local cut = db.houses and db.houses[houseKey] and db.houses[houseKey].cut
    local rows, totals = {}, { valueBest = 0, valueVendor = 0, valueAuction = 0,
        items = 0, withoutPrice = 0, stale = 0, reserved = 0 }
    for key, row in pairs(grouped) do
        local value = addon.Valuation.value(db, houseKey, key, now, opts.maxAge)
        local reference, staleValue = value.ref, value.why and value.why.best
        local free = row.qty - row.qtyBound
        local reserved = tonumber(db.reserved and db.reserved[key])
        if reserved == nil and type(key) ~= "string" then reserved = tonumber(db.reserved and db.reserved[row.itemID]) end
        row.qtyReserved = math.min(free, math.max(0, reserved or 0))
        row.qtySellable = free - row.qtyReserved + row.qtyBound
        row.qtyAuction = free - row.qtyReserved
        row.vendorUnit = value.vendor and value.vendor.price or nil
        row.ahUnit = reference and reference.price or nil
        row.age = reference and reference.age or staleValue and staleValue.age or nil
        row.stale = not reference and staleValue ~= nil
        local advice = addon.Advisor.recommend(row.vendorUnit, row.ahUnit, cut)
        if row.qtyAuction == 0 then
            advice = { action = row.vendorUnit and "vendor" or "none", vendor = row.vendorUnit, net = nil, cutAssumed = false }
        end
        row.action, row.cutAssumed = advice.action, advice.cutAssumed and row.ahUnit ~= nil
        row.class = advice.action == "auction" and (reference and reference.class or "OBS")
            or advice.action == "vendor" and "GAME" or nil
        row.unitBest = advice.action == "auction" and advice.net or advice.action == "vendor" and advice.vendor or nil
        row.valueBest = ((row.qtyAuction > 0 and advice.action == "auction" and advice.net or 0) * row.qtyAuction)
            + ((row.qtyBound + (row.qtyAuction > 0 and advice.action ~= "auction" and row.qtyAuction or 0)) * (row.vendorUnit or 0))
        row.valueVendor = (row.vendorUnit or 0) * row.qtySellable
        row.valueAuction = (row.qtyAuction > 0 and advice.net or 0) * row.qtyAuction
        row.reserved = row.qtyReserved > 0
        row.watched = db.watch and db.watch[row.itemID] == true or false
        rows[#rows + 1] = row
        totals.items = totals.items + 1
        totals.valueBest = totals.valueBest + row.valueBest
        totals.valueVendor = totals.valueVendor + row.valueVendor
        totals.valueAuction = totals.valueAuction + row.valueAuction
        if row.action == "none" then totals.withoutPrice = totals.withoutPrice + 1 end
        if row.stale then totals.stale = totals.stale + 1 end
        if row.reserved then totals.reserved = totals.reserved + 1 end
    end
    table.sort(rows, function(a, b)
        local an, bn = a.action == "none", b.action == "none"
        if an ~= bn then return not an end
        if a.valueBest ~= b.valueBest then return a.valueBest > b.valueBest end
        return a.itemID == b.itemID and tostring(a.key) < tostring(b.key) or a.itemID < b.itemID
    end)
    return { rows = rows, totals = totals }
end

return Inventory
