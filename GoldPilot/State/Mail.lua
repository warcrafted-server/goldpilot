local _, addon = ...

local open = false
local opening = 0
local MAX_LISTED = 6

local function after(delay, callback)
    addon.Compat.call("C_Timer.After", delay, callback)
end

local function combat()
    local ok, value = addon.Compat.call("InCombatLockdown")
    return ok and value == true
end

local function readMailbox()
    if not open or combat() or addon.safeMode then return end
    local countOk, count = addon.Compat.call("GetInboxNumItems")
    if not countOk then return end
    local nowOk, now = addon.Compat.call("time")
    if not nowOk or not tonumber(now) then return end
    local nameOk, character = addon.Compat.call("UnitName", "player")
    if not nameOk or type(character) ~= "string" or character == "" then character = "unknown" end
    local mails = {}
    for index = 1, math.min(100, tonumber(count) or 0) do
        local headerOk, header = (function()
            local values = { addon.Compat.call("GetInboxHeaderInfo", index) }
            local unpacked = {}
            for field = 2, 14 do unpacked[field - 1] = values[field] end
            return values[1], unpacked
        end)()
        if headerOk then
            local sender, money, cod, daysLeft = header[3], tonumber(header[5]) or 0,
                tonumber(header[6]) or 0, tonumber(header[7]) or 0
            local hasItem, wasReturned, canReply = header[8] and true, header[10] and true, header[12] and true
            local invoiceOk, invoice = (function()
                local values = { addon.Compat.call("GetInboxInvoiceInfo", index) }
                local unpacked = {}
                for field = 2, 12 do unpacked[field - 1] = values[field] end
                return values[1], unpacked
            end)()
            local invoiceType = invoiceOk and invoice[1] or nil
            local isInvoice = invoiceType ~= nil
            local itemID, attachedName, qty
            if hasItem then
                local itemOk, item = (function()
                    local values = { addon.Compat.call("GetInboxItem", index, 1) }
                    local unpacked = {}
                    for field = 2, 5 do unpacked[field - 1] = values[field] end
                    return values[1], unpacked
                end)()
                if itemOk then attachedName, itemID, qty = item[1], tonumber(item[2]), tonumber(item[4]) end
            end
            local name = isInvoice and invoice[2] or attachedName
            local mail = {
                sender = sender, invoice = isInvoice, invoiceType = invoiceType,
                name = name, itemID = itemID, qty = isInvoice and tonumber(invoice[11]) or qty,
                gross = isInvoice and tonumber(invoice[4]) or 0,
                deposit = isInvoice and tonumber(invoice[6]) or 0,
                cut = isInvoice and tonumber(invoice[7]) or 0,
                daysLeft = daysLeft,
                returnCandidate = invoiceOk and not isInvoice and hasItem and money == 0 and cod == 0 and
                    not canReply and not wasReturned,
            }
            mails[#mails + 1] = mail
        end
    end
    GoldPilotDB = GoldPilotDB or {}
    local added = addon.Ledger.sync(GoldPilotDB, character, mails, tonumber(now))
    if added > 0 then addon.Log:info(string.format(addon.L.LEDGER_ADDED, added)) end
end

-- Con un solo objeto y sin dinero manda el nombre del objeto; si no, el asunto del correo.
local function describe(index, subject, money, hasItem)
    local entry = { name = type(subject) == "string" and subject ~= "" and subject or nil,
        money = money > 0 and money or nil }
    if money > 0 or (tonumber(hasItem) or 1) ~= 1 then return entry end
    local ok, name, _, _, qty = addon.Compat.call("GetInboxItem", index, 1)
    if ok and type(name) == "string" and name ~= "" then entry.name, entry.qty = name, tonumber(qty) end
    return entry
end

local function snapshot()
    if not open or addon.safeMode then return end
    local countOk, count, total = addon.Compat.call("GetInboxNumItems")
    if not countOk or not tonumber(count) then return end
    local nowOk, now = addon.Compat.call("time")
    if not nowOk or not tonumber(now) then return end
    local nameOk, character = addon.Compat.call("UnitName", "player")
    if not nameOk or type(character) ~= "string" or character == "" then character = "unknown" end
    local money, items, expires, list, countedMails = 0, 0, nil, {}, 0
    for index = 1, math.min(100, math.max(0, tonumber(count) or 0)) do
        local ok, _, _, _, subject, mailMoney, cod, daysLeft, hasItem = addon.Compat.call("GetInboxHeaderInfo", index)
        if ok then
            mailMoney, cod, daysLeft = tonumber(mailMoney), tonumber(cod), tonumber(daysLeft)
            local hasAttachment = hasItem == true or (tonumber(hasItem) or 0) > 0
            if mailMoney then money = money + mailMoney end
            local counted = (mailMoney or 0) > 0 or hasAttachment and (cod or 0) == 0
            if hasAttachment and (cod or 0) == 0 then items = items + 1 end
            if counted then
                countedMails = countedMails + 1
                if #list < MAX_LISTED then
                    list[#list + 1] = describe(index, subject, mailMoney or 0, hasItem)
                end
            end
            if counted and daysLeft and daysLeft >= 0 then
                local expiry = now + daysLeft * 86400
                if not expires or expiry < expires then expires = expiry end
            end
        end
    end
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.mailPending = GoldPilotDB.mailPending or {}
    GoldPilotDB.mailPending[character] = { t = now, money = money, items = items,
        total = math.max(tonumber(count) or 0, tonumber(total) or 0), expires = expires, list = list, counted = countedMails }
end

addon.Modules:register("mail", {
    requires = { "GetInboxNumItems" },
    onEnable = function()
        addon.Events:subscribe("mail", "MAIL_SHOW", function()
            open = true
            opening = opening + 1
            local current = opening
            after(1, function() if open and opening == current then readMailbox() end end)
            after(4, function() if open and opening == current then readMailbox() end end)
        end)
        addon.Events:subscribe("mail", "MAIL_INBOX_UPDATE", readMailbox, 1)
        addon.Events:subscribe("mail", "MAIL_INBOX_UPDATE", snapshot)
        addon.Events:subscribe("mail", "MAIL_CLOSED", function() open = false; opening = opening + 1 end)
    end,
})
