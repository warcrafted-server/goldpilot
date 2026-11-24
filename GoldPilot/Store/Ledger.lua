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

function Ledger.summary(db, since)
    local result = { sales = 0, gross = 0, cut = 0, deposit = 0, net = 0,
        purchases = 0, spent = 0, returns = 0, balance = 0 }
    for _, year in pairs(db and db.ledger or {}) do
        for _, entry in ipairs(year) do
            if (tonumber(entry.t) or 0) >= (tonumber(since) or 0) then
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
