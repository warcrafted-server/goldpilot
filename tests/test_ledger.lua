local function sale(name, qty, gross, deposit, cut, daysLeft)
    return { invoice = true, invoiceType = "seller", sender = "Auctioneer", name = name,
        qty = qty, gross = gross, deposit = deposit, cut = cut, daysLeft = daysLeft or 2 }
end

local function setupCollector()
    local mails = {}
    GetInboxNumItems = function() return #mails end
    GetInboxHeaderInfo = function(i)
        local mail = mails[i]
        return nil, nil, mail.sender, nil, mail.money or 0, mail.cod or 0, mail.daysLeft or 2,
            mail.hasItem and 1 or nil, false, mail.wasReturned and 1 or nil, nil, mail.canReply and 1 or nil, false
    end
    GetInboxInvoiceInfo = function(i)
        local mail = mails[i]
        if not mail.invoice then return nil end
        return mail.invoiceType, mail.name, nil, mail.gross, nil, mail.deposit, mail.cut, 0, 0, 0, mail.qty, false
    end
    GetInboxItem = function(i)
        local mail = mails[i]
        return mail.name, mail.itemID, nil, mail.qty
    end
    return mails
end

return {
    ["ledger registra las cinco ventas y la compra con totales confirmados"] = function(addon)
        local db = {}
        local sales = {
            sale("A", 23, 3036, 46, 151), sale("B", 51, 765, 69, 38),
            sale("C", 29, 841, 58, 42), sale("D", 6, 294, 18, 14), sale("E", 4, 536, 8, 26),
        }
        for _, mail in ipairs(sales) do assert(addon.Ledger.sync(db, "Tester", { mail }, 100000) == 1) end
        local buy = { invoice = true, invoiceType = "buyer", sender = "Auctioneer", name = "Bought",
            itemID = 2681, qty = 1, gross = 13, daysLeft = 2 }
        assert(addon.Ledger.sync(db, "Tester", { buy }, 100000) == 1)
        local expected = { 2931, 796, 857, 298, 518 }
        for i, amount in ipairs(expected) do assert(db.ledger[1970][i].net == amount) end
        local purchase = db.ledger[1970][6]
        assert(purchase.kind == "buy" and purchase.itemID == 2681 and purchase.qty == 1 and purchase.net == -13)
    end,
    ["ledger empareja uno a uno y tolera reaperturas hasta caducidad"] = function(addon)
        local db, mail = {}, sale("Same", 1, 100, 10, 5, 2)
        assert(addon.Ledger.sync(db, "Tester", { mail, sale("Same", 1, 100, 10, 5, 2) }, 100000) == 2)
        assert(addon.Ledger.sync(db, "Tester", { sale("Same", 1, 100, 10, 5, 2 - 1 / 24) }, 103600) == 0)
        assert(addon.Ledger.sync(db, "Tester", { sale("Same", 1, 100, 10, 5, 1) }, 186400) == 0)
        assert(addon.Ledger.sync(db, "Tester", { sale("Same", 1, 100, 10, 5, 4) }, 190000) == 1)
        assert(#db.ledger[1970] == 3)
    end,
    ["ledger espera dos lecturas para devoluciones y excluye correos de jugadores"] = function(addon)
        local db = {}
        addon.Ledger.sync(db, "Tester", { sale("Known", 1, 100, 0, 5) }, 100000)
        local returned = { returnCandidate = true, sender = "Auctioneer", name = "Returned", itemID = 42,
            qty = 1, daysLeft = 2 }
        assert(addon.Ledger.sync(db, "Tester", { returned }, 100010) == 0)
        assert(addon.Ledger.sync(db, "Tester", { returned }, 100011) == 0)
        assert(addon.Ledger.sync(db, "Tester", { returned }, 100012) == 1)
        assert(addon.Ledger.sync(db, "Tester", { returned }, 100013) == 0)
        local returnedAgain = { returnCandidate = true, sender = "Auctioneer", name = "Returned again", itemID = 43,
            qty = 1, daysLeft = 2 }
        assert(addon.Ledger.sync(db, "Tester", { returnedAgain }, 100020) == 0)
        assert(addon.Ledger.sync(db, "Tester", { returnedAgain }, 100022) == 1)
        local playerMail = { returnCandidate = true, sender = "Player", name = "Gift", qty = 1, daysLeft = 2 }
        assert(addon.Ledger.sync(db, "Tester", { playerMail }, 100020) == 0)
        local returns = addon.Ledger.summary(db, 0)
        assert(returns.returns == 2)
    end,
    ["ledger resumen suma operaciones desde la fecha indicada"] = function(addon, mock)
        local db = {}
        addon.Ledger.sync(db, "Tester", { sale("A", 2, 1000, 50, 50) }, 100000)
        addon.Ledger.sync(db, "Tester", { { invoice = true, invoiceType = "buyer", sender = "Auctioneer",
            name = "B", itemID = 13, qty = 1, gross = 200, daysLeft = 2 } }, 100010)
        local summary = addon.Ledger.summary(db, 100005)
        assert(summary.sales == 0 and summary.purchases == 1 and summary.spent == 200)
        assert(summary.balance == -200)
        GoldPilotDB = { ledger = { [1970] = { { kind = "buy", t = 200000, qty = 1, gross = 200, net = -200 } } } }
        SlashCmdList.GOLDPILOT("ledger")
        assert(string.find(table.concat(mock.output, " "), "balance %-") ~= nil)
    end,
    ["ledger registra dos devoluciones idénticas y no las duplica en otra lectura"] = function(addon)
        local db = {}
        addon.Ledger.sync(db, "Tester", { sale("Known", 1, 100, 0, 5) }, 110000)
        local returned = { returnCandidate = true, sender = "Auctioneer", name = "Twin", itemID = 42, qty = 1, daysLeft = 2 }
        assert(addon.Ledger.sync(db, "Tester", { returned, returned }, 110010) == 0)
        assert(addon.Ledger.sync(db, "Tester", { returned, returned }, 110012) == 2)
        assert(addon.Ledger.sync(db, "Tester", { returned, returned }, 110014) == 0)
        assert(addon.Ledger.summary(db, 0).returns == 2)
    end,
    ["colector solo lee buzón abierto fuera de combate y respeta modo seguro"] = function(addon, mock)
        local mails = setupCollector()
        mails[1] = { invoice = true, invoiceType = "seller", sender = "Auctioneer", name = "A",
            qty = 1, gross = 100, deposit = 0, cut = 5 }
        addon.Modules:enableAll()
        mock.fire("MAIL_INBOX_UPDATE")
        mock.flushTimers()
        assert(not GoldPilotDB or not GoldPilotDB.ledger)
        mock.fire("MAIL_SHOW")
        mock.flushTimers()
        assert(GoldPilotDB.ledger and #GoldPilotDB.ledger[1970] == 1)
        mails[1] = sale("A", 1, 100, 0, 5)
        mock.combat = true
        mock.fire("MAIL_INBOX_UPDATE")
        mock.flushTimers()
        assert(#GoldPilotDB.ledger[1970] == 1)
        mock.combat = false
        addon.safeMode = true
        mails[1] = sale("B", 1, 200, 0, 10)
        mock.fire("MAIL_INBOX_UPDATE")
        mock.flushTimers()
        assert(#GoldPilotDB.ledger[1970] == 1)
        addon.safeMode = false
        mock.fire("MAIL_CLOSED")
        mails[1] = sale("C", 1, 200, 0, 10)
        mock.fire("MAIL_INBOX_UPDATE")
        mock.flushTimers()
        assert(#GoldPilotDB.ledger[1970] == 1)
        mock.fire("MAIL_SHOW")
        mock.flushTimers()
        mails[1] = { sender = "Auctioneer", name = "Delayed", itemID = 77, qty = 1, hasItem = true }
        mock.fire("MAIL_INBOX_UPDATE")
        mock.flushTimers()
        mails[1] = { invoice = true, invoiceType = "seller", sender = "Auctioneer", name = "Delayed",
            qty = 1, gross = 200, deposit = 0, cut = 10 }
        mock.fire("MAIL_INBOX_UPDATE")
        mock.flushTimers()
        assert(#GoldPilotDB.ledger[1970] == 3 and GoldPilotDB.ledger[1970][3].kind == "sell")
    end,
    ["colector obtiene itemID de compra y registra dos devoluciones iguales"] = function(addon, mock)
        local mails = setupCollector()
        local tick = 300000
        time = function() return tick end
        addon.Ledger.pendingReturns = nil
        GoldPilotDB = {}
        mails[1] = { invoice = true, invoiceType = "buyer", sender = "Auctioneer", name = "Bought",
            gross = 13, qty = 1, itemID = 2681, hasItem = 1 }
        addon.Modules:enableAll()
        mock.fire("MAIL_SHOW")
        mock.flushTimers()
        assert(#GoldPilotDB.ledger[1970] == 1)
        assert(GoldPilotDB.ledger[1970][1].kind == "buy" and GoldPilotDB.ledger[1970][1].itemID == 2681)
        local returned = { sender = "Auctioneer", name = "Twin", itemID = 42, qty = 1, hasItem = 1 }
        mails[1], mails[2] = returned, returned
        tick = tick + 10
        mock.fire("MAIL_INBOX_UPDATE")
        mock.flushTimers()
        tick = tick + 2
        mock.fire("MAIL_INBOX_UPDATE")
        mock.flushTimers()
        assert(#GoldPilotDB.ledger[1970] == 3)
        assert(GoldPilotDB.ledger[1970][2].kind == "return" and GoldPilotDB.ledger[1970][3].kind == "return")
    end,
}
