local _, addon = ...

local SellAssist = { hooked = false, owner = "sell-assist" }
addon.SellAssist = SellAssist

local WIDTH = 220
local GOLD = { 0.72, 0.55, 0.2, 0.9 }

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function call(object, method, ...)
    if not object or type(object[method]) ~= "function" then return nil end
    local ok, value = pcall(object[method], object, ...)
    if ok then return value end
end

local function shown(object)
    return object and call(object, "IsShown") == true
end

local function itemID(item)
    if type(item) == "number" then return tonumber(item) end
    if type(item) == "string" then
        return addon.ItemKey.itemID(item) or tonumber(item)
    end
    local ok, id = addon.Compat.call("C_Item.GetItemID", item)
    if ok and tonumber(id) then return tonumber(id) end
    if type(item) == "table" then return tonumber(item.itemID) end
end

local function itemKey(item, id)
    if type(item) == "string" then
        return addon.ItemKey.fromLink(item, true) or tostring(id)
    end
    local link = call(item, "GetItemLink")
    if type(link) == "string" then return addon.ItemKey.fromLink(link, true) or tostring(id) end
    local ok, linkValue = addon.Compat.call("C_Item.GetItemLink", item)
    if ok and type(linkValue) == "string" then return addon.ItemKey.fromLink(linkValue, true) or tostring(id) end
    return tostring(id)
end

local function createPanel(parent)
    if SellAssist.frame or inCombat() or not parent then return SellAssist.frame end
    local frame = addon.Widgets.frame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(WIDTH, 174)
    frame:SetFrameStrata("DIALOG")
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.06, 0.04, 0.96)
    local function edge(first, second, horizontal)
        local texture = frame:CreateTexture(nil, "OVERLAY")
        texture:SetPoint(first, frame, first, 0, 0)
        texture:SetPoint(second, frame, second, 0, 0)
        if horizontal then texture:SetHeight(1) else texture:SetWidth(1) end
        texture:SetColorTexture(unpack(GOLD))
    end
    edge("TOPLEFT", "TOPRIGHT", true)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    edge("TOPLEFT", "BOTTOMLEFT", false)
    edge("TOPRIGHT", "BOTTOMRIGHT", false)
    frame.lines = {}
    for index = 1, 7 do
        local line = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line:SetFont("Fonts/FRIZQT__.TTF", index == 1 and 12 or 11, "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -7 - (index - 1) * 17)
        line:SetWidth(WIDTH - 16)
        line:SetJustifyH("LEFT")
        frame.lines[index] = line
    end
    frame.useButton = addon.Widgets.frame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.useButton:SetSize(WIDTH - 16, 24)
    frame.useButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 7)
    frame.useButton:SetText(addon.L.SELL_USE)
    frame.useButton:SetScript("OnClick", function()
        if inCombat() or not SellAssist.suggestion or not SellAssist.sellFrame then return end
        local input = SellAssist.sellFrame.PriceInput
        if input and type(input.SetAmount) == "function" then pcall(input.SetAmount, input, SellAssist.suggestion.price) end
    end)
    frame:Hide()
    SellAssist.frame = frame
    return frame
end

local function visibleSellFrame(auction)
    for _, name in ipairs({ "CommoditiesSellFrame", "ItemSellFrame" }) do
        local sellFrame = auction and auction[name]
        if shown(sellFrame) then return sellFrame, name == "CommoditiesSellFrame" end
    end
end

local function currentItem(sellFrame)
    local display = sellFrame and sellFrame.ItemDisplay
    local item = call(display, "GetItem")
    local id = itemID(item)
    if not id and display then id = itemID(call(display, "GetItemID")) end
    if not id then return nil end
    return item, id, itemKey(item, id)
end

