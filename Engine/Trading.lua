local _, addon = ...

local Trading = {}
addon.Trading = Trading

local function rounded(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

function Trading.analyze(entries, personal)
    local groups = {}
    for index, entry in ipairs(entries or {}) do
        if type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" and
            (entry.kind == "buy" or entry.kind == "sell") and (tonumber(entry.qty) or 0) > 0 then
            local item = groups[entry.name]
            if not item then
                item = { name = entry.name, events = {}, itemID = nil, last = nil,
                    bought = 0, spent = 0, sold = 0, income = 0, resold = 0,
                    resaleProfit = 0, other = 0, otherIncome = 0, stock = 0, stockCost = 0 }
                groups[entry.name] = item
            end
            item.events[#item.events + 1] = { entry = entry, index = index }
            local timestamp = tonumber(entry.t) or 0
            if not item.last or timestamp > item.last then item.last = timestamp end
            item.itemID = tonumber(entry.itemID) or item.itemID
        end
    end

    local items, totals = {}, { spent = 0, income = 0, balance = 0, resaleProfit = 0,
        otherIncome = 0, stockCost = 0, personalSpent = 0 }
    for name, item in pairs(groups) do
        table.sort(item.events, function(a, b)
            local at, bt = tonumber(a.entry.t) or 0, tonumber(b.entry.t) or 0
            if at ~= bt then return at < bt end
            if a.entry.kind ~= b.entry.kind then return a.entry.kind == "buy" end
            return a.index < b.index
        end)
        local lots, lotHead = {}, 1
        for _, event in ipairs(item.events) do
            local entry = event.entry
            local qty, gross = tonumber(entry.qty) or 0, tonumber(entry.gross) or 0
            if entry.kind == "buy" then
                local unit = gross / qty
                item.bought, item.spent = item.bought + qty, item.spent + gross
                lots[#lots + 1] = { qty = qty, unit = unit }
            else
                local income = gross - (tonumber(entry.cut) or 0)
                local unitIncome = income / qty
                item.sold, item.income = item.sold + qty, item.income + income
                local left = qty
                while left > 0 and lots[lotHead] do
                    local lot = lots[lotHead]
                    local used = math.min(left, lot.qty)
                    item.resold = item.resold + used
                    item.resaleProfit = item.resaleProfit + used * (unitIncome - lot.unit)
                    lot.qty, left = lot.qty - used, left - used
                    if lot.qty <= 0 then lotHead = lotHead + 1 end
                end
                if left > 0 then
                    item.other = item.other + left
                    item.otherIncome = item.otherIncome + left * unitIncome
                end
            end
        end
        for index = lotHead, #lots do
            local lot = lots[index]
            item.stock, item.stockCost = item.stock + lot.qty, item.stockCost + lot.qty * lot.unit
        end
        item.personal = personal and personal[name] == true or false
        item.avgBuy = item.bought > 0 and item.spent / item.bought or nil
        item.avgSell = item.sold > 0 and item.income / item.sold or nil
        if item.personal then
            totals.personalSpent = totals.personalSpent + item.spent
        else
            totals.spent = totals.spent + item.spent
            totals.income = totals.income + item.income
            totals.resaleProfit = totals.resaleProfit + item.resaleProfit
            totals.otherIncome = totals.otherIncome + item.otherIncome
            totals.stockCost = totals.stockCost + item.stockCost
        end
        item.spent, item.income = rounded(item.spent), rounded(item.income)
        item.resaleProfit, item.otherIncome = rounded(item.resaleProfit), rounded(item.otherIncome)
        item.stockCost = rounded(item.stockCost)
        if item.avgBuy then item.avgBuy = rounded(item.avgBuy) end
        if item.avgSell then item.avgSell = rounded(item.avgSell) end
        item.events = nil
        items[#items + 1] = item
    end
    for key, value in pairs(totals) do totals[key] = rounded(value) end
    totals.balance = rounded(totals.income - totals.spent)
    return items, totals
end

return Trading
