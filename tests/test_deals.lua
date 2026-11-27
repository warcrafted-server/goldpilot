return {
    ["deals evaluate vendor and resale, thresholds and max pay"] = function(addon)
        local day, now = 100, 100 * 86400 + 100
        local function item(overrides)
            local value = { itemID = 7, min = 700, p50 = 1000, qty = 5, t = now,
                history = { { day - 2, 900, 1000, 5 }, { day - 1, 800, 1000, 5 }, { day, 500, 500, 5 } } }
            for key, entry in pairs(overrides or {}) do value[key] = entry end
            return value
        end
        local vendor = addon.Deals.evaluate(item({ min = 50, vendor = 100, history = {} }), { now = now })
        assert(vendor.kind == "vendor" and vendor.profit == 50 and vendor.ref == 100 and vendor.maxPay == 50)
        local tiny = item({ min = 90, vendor = 112, history = {} })
        assert(not addon.Deals.evaluate(tiny, { now = now }))
        assert(addon.Deals.evaluate(tiny, { now = now, small = true }).profit == 22)
        local resale = addon.Deals.evaluate(item(), { now = now })
        assert(resale.kind == "resale" and resale.ref == 1000 and resale.profit == 250 and resale.maxPay == 700)
        local check = addon.Deals.check(vendor, 40)
        assert(check.good and check.gain == 60 and check.price == 40)
        check = addon.Deals.check(vendor, 51)
        assert(not check.good and check.gain == 49)
        assert(not addon.Deals.evaluate(item({ history = { { day - 1, 800, 1000, 5 } } }), { now = now }))
        assert(not addon.Deals.evaluate(item({ t = now - 3601 }), { now = now }))
        local small = addon.Deals.find({ tiny, item({ itemID = 9 }), item({ itemID = 8 }) }, { now = now, small = true, limit = 1 })
        assert(#small.vendor == 1 and #small.resale == 1 and small.resale[1].itemID == 8)
    end,
    ["deals names truncate without splitting UTF-8 characters"] = function(addon)
        local name = "Espada larga esquelética"
        assert(addon.Widgets.truncate(name, 22):sub(-3) == "…")
        local long = name .. " con filo antiguo"
        local truncated = addon.Widgets.truncate(long, 22)
        assert(truncated:sub(-3) == "…")
        assert(not truncated:find("\195$"))
        assert(addon.Widgets.truncate("corto", 23) == "corto")
    end,
    ["deals UI shows sections, toggles small profits, and checks live prices without buying"] = function(addon, mock)
        local oldAuction, oldApi, oldDB = _G.AuctionHouseFrame, C_AuctionHouse, GoldPilotDB
        local oldVendor = addon.Valuation.vendor
        local auction, browse = CreateFrame("Frame"), CreateFrame("Frame")
        browse:Show(); auction.BrowseResultsFrame = browse; auction.SelectBrowseResult = function(self, value) self.selected = value end
        _G.AuctionHouseFrame = auction
        local bought, searched, livePrice = 0, nil, 100
        C_AuctionHouse = {
            MakeItemKey = function(id) return { itemID = id } end,
            GetItemKeyInfo = function(key) return { itemName = "Bargain " .. key.itemID, isCommodity = true } end,
            PlaceBid = function() bought = bought + 1 end,
            SendSearchQuery = function(key) searched = key.itemID end,
            StartCommoditiesPurchase = function() bought = bought + 1 end,
            ConfirmCommoditiesPurchase = function() bought = bought + 1 end,
            GetNumCommoditySearchResults = function() return 1 end,
            GetCommoditySearchResultInfo = function() return { unitPrice = livePrice, quantity = 1, numOwnerItems = 0 } end,
        }
        addon.Valuation.vendor = function(id) if id == 42 then return { price = 100 } elseif id == 43 then return { price = 112 } end end
        local house = addon.AuctionHouse.houseKey()
        GoldPilotDB = { prices = { [house] = {
            [42] = "199999:50:80:5||", [43] = "199999:90:100:5||",
        } } }
        addon.Modules:enableAll()
        addon.Events:send("GOLDPILOT_SCAN_PROGRESS", nil)
        mock.fire("AUCTION_HOUSE_SHOW"); mock.flushTimers()
        local panel = addon.DealsUI.frame
        assert(panel:IsShown() and panel.sections.resale and panel.sections.vendor)
        assert(panel.sections.vendor.title:GetText() == addon.L.DEALS_SECTION_VENDOR)
        panel.checkbox:SetChecked(true); panel.checkbox.scripts.OnClick(panel.checkbox)
        assert(addon.Settings.get("dealsSmall") and #addon.DealsUI.results.vendor == 2)
        local button = panel.sections.vendor.rows[1].button
        button.scripts.OnClick()
        assert(auction.selected and auction.selected.itemKey.itemID == 42 and bought == 0)
        assert(searched == 42, "al abrir el objeto se piden sus precios")
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 42)
        assert(panel.live:GetText():find("no longer a bargain", 1, true))
        livePrice = 40
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 42)
        assert(panel.live:GetText():find("now", 1, true) and bought == 0)
        browse:Hide(); auction.CommoditiesSellFrame = CreateFrame("Frame"); auction.CommoditiesSellFrame:Show()
        mock.flushTimers(); assert(not panel:IsShown())
        browse:Show(); addon.Settings.set("deals", false); mock.flushTimers(); assert(not panel:IsShown())
        _G.AuctionHouseFrame, C_AuctionHouse, GoldPilotDB = oldAuction, oldApi, oldDB
        addon.Valuation.vendor = oldVendor
    end,
    ["deals UI tolerates absent auction frame"] = function(addon, mock)
        local old = _G.AuctionHouseFrame; _G.AuctionHouseFrame = nil
        addon.Modules:enableAll(); mock.fire("AUCTION_HOUSE_SHOW"); mock.flushTimers()
        _G.AuctionHouseFrame = old
    end,
}
