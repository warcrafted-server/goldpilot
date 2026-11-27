return {
    ["deals evaluate vendor and resale opportunities"] = function(addon)
        local day, now = 100, 100 * 86400 + 100
        local function item(overrides)
            local value = { itemID = 7, min = 700, p50 = 1000, qty = 5, t = now,
                history = { { day - 2, 900, 1000, 5 }, { day - 1, 800, 1000, 5 }, { day, 500, 500, 5 } } }
            for key, entry in pairs(overrides or {}) do value[key] = entry end
            return value
        end
        local vendor = addon.Deals.evaluate(item({ min = 50, vendor = 100, history = {} }), { now = now })
        assert(vendor.kind == "vendor" and vendor.profit == 50 and vendor.ref == 100)
        local resale = addon.Deals.evaluate(item(), { now = now })
        assert(resale.kind == "resale" and resale.ref == 1000 and resale.profit == 250)
        assert(not addon.Deals.evaluate(item({ history = { { day - 1, 800, 1000, 5 } } }), { now = now }))
        assert(not addon.Deals.evaluate(item({ history = { { day - 1, 800, 1000, 5 }, { day, 500, 500, 5 } } }), { now = now }))
        assert(not addon.Deals.evaluate(item({ t = now - 3601 }), { now = now }))
        local missingMin = item(); missingMin.min = nil
        assert(not addon.Deals.evaluate(missingMin, { now = now }))
        assert(not addon.Deals.evaluate(item({ qty = 2 }), { now = now }))
        assert(not addon.Deals.evaluate(item({ min = 701 }), { now = now }))
        assert(not addon.Deals.evaluate(item({ min = 700 }), { now = now, minProfit = 400 }))
        local found = addon.Deals.find({ item({ itemID = 3 }), item({ itemID = 2, vendor = 900 }), item({ itemID = 1 }) }, { now = now, limit = 2 })
        assert(#found == 2 and found[1].kind == "vendor" and found[2].itemID == 1)
    end,
    ["deals UI shows and opens a result without buying"] = function(addon, mock)
        local oldAuction, oldApi, oldDB = _G.AuctionHouseFrame, C_AuctionHouse, GoldPilotDB
        local oldVendor = addon.Valuation.vendor
        local auction, browse = CreateFrame("Frame"), CreateFrame("Frame")
        browse:Show(); auction.BrowseResultsFrame = browse; auction.SelectBrowseResult = function(self, value) self.selected = value end
        _G.AuctionHouseFrame = auction
        local bought, searched = 0, nil
        C_AuctionHouse = {
            MakeItemKey = function(id) return { itemID = id } end,
            GetItemKeyInfo = function(key) return { itemName = "Bargain " .. key.itemID, isCommodity = true } end,
            PlaceBid = function() bought = bought + 1 end,
            SendSearchQuery = function(key) searched = key.itemID end,
            StartCommoditiesPurchase = function() bought = bought + 1 end,
            ConfirmCommoditiesPurchase = function() bought = bought + 1 end,
        }
        addon.Valuation.vendor = function(id) if id == 42 then return { price = 100 } end end
        local house = addon.AuctionHouse.houseKey()
        GoldPilotDB = { prices = { [house] = { [42] = "199999:50:80:5||" } } }
        addon.Modules:enableAll()
        addon.Events:send("GOLDPILOT_SCAN_PROGRESS", nil)
        mock.fire("AUCTION_HOUSE_SHOW"); mock.flushTimers()
        assert(addon.DealsUI.frame:IsShown())
        local button = addon.DealsUI.frame.rows[1].button
        button.scripts.OnClick()
        assert(auction.selected and auction.selected.itemKey.itemID == 42 and bought == 0)
        assert(searched == 42, "al abrir el objeto se piden sus precios")
        browse:Hide(); auction.CommoditiesSellFrame = CreateFrame("Frame"); auction.CommoditiesSellFrame:Show()
        mock.flushTimers(); assert(not addon.DealsUI.frame:IsShown())
        browse:Show(); addon.Settings.set("deals", false); mock.flushTimers(); assert(not addon.DealsUI.frame:IsShown())
        _G.AuctionHouseFrame, C_AuctionHouse, GoldPilotDB = oldAuction, oldApi, oldDB
        addon.Valuation.vendor = oldVendor
    end,
    ["deals UI tolerates absent auction frame"] = function(addon, mock)
        local old = _G.AuctionHouseFrame; _G.AuctionHouseFrame = nil
        addon.Modules:enableAll(); mock.fire("AUCTION_HOUSE_SHOW"); mock.flushTimers()
        _G.AuctionHouseFrame = old
    end,
}
