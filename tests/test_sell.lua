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
        local oldGetItemID, oldValue = C_Item.GetItemID, addon.Valuation.value
        local depositAmount = 5
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
            CalculateCommodityDeposit = function() return depositAmount end,
        }
        addon.Valuation.value = function() return { ref = { price = 100, class = "OBS" } } end
        addon.Modules:enableAll()
        mock.fire("AUCTION_HOUSE_SHOW")
        display:SetItem({ itemID = 123 })
        mock.flushTimers()
        assert(addon.SellAssist.frame and addon.SellAssist.frame:IsShown())
        local panel = addon.SellAssist.frame
        assert(panel.point[2] == auction and panel.point[3] == "TOPRIGHT" and panel.x == 4 and panel.y == -30)
        assert(panel.rows[1].value:GetText():find(addon.L.SELL_CONF_OBS, 1, true))
        local withDepositHeight = panel:GetHeight()
        depositAmount = nil
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 123)
        assert(panel:GetHeight() < withDepositHeight)
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
        assert(not addon.SellAssist.frame:IsShown())
        _G.AuctionHouseFrame, hooksecurefunc, C_AuctionHouse = oldAuction, oldHook, oldAuctionAPI
        C_Item.GetItemID, addon.Valuation.value = oldGetItemID, oldValue
    end,
    ["sell assistant reads gear listings with the full key and never suggests without them"] = function(addon, mock)
        local old = { auction = _G.AuctionHouseFrame, hook = hooksecurefunc, api = C_AuctionHouse,
            getID = C_Item.GetItemID, value = addon.Valuation.value, db = GoldPilotDB }
        local ok, err = pcall(function()
            local auction, display, sell = CreateFrame("Frame"), CreateFrame("Button"), CreateFrame("Frame")
            display.GetItem = function(self) return self.item end
            display.SetItem = function(self, item) self.item = item end
            sell.ItemDisplay, sell.PriceInput = display, { SetAmount = function() end }
            auction.ItemSellFrame, auction.CommoditiesSellFrame = sell, CreateFrame("Frame")
            auction.CommoditiesSellFrame:Hide()
            auction.SetPostItem = function() end
            _G.AuctionHouseFrame = auction
            hooksecurefunc = function(object, method, callback)
                local original = object[method]
                object[method] = function(self, ...) local result = original(self, ...); callback(); return result end
            end
            C_Item.GetItemID = function(item) return type(item) == "table" and item.itemID or item end
            local full = { itemID = 777, itemLevel = 16, itemSuffix = 12733 }
            local listed = true
            C_AuctionHouse = {
                MakeItemKey = function(id) return { itemID = id } end,
                GetItemKeyFromItem = function() return full end,
                GetNumItemSearchResults = function(key) return (listed and key == full) and 1 or 0 end,
                GetItemSearchResultInfo = function(key, index)
                    if key == full and index == 1 then return { buyoutAmount = 923, quantity = 1, containsOwnerItem = false } end
                end,
            }
            GoldPilotDB = {}
            addon.Valuation.value = function() return { ref = { price = 40, class = "OBS" } } end
            addon.Modules:enableAll()
            mock.fire("AUCTION_HOUSE_SHOW")
            display:SetItem({ itemID = 777 })
            mock.flushTimers()
            local panel = addon.SellAssist.frame
            assert(addon.SellAssist.suggestion and addon.SellAssist.suggestion.price == 922)
            assert(panel.rows[2].value:GetText() == addon.Theme.money(923))
            assert(GoldPilotDB.diag.venta.minimo == 923 and GoldPilotDB.diag.venta.referencia == 40)
            listed = false
            mock.fire("ITEM_SEARCH_RESULTS_UPDATED", full)
            assert(addon.SellAssist.suggestion == nil, "sin precio en vivo no hay sugerencia")
            assert(panel.useButton.enabled == false)
            assert(panel.warning:GetText() == addon.L.SELL_WARN_NOLIVE)
            mock.fire("AUCTION_HOUSE_CLOSED")
        end)
        _G.AuctionHouseFrame, hooksecurefunc, C_AuctionHouse = old.auction, old.hook, old.api
        C_Item.GetItemID, addon.Valuation.value, GoldPilotDB = old.getID, old.value, old.db
        assert(ok, err)
    end,
}
