local _, addon = ...

local Ledger = {}
addon.Ledger = Ledger

local function yearOf(timestamp)
    local ok, year = pcall(date, "!%Y", timestamp)
    if ok and tonumber(year) then return tonumber(year) end
    return 1970
end

local function fingerprint(char, mail)
    return table.concat({ tostring(char or ""), tostring(mail.kind or ""), tostring(mail.name or ""),
        tostring(tonumber(mail.qty) or 0), tostring(tonumber(mail.gross) or 0),
        tostring(tonumber(mail.deposit) or 0), tostring(tonumber(mail.cut) or 0) }, "|")
end

local function seenMatch(seen, key, expires, matched, existingCount)
    for index, entry in ipairs(seen) do
        if index > existingCount then break end
        if not matched[index] and entry.huella == key and math.abs((tonumber(entry.expira) or 0) - expires) <= 600 then
            matched[index] = true
            return true
        end
    end
    return false
end

function Ledger.sync(db, char, mails, now)
    db.ledger, db.mailSeen, db.auctionSenders = db.ledger or {}, db.mailSeen or {}, db.auctionSenders or {}
    local senderSet = {}
    for _, sender in ipairs(db.auctionSenders) do senderSet[sender] = true end
    for _, mail in ipairs(mails or {}) do
        if mail.invoice and (mail.invoiceType == "seller" or mail.invoiceType == "buyer") and mail.sender then
            if not senderSet[mail.sender] then
                db.auctionSenders[#db.auctionSenders + 1] = mail.sender
                senderSet[mail.sender] = true
            end
        end
    end

    for index = #db.mailSeen, 1, -1 do
        if (tonumber(db.mailSeen[index].expira) or 0) < now - 86400 then table.remove(db.mailSeen, index) end
    end

    local added, matched, existingCount = 0, {}, #db.mailSeen
    -- Las devoluciones pendientes solo viven en memoria para no guardarlas en SavedVariables.
    local pending = Ledger.pendingReturns or {}
    Ledger.pendingReturns = pending
    local charPending = pending[char] or {}
    pending[char] = charPending
    local returnObserved = {}
    for _, mail in ipairs(mails or {}) do
        local entry
        if mail.invoice then
            local kind = mail.invoiceType == "seller" and "sell" or mail.invoiceType == "buyer" and "buy" or nil
            if kind and tonumber(mail.qty) and mail.name then
                entry = { t = now, char = char, kind = kind, name = mail.name,
                    itemID = kind == "buy" and tonumber(mail.itemID) or nil, qty = tonumber(mail.qty),
                    gross = tonumber(mail.gross) or 0, deposit = tonumber(mail.deposit) or 0,
                    cut = tonumber(mail.cut) or 0, net = kind == "sell" and
                        ((tonumber(mail.gross) or 0) + (tonumber(mail.deposit) or 0) - (tonumber(mail.cut) or 0)) or
                        -(tonumber(mail.gross) or 0), src = "CONF" }
            end
        elseif mail.returnCandidate and senderSet[mail.sender] and mail.name and tonumber(mail.qty) then
            local key = fingerprint(char, { kind = "return", name = mail.name, qty = mail.qty })
            returnObserved[key] = true
            local previous = charPending[key]
            if previous and now - previous >= 2 then
                entry = { t = now, char = char, kind = "return", name = mail.name,
                    itemID = tonumber(mail.itemID), qty = tonumber(mail.qty), gross = 0, deposit = 0,
                    cut = 0, net = 0, src = "OBS" }
            else
                if not previous then charPending[key] = now end
            end
        end

        if entry then
            local mailForKey = { kind = entry.kind, name = entry.name, qty = entry.qty,
                gross = entry.gross, deposit = entry.deposit, cut = entry.cut }
            local key = fingerprint(char, mailForKey)
            local expires = now + (tonumber(mail.daysLeft) or 0) * 86400
            if not seenMatch(db.mailSeen, key, expires, matched, existingCount) then
                local year = yearOf(now)
                db.ledger[year] = db.ledger[year] or {}
                db.ledger[year][#db.ledger[year] + 1] = entry
                db.mailSeen[#db.mailSeen + 1] = { huella = key, expira = expires }
                added = added + 1
            end
        end
    end
    for key in pairs(charPending) do
        if not returnObserved[key] then charPending[key] = nil end
    end
    return added
end

function Ledger.vendorSale(db, char, now, itemID, name, qty, unitPrice)
    db.ledger = db.ledger or {}
    itemID, qty, unitPrice = tonumber(itemID), tonumber(qty), tonumber(unitPrice)
    if not itemID or type(name) ~= "string" or name == "" or not qty or qty <= 0 or not unitPrice or unitPrice <= 0 then return false end
    local matchedName
    for _, year in pairs(db.ledger) do
        for _, entry in ipairs(year) do
            if entry.kind == "buy" and ((tonumber(entry.itemID) and tonumber(entry.itemID) == itemID) or entry.name == name) then
                matchedName = tonumber(entry.itemID) == itemID and entry.name or matchedName or name
            end
        end
    end
    if not matchedName then return false end
    local gross = unitPrice * qty
    local year = yearOf(now)
    db.ledger[year] = db.ledger[year] or {}
    db.ledger[year][#db.ledger[year] + 1] = { t = now, char = char, kind = "sell", venue = "vendor",
        name = matchedName, itemID = itemID, qty = qty, gross = gross, deposit = 0, cut = 0, net = gross, src = "OBS" }
    return true
end

function Ledger.vendorUndo(db, char, name, qty)
    qty = tonumber(qty)
    if type(name) ~= "string" or not qty or qty <= 0 then return false end
    local nowOk, now = addon.Compat.call("time")
    now = nowOk and tonumber(now) or 0
    local latest, latestYear, latestIndex
    for year, entries in pairs(db and db.ledger or {}) do
        for index, entry in ipairs(entries) do
            local timestamp = tonumber(entry.t) or 0
            if entry.kind == "sell" and entry.venue == "vendor" and entry.char == char and entry.name == name and
                tonumber(entry.qty) == qty and timestamp <= now and now - timestamp < 43200 and
                (not latest or timestamp > latest or timestamp == latest and year == latestYear and index > latestIndex) then
                latest, latestYear, latestIndex = timestamp, year, index
            end
        end
    end
    if not latestIndex then return false end
    table.remove(db.ledger[latestYear], latestIndex)
    return true
end

local function includes(entry, since, char)
    return (tonumber(entry.t) or 0) >= (tonumber(since) or 0) and
        (char == nil or entry.char == char)
end

local function orderedYears(db)
    local years = {}
    for year in pairs(db and db.ledger or {}) do years[#years + 1] = year end
    table.sort(years, function(a, b)
        local an, bn = tonumber(a) or 0, tonumber(b) or 0
        if an ~= bn then return an < bn end
        return tostring(a) < tostring(b)
    end)
    return years
end

function Ledger.summary(db, since, char)
    local result = { sales = 0, gross = 0, cut = 0, deposit = 0, net = 0,
        purchases = 0, spent = 0, returns = 0, balance = 0 }
    for _, year in pairs(db and db.ledger or {}) do
        for _, entry in ipairs(year) do
            if includes(entry, since, char) then
                if entry.kind == "sell" then
                    result.sales = result.sales + (tonumber(entry.qty) or 0)
                    result.gross = result.gross + (tonumber(entry.gross) or 0)
                    result.cut = result.cut + (tonumber(entry.cut) or 0)
                    result.deposit = result.deposit + (tonumber(entry.deposit) or 0)
                    result.net = result.net + (tonumber(entry.net) or 0)
                elseif entry.kind == "buy" then
                    result.purchases = result.purchases + (tonumber(entry.qty) or 0)
                    result.spent = result.spent + (tonumber(entry.gross) or 0)
                elseif entry.kind == "return" then
                    result.returns = result.returns + (tonumber(entry.qty) or 0)
                end
                result.balance = result.balance + (tonumber(entry.net) or 0)
            end
        end
    end
    return result
end

function Ledger.items(db, since, char)
    local byName = {}
    for _, yearKey in ipairs(orderedYears(db)) do
        local year = db.ledger[yearKey]
        for _, entry in ipairs(year) do
            if includes(entry, since, char) and type(entry.name) == "string" and entry.name ~= "" then
                local item = byName[entry.name]
                if not item then
                    item = { name = entry.name, itemID = nil, sold = 0, gross = 0, deposit = 0, cut = 0,
                        net = 0, bought = 0, spent = 0, returned = 0, balance = 0, last = 0, chars = {},
                    }
                    byName[entry.name] = item
                end
                if not item.itemID and tonumber(entry.itemID) then item.itemID = tonumber(entry.itemID) end
                local timestamp, net = tonumber(entry.t) or 0, tonumber(entry.net) or 0
                if timestamp > item.last then item.last = timestamp end
                item.balance = item.balance + net
                if entry.char ~= nil then item.chars[entry.char] = (item.chars[entry.char] or 0) + net end
                if entry.kind == "sell" then
                    item.sold = item.sold + (tonumber(entry.qty) or 0)
                    item.gross = item.gross + (tonumber(entry.gross) or 0)
                    item.deposit = item.deposit + (tonumber(entry.deposit) or 0)
                    item.cut = item.cut + (tonumber(entry.cut) or 0)
                    item.net = item.net + net
                elseif entry.kind == "buy" then
                    item.bought = item.bought + (tonumber(entry.qty) or 0)
                    item.spent = item.spent + (tonumber(entry.gross) or 0)
                elseif entry.kind == "return" then
                    item.returned = item.returned + (tonumber(entry.qty) or 0)
                end
            end
        end
    end
    local result = {}
    for _, item in pairs(byName) do result[#result + 1] = item end
    table.sort(result, function(a, b)
        local aa, bb = math.abs(a.balance), math.abs(b.balance)
        if aa ~= bb then return aa > bb end
        if a.last ~= b.last then return a.last > b.last end
        return a.name < b.name
    end)
    return result
end

-- Las facturas de venta no traen el identificador: se aprende por nombre y se guarda.
function Ledger.itemID(db, name)
    return db and db.itemNames and tonumber(db.itemNames[name]) or nil
end

function Ledger.learn(db, name, itemID)
    itemID = tonumber(itemID)
    if not itemID or type(name) ~= "string" or name == "" then return end
    db.itemNames = db.itemNames or {}
    db.itemNames[name] = itemID
end

-- Nombres del libro sin identificador; otra operación del mismo objeto también lo aporta.
function Ledger.unknownNames(db)
    local unknown = {}
    for _, year in pairs(db and db.ledger or {}) do
        for _, entry in ipairs(year) do
            if type(entry.name) == "string" and not Ledger.itemID(db, entry.name) then
                if tonumber(entry.itemID) then Ledger.learn(db, entry.name, entry.itemID)
                else unknown[entry.name] = true end
            end
        end
    end
    for name in pairs(unknown) do
        if Ledger.itemID(db, name) then unknown[name] = nil end
    end
    return unknown
end

function Ledger.entries(db, since, char, name, limit)
    if type(name) ~= "string" or name == "" then return {} end
    local result, sequence = {}, 0
    for _, yearKey in ipairs(orderedYears(db)) do
        local year = db.ledger[yearKey]
        for _, entry in ipairs(year) do
            if includes(entry, since, char) and entry.name == name then
                result[#result + 1] = { entry = entry, sequence = sequence }
                sequence = sequence + 1
            end
        end
    end
    table.sort(result, function(a, b)
        local at, bt = tonumber(a.entry.t) or 0, tonumber(b.entry.t) or 0
        if at ~= bt then return at > bt end
        return a.sequence < b.sequence
    end)
    local entries = {}
    for i, value in ipairs(result) do
        if limit and i > math.max(0, tonumber(limit) or 0) then break end
        entries[#entries + 1] = value.entry
    end
    return entries
end
