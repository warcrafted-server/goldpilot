return {
    ["shopping validates, updates, sorts and evaluates observations"] = function(addon)
        local db = {}
        assert(not addon.Shopping.add(db, 0, 10))
        assert(not addon.Shopping.add(db, 1, 0))
        assert(addon.Shopping.add(db, 9, 200) and addon.Shopping.add(db, 3, 100))
        assert(addon.Shopping.add(db, 9, 250))
        assert(addon.Shopping.get(db, 9).max == 250)
        local list = addon.Shopping.list(db)
        assert(#list == 2 and list[1].itemID == 3 and list[2].itemID == 9)
        assert(addon.Shopping.evaluate({ max = 100 }, { min = 90, t = 1000 }, 1000).state == "buy")
        assert(addon.Shopping.evaluate({ max = 100 }, { min = 110, t = 1000 }, 1000).state == "wait")
        assert(addon.Shopping.evaluate({ max = 100 }, { min = 90, t = 1 }, 5000).state == "unknown")
        assert(addon.Shopping.remove(db, 3) and not addon.Shopping.get(db, 3))
    end,
    ["shopping UI saves copper, preserves edits, marks and removes items, alerts once and never buys"] = function(addon, mock)
        local oldAuction, oldApi, oldDB, oldCharDB = _G.AuctionHouseFrame, C_AuctionHouse, GoldPilotDB, GoldPilotCharDB
        local auction, buy = CreateFrame("Frame"), CreateFrame("Frame")
        buy:Show(); auction.CommoditiesBuyFrame = buy
        auction.SelectBrowseResult = function(self, value) self.selected = value end
        _G.AuctionHouseFrame = auction
        local bought = 0
        C_AuctionHouse = {
            MakeItemKey = function(id) return { itemID = id } end,
            GetItemKeyInfo = function(key) return { itemName = "Item " .. key.itemID, isCommodity = true } end,
            PlaceBid = function() bought = bought + 1 end,
            StartCommoditiesPurchase = function() bought = bought + 1 end,
            ConfirmCommoditiesPurchase = function() bought = bought + 1 end,
        }
        local house = addon.AuctionHouse.houseKey()
        GoldPilotDB = { shopping = { [77] = { itemID = 77, max = 12345 } }, prices = { [house] = { [77] = "199999:12000:12000:1||" } } }
        GoldPilotCharDB = { dealsView = "list" }
        addon.Modules:enableAll(); mock.fire("AUCTION_HOUSE_SHOW"); mock.flushTimers()
        local panel = addon.DealsUI.frame
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 77)
        assert(addon.DealsUI.activeItem == 77, "el resultado activo debe identificar el objeto abierto")
        assert(panel.editor and panel.editor.itemID == 77 and panel.editor.boxes[1]:GetText() == "1", table.concat(mock.output, " | "))
        panel.editor.boxes[3]:SetText("9")
        panel.editor.boxes[3].scripts.OnTextChanged(panel.editor.boxes[3])
        mock.fire("COMMODITY_SEARCH_RESULTS_UPDATED", 77)
        assert(panel.editor.boxes[3]:GetText() == "9", "el redibujado conserva lo escrito")
        panel.editor.action.scripts.OnClick()
        assert(GoldPilotDB.shopping[77].max == 12309)
        assert(#panel.shopping.rows > 0 and panel.shopping.rows[1].now.color[2] > 0.8)
        panel.viewDeals.scripts.OnClick(panel.viewDeals)
        assert(panel.shopping.rows[1].name.hidden and not panel.checkbox.hidden)
        panel.viewList.scripts.OnClick(panel.viewList)
        assert(not panel.shopping.rows[1].name.hidden and panel.checkbox.hidden)
        local function alertCount()
            local count = 0
            for _, line in ipairs(mock.output) do if line:find("My list: Item 77", 1, true) then count = count + 1 end end
            return count
        end
        assert(alertCount() == 1, "avisa al abrir con un precio fresco")
        mock.fire("GOLDPILOT_SCAN_PROGRESS", nil)
        assert(alertCount() == 1, "debe salir un aviso por objeto y apertura")
        panel.shopping.rows[1].button.scripts.OnClick()
        assert(auction.selected and auction.selected.itemKey.itemID == 77)
        panel.shopping.rows[1].remove.scripts.OnClick(panel.shopping.rows[1].remove)
        assert(not addon.Shopping.get(GoldPilotDB, 77))
        assert(bought == 0)
        addon.Shopping.add(GoldPilotDB, 77, 12345)
        mock.fire("AUCTION_HOUSE_CLOSED"); mock.fire("AUCTION_HOUSE_SHOW"); mock.flushTimers()
        assert(alertCount() == 2, "un nuevo uso de la subasta permite volver a avisar")
        GoldPilotDB, GoldPilotCharDB = oldDB, oldCharDB
        _G.AuctionHouseFrame, C_AuctionHouse = oldAuction, oldApi
    end,
}
