local _, addon = ...

local Inventory = {}
addon.Inventory = Inventory

local function addBreakdown(row, charName, where, quantity)
    quantity = tonumber(quantity) or 0
    if quantity <= 0 then return end
    row.qty = row.qty + quantity
    row.breakdown[#row.breakdown + 1] = { char = charName, where = where, qty = quantity }
end

function Inventory.build(db, houseKey, scope, now, opts)
    db, opts = db or {}, opts or {}
    local grouped = {}
    for charName, character in pairs(db.chars or {}) do
        if scope == nil or scope == charName then
            for _, where in ipairs({ "bags", "bank" }) do
                for itemID, quantity in pairs(character[where] or {}) do
                    itemID, quantity = tonumber(itemID), tonumber(quantity) or 0
                    if itemID and quantity > 0 and addon.DataItems and addon.DataItems[itemID] then
                        local row = grouped[itemID] or { itemID = itemID, qty = 0, breakdown = {} }
                        grouped[itemID] = row
                        addBreakdown(row, charName, where, quantity)
                    end
                end
            end
        end
    end

    local cut = db.houses and db.houses[houseKey] and db.houses[houseKey].cut
    local rows, totals = {}, { valueBest = 0, valueVendor = 0, valueAuction = 0,
        items = 0, withoutPrice = 0, stale = 0, reserved = 0 }
    for itemID, row in pairs(grouped) do
        local value = addon.Valuation.value(db, houseKey, itemID, now, opts.maxAge)
        local reference, staleValue = value.ref, value.why and value.why.best
        row.qtyReserved = math.min(row.qty, math.max(0, tonumber(db.reserved and db.reserved[itemID]) or 0))
        row.qtySellable = row.qty - row.qtyReserved
        row.vendorUnit = value.vendor and value.vendor.price or nil
        row.ahUnit = reference and reference.price or nil
        row.age = reference and reference.age or staleValue and staleValue.age or nil
        row.stale = not reference and staleValue ~= nil
        local advice = addon.Advisor.recommend(row.vendorUnit, row.ahUnit, cut)
        row.action, row.cutAssumed = advice.action, advice.cutAssumed and row.ahUnit ~= nil
        row.class = advice.action == "auction" and (reference and reference.class or "OBS")
            or advice.action == "vendor" and "GAME" or nil
        row.unitBest = advice.action == "auction" and advice.net or advice.action == "vendor" and advice.vendor or nil
        row.valueBest = (row.unitBest or 0) * row.qtySellable
        row.valueVendor = (row.vendorUnit or 0) * row.qtySellable
        row.valueAuction = (advice.net or 0) * row.qtySellable
        row.reserved = row.qtyReserved > 0
        row.watched = db.watch and db.watch[itemID] == true or false
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
        return a.itemID < b.itemID
    end)
    return { rows = rows, totals = totals }
end

return Inventory
