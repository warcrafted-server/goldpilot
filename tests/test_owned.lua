return {
    ["owned review classifies and orders auctions and summarizes counts"] = function(addon)
        local rows, summary = addon.Owned.review({
            { auctionID = 1, name = "Okay", key = 1, unitPrice = 100, quantity = 1 },
            { auctionID = 2, name = "Small cut", key = 2, unitPrice = 100, quantity = 1 },
            { auctionID = 3, name = "Big cut", key = 3, unitPrice = 200, quantity = 1 },
            { auctionID = 4, name = "Sold", key = 4, unitPrice = 80, quantity = 1, status = 1 },
            { auctionID = 5, name = "Unknown", key = 5, unitPrice = 50, quantity = 1 },
        }, function(key)
            if key == 1 then return { min = 100, t = 90 } end
            if key == 2 then return { min = 90, t = 90 } end
            if key == 3 then return { min = 100, t = 90 } end
        end, 100)
        assert(rows[1].auction.auctionID == 3 and rows[1].state == "undercut")
        assert(rows[1].suggestion.price == 99 and rows[1].age == 10)
        assert(rows[2].auction.auctionID == 2 and rows[2].state == "undercut")
        assert(rows[3].state == "unknown" and rows[4].state == "ok" and rows[5].state == "sold")
        assert(summary.undercut == 2 and summary.unknown == 1 and summary.ok == 1 and summary.sold == 1)
    end,
    ["owned UI queries, shows rows, confirms cancellation and hides"] = function(addon, mock)
        local oldAuction, oldApi = _G.AuctionHouseFrame, C_AuctionHouse
        local oldPrices, oldValue, oldEnqueue = addon.Prices.get, addon.Valuation.value, addon.AuctionHouse.enqueue
        local auction, auctionsFrame = CreateFrame("Frame"), CreateFrame("Frame")
        auctionsFrame:Show(); auction.AuctionsFrame = auctionsFrame; _G.AuctionHouseFrame = auction
        local canceled, queried, enqueued = nil, 0, 0
        C_AuctionHouse = {
            QueryOwnedAuctions = function() queried = queried + 1 end,
            GetOwnedAuctions = function() return {
                { auctionID = 77, itemKey = { itemID = 100 }, itemLink = "Herb", status = 0, quantity = 2, buyoutAmount = 200 },
                { auctionID = 78, itemKey = { itemID = 101 }, itemLink = "Ore", status = 1, quantity = 1, buyoutAmount = 300 },
                { auctionID = 79, itemKey = { itemID = 102 }, itemLink = "Gear", status = 0, quantity = 4, buyoutAmount = 400 },
                { auctionID = 80, itemKey = { itemID = 103 }, itemLink = "Bid only", status = 0, quantity = 1 },
            } end,
            GetItemKeyInfo = function(key) return { itemName = "Item " .. key.itemID, isCommodity = key.itemID ~= 102 } end,
            GetCancelCost = function() return 5 end,
            CancelAuction = function(id) canceled = id end,
        }
        addon.Prices.get = function(_, _, key) if tonumber(key) == 100 then return { min = 80, t = 199999 } end end
        addon.Valuation.value = function() return {} end
        addon.AuctionHouse.enqueue = function() enqueued = enqueued + 1 end
        addon.Modules:enableAll()
        local converted = addon.MyAuctions.convertOwned()
        local loaded = C_AuctionHouse.GetItemKeyInfo
        C_AuctionHouse.GetItemKeyInfo = function() return nil end
        local during = addon.MyAuctions.convertOwned()
        C_AuctionHouse.GetItemKeyInfo = loaded
        for index, row in ipairs(during) do
            assert(row.name == converted[index].name and row.unitPrice == converted[index].unitPrice, "sin datos del objeto no cambian ni el nombre ni el precio")
            assert(not string.find(row.name, "|H", 1, true))
        end
        assert(#converted == 3 and converted[3].itemID == 102 and converted[3].unitPrice == 100)
        mock.fire("AUCTION_HOUSE_SHOW"); mock.flushTimers()
        assert(queried == 1 and addon.MyAuctions.frame:IsShown())
        assert(not (addon.SellAssist.frame and addon.SellAssist.frame:IsShown()))
        mock.fire("OWNED_AUCTIONS_UPDATED")
        assert(addon.MyAuctions.frame.summary:GetText():find("1 undercut", 1, true))
        local sawUndercut, sawSold = false, false
        for _, row in ipairs(addon.MyAuctions.frame.rows) do
            if row.stateKind == "undercut" then sawUndercut = true; assert(not row.button.hidden) end
            if row.stateKind == "sold" then sawSold = true; assert(row.button.hidden) end
        end
        assert(sawUndercut and sawSold)
        assert(enqueued > 0)
        local button = addon.MyAuctions.frame.rows[1].button
        button.scripts.OnClick(); assert(canceled == nil)
        button.scripts.OnClick(); assert(canceled == 77)
        auctionsFrame:Hide(); mock.flushTimers()
        assert(not addon.MyAuctions.frame:IsShown())
        addon.Settings.set("myAuctions", false)
        auctionsFrame:Show(); mock.fire("AUCTION_HOUSE_SHOW"); mock.flushTimers()
        assert(not addon.MyAuctions.frame:IsShown())
        _G.AuctionHouseFrame, C_AuctionHouse = oldAuction, oldApi
        addon.Prices.get, addon.Valuation.value, addon.AuctionHouse.enqueue = oldPrices, oldValue, oldEnqueue
    end,
    ["owned UI tolerates absent auction frame"] = function(addon, mock)
        local old = _G.AuctionHouseFrame; _G.AuctionHouseFrame = nil
        addon.Modules:enableAll(); mock.fire("AUCTION_HOUSE_SHOW"); mock.flushTimers()
        _G.AuctionHouseFrame = old
    end,
}
