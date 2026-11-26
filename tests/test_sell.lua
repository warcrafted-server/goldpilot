return {
    ["sell sugiere mínimo menos uno o referencia y calcula comisión y depósito"] = function(addon)
        local result = addon.Sell.suggest({ min = 100, ref = 200, quantity = 3, deposit = 4 })
        assert(result.price == 99 and result.basis == "undercut")
        assert(result.net == math.floor(99 * 3 * 0.95) - 4)
        result = addon.Sell.suggest({ ref = 200, quantity = 1 })
        assert(result.price == 200 and result.basis == "reference")
        assert(addon.Sell.suggest({}) == nil)
    end,
    ["sell alerta si el vendedor paga más y si cae el mercado"] = function(addon)
        local result = addon.Sell.suggest({ min = 100, vendor = 100 })
        assert(result.warning == "vendor" and result.floor == math.ceil(100 / 0.95))
        result = addon.Sell.suggest({ min = 60, ref = 100 })
        assert(result.warning == "crashed")
    end,
    ["sell ignora anuncios que son solo propios"] = function(addon)
        assert(addon.Sell.otherMin({
            { price = 1, qty = 4, own = 4 },
            { price = 12, qty = 6, own = 5 },
            { price = 9, qty = 2, own = false },
        }) == 9)
        assert(addon.Sell.otherMin({ { price = 1, qty = 2, own = true } }) == nil)
    end,
    ["sell assistant displays suggestions, fills price, closes and respects setting"] = function(addon, mock)
        local oldAuction, oldHook, oldAuctionAPI = _G.AuctionHouseFrame, hooksecurefunc, C_AuctionHouse
        local oldGetItemID = C_Item.GetItemID
        local auction = CreateFrame("Frame")
        local function input(method, value)
            local object = CreateFrame("Frame")
            object[method == "GetAmount" and "amount" or method == "GetQuantity" and "quantity" or "duration"] = value
            object[method] = function(self) return self[method == "GetAmount" and "amount" or method == "GetQuantity" and "quantity" or "duration"] end
            return object
        end
        local display = CreateFrame("Button")
        display.GetItem = function(self) return self.item end
        display.SetItem = function(self, item) self.item = item end
        local price = { SetAmount = function(self, value) self.amount = value end }
        local sell = CreateFrame("Frame")
        sell.ItemDisplay, sell.PriceInput = display, price
        sell.QuantityInput = input("GetQuantity", 2)
        sell.Duration = input("GetDuration", 12)
        auction.CommoditiesSellFrame = sell
        auction.ItemSellFrame = CreateFrame("Frame")
        auction.SetPostItem = function() end
        _G.AuctionHouseFrame = auction
        hooksecurefunc = function(object, method, callback)
            local original = object[method]
            object[method] = function(self, ...)
                local result = original(self, ...)
                callback()
                return result
            end
        end
        C_Item.GetItemID = function(item) return type(item) == "table" and item.itemID or item end
        C_AuctionHouse = {
            GetNumCommoditySearchResults = function() return 2 end,
            GetCommoditySearchResultInfo = function(_, index)
                return index == 1 and { unitPrice = 50, quantity = 2, numOwnerItems = 2 }
                    or { unitPrice = 80, quantity = 3, numOwnerItems = 0 }
            end,
            CalculateCommodityDeposit = function() return 5 end,
        }
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        display:SetItem({ itemID = 123 })
        mock.flushTimers()
        assert(addon.SellAssist.frame and addon.SellAssist.frame:IsShown())
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 123)
        assert(addon.SellAssist.suggestion.price == 79)
        addon.SellAssist.frame.useButton.scripts.OnClick()
        assert(price.amount == 79)
        mock.fire("AUCTION_HOUSE_CLOSED")
        assert(not addon.SellAssist.frame:IsShown())
        addon.Settings.set("sellAssist", false)
        mock.fire("AUCTION_HOUSE_SHOW")
        display:SetItem({ itemID = 123 })
        mock.flushTimers()
        assert(not addon.SellAssist.frame:IsShown())
        addon.Settings.set("sellAssist", true)
        _G.AuctionHouseFrame = nil
        mock.fire("AUCTION_HOUSE_SHOW")
        _G.AuctionHouseFrame, hooksecurefunc, C_AuctionHouse = oldAuction, oldHook, oldAuctionAPI
        C_Item.GetItemID = oldGetItemID
    end,
}