local function readOtherMin(id, key, commodity)
    local listings = {}
    local countOK, count
    if commodity then countOK, count = addon.Compat.call("C_AuctionHouse.GetNumCommoditySearchResults", id)
    else
        local ok, auctionKey = addon.Compat.call("C_AuctionHouse.MakeItemKey", id)
        countOK, count = addon.Compat.call("C_AuctionHouse.GetNumItemSearchResults", ok and auctionKey or key)
    end
    if not countOK then return nil end
    count = math.min(50, math.max(0, tonumber(count) or 0))
    for index = 1, count do
        local ok, info
        if commodity then ok, info = addon.Compat.call("C_AuctionHouse.GetCommoditySearchResultInfo", id, index)
        else
            local _, auctionKey = addon.Compat.call("C_AuctionHouse.MakeItemKey", id)
            ok, info = addon.Compat.call("C_AuctionHouse.GetItemSearchResultInfo", auctionKey or key, index)
        end
        if ok and type(info) == "table" then
            if commodity then
                listings[#listings + 1] = { price = info.unitPrice, qty = info.quantity, own = info.numOwnerItems or 0 }
            else
                listings[#listings + 1] = { price = info.buyoutAmount, qty = info.quantity or 1, own = info.containsOwnerItem == true }
            end
        end
    end
    return addon.Sell.otherMin(listings)
end

local function deposit(item, id, commodity, duration, quantity)
    local path = commodity and "C_AuctionHouse.CalculateCommodityDeposit" or "C_AuctionHouse.CalculateItemDeposit"
    local argument = item
    if commodity then argument = id end
    local ok, value = addon.Compat.call(path, argument, duration, quantity)
    if ok and tonumber(value) then return tonumber(value) end
end

local function render(frame, value, minPrice, suggestion, depositValue)
    local function money(amount) return addon.Theme.money(amount) end
    frame.lines[1]:SetText(addon.L.SELL_TITLE)
    frame.lines[2]:SetText(value.ref
        and string.format(addon.L.SELL_REF, money(value.ref.price), addon.Theme.badge(value.ref.class))
        or addon.L.SELL_NO_REF)
    frame.lines[3]:SetText(minPrice and string.format(addon.L.SELL_MIN, money(minPrice)) or addon.L.SELL_NO_MIN)
    frame.lines[4]:SetText(suggestion and string.format(addon.L.SELL_SUGGESTED, money(suggestion.price)) or addon.L.SELL_NO_DATA)
    frame.lines[5]:SetText(suggestion and string.format(addon.L.SELL_NET, money(suggestion.net)) or "")
    frame.lines[6]:SetText(depositValue and string.format(addon.L.SELL_DEPOSIT, money(depositValue)) or "")
    local warning = suggestion and suggestion.warning
    frame.lines[7]:SetText(warning == "vendor" and addon.L.SELL_WARN_VENDOR or warning == "crashed" and addon.L.SELL_WARN_CRASHED or "")
    if frame.lines[4].SetTextColor then frame.lines[4]:SetTextColor(1, 0.82, 0.2) end
    if frame.lines[7].SetTextColor then
        if warning then frame.lines[7]:SetTextColor(1, 0.35, 0.2) else frame.lines[7]:SetTextColor(0.92, 0.86, 0.72) end
    end
    frame.useButton:SetEnabled(suggestion ~= nil)
end

function SellAssist:hide()
    if inCombat() then return false end
    addon.Timer.cancelAll(self.owner)
    self.timer = nil
    self.active = false
    if self.frame then self.frame:Hide() end
    return true
end

local function update()
    if inCombat() then return false end
    if addon.Settings.get("sellAssist") == false then SellAssist:hide(); return false end
    local auction = _G and _G.AuctionHouseFrame
    if not shown(auction) then SellAssist:hide(); return false end
    local sellFrame, commodity = visibleSellFrame(auction)
    if not sellFrame then SellAssist:hide(); return false end
    local item, id, key = currentItem(sellFrame)
    if not item or not id then SellAssist:hide(); return false end
    local parent = auction
    local frame = createPanel(parent)
    if not frame then return false end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", sellFrame, "TOPRIGHT", 4, 0)
    local quantity = tonumber(call(sellFrame.QuantityInput, "GetQuantity")) or 1
    quantity = math.max(1, quantity)
    local duration = call(sellFrame.Duration, "GetDuration")
    local depositValue = deposit(item, id, commodity, duration, quantity)
    local db = GoldPilotDB or {}
    local value = addon.Valuation.value(db, addon.AuctionHouse:houseKey(), key, time())
    local minPrice = readOtherMin(id, key, commodity)
    local suggestion = addon.Sell.suggest({ min = minPrice, ref = value.ref and value.ref.price,
        refClass = value.ref and value.ref.class, vendor = value.vendor and value.vendor.price,
        quantity = quantity, deposit = depositValue })
    SellAssist.sellFrame, SellAssist.item, SellAssist.itemID, SellAssist.commodity = sellFrame, item, id, commodity
    SellAssist.suggestion = suggestion
    SellAssist.active = true
    SellAssist.lastQuantity, SellAssist.lastDuration = quantity, duration
    render(frame, value, minPrice, suggestion, depositValue)
    frame:Show()
    if not SellAssist.timer then
        SellAssist.timer = addon.Timer.every(0.5, function()
            if inCombat() then return true end
            local liveAuction = _G and _G.AuctionHouseFrame
            if addon.Settings.get("sellAssist") == false or not shown(liveAuction) then
                SellAssist:hide()
                return false
            end
            local currentSell = visibleSellFrame(liveAuction)
            if not currentSell then SellAssist:hide(); SellAssist.timer = nil; return false end
            local q = tonumber(call(currentSell.QuantityInput, "GetQuantity")) or 1
            local d = call(currentSell.Duration, "GetDuration")
            if currentSell ~= SellAssist.sellFrame or q ~= SellAssist.lastQuantity or d ~= SellAssist.lastDuration then update() end
            return true
        end, SellAssist.owner)
    end
    return true
end

local function onCommodityResults(id)
    if SellAssist.active and SellAssist.commodity and tonumber(id) == SellAssist.itemID then update() end
end

local function onItemResults(key)
    local id = type(key) == "table" and tonumber(key.itemID) or tonumber(key)
    if SellAssist.active and not SellAssist.commodity and id == SellAssist.itemID then update() end
end

local function hookAuction()
    if inCombat() or SellAssist.hooked then return end
    local auction = _G and _G.AuctionHouseFrame
    if not auction then return end
    SellAssist.hooked = true
    -- SetPostItem salta antes de que Blizzard muestre el panel de venta: se espera a que esté visible.
    local function deferred() addon.Timer.after(0.1, update, "sell-assist-hook") end
    for _, name in ipairs({ "CommoditiesSellFrame", "ItemSellFrame" }) do
        local display = auction[name] and auction[name].ItemDisplay
        if display and type(display.SetItem) == "function" then
            pcall(hooksecurefunc, display, "SetItem", deferred)
        end
    end
    if type(auction.SetPostItem) == "function" then pcall(hooksecurefunc, auction, "SetPostItem", deferred) end
end

addon.Modules:register("sell-assist", {
    onEnable = function()
        addon.Events:subscribe("sell-assist", "AUCTION_HOUSE_SHOW", function()
            if inCombat() then return end
            hookAuction()
            update()
        end)
        addon.Events:subscribe("sell-assist", "PLAYER_REGEN_ENABLED", function()
            hookAuction()
            update()
        end)
        addon.Events:subscribe("sell-assist", "AUCTION_HOUSE_CLOSED", function() SellAssist:hide() end)
        addon.Events:subscribe("sell-assist", "COMMODITY_SEARCH_RESULTS_UPDATED", onCommodityResults)
        addon.Events:subscribe("sell-assist", "ITEM_SEARCH_RESULTS_UPDATED", onItemResults)
    end,
})

return SellAssist
