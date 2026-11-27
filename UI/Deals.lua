local _, addon = ...

local DealsUI = { owner = "deals", cacheTime = 0, active = false }
addon.DealsUI = DealsUI

local WIDTH, ROW_HEIGHT, MAX_REQUESTS = 400, 20, 50
local GREEN, GOLD, PALE, GRAY, RED = { 0.4, 0.9, 0.4 }, { 0.9, 0.72, 0.29 }, { 0.92, 0.82, 0.55 }, { 0.65, 0.65, 0.65 }, { 1, 0.3, 0.25 }

local function call(object, method, ...)
    if not object or type(object[method]) ~= "function" then return nil end
    local ok, value = pcall(object[method], object, ...)
    if ok then return value end
end
local function shown(object) return object and call(object, "IsShown") == true end
local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function api(path, ...) local ok, a = addon.Compat.call(path, ...); if ok then return a end end

local function label(parent, width, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetFont("Fonts/FRIZQT__.TTF", 10, "")
    text:SetWordWrap(false)
    if width then text:SetWidth(width) end
    if justify then text:SetJustifyH(justify) end
    return text
end

local function createPanel(parent)
    if DealsUI.frame or not parent or inCombat() then return DealsUI.frame end
    local panel = addon.Widgets.sidePanel(parent, addon.L.DEALS_TITLE, WIDTH)
    if not panel then return nil end
    panel.age = label(panel)
    panel.age:SetTextColor(unpack(GRAY))
    panel.checkbox = addon.Widgets.smallCheckbox(panel, addon.L.DEALS_SMALL, addon.Settings.get("dealsSmall"), function(value)
        addon.Settings.set("dealsSmall", value)
    end)
    panel.live = label(panel, WIDTH - 16)
    panel.live:SetWordWrap(true)
    panel.sections = {}
    for _, kind in ipairs({ "resale", "vendor" }) do
        local section = { kind = kind, rows = {} }
        section.title = label(panel)
        section.title:SetTextColor(unpack(GOLD))
        section.columns = { label(panel, 74, "RIGHT"), label(panel, 74, "RIGHT"), label(panel, 78, "RIGHT") }
        section.empty = label(panel)
        section.empty:SetTextColor(unpack(GRAY))
        for i = 1, 6 do
            local row = { name = label(panel, 150, "LEFT"), price = label(panel, 74, "RIGHT"), max = label(panel, 74, "RIGHT"), profit = label(panel, 78, "RIGHT") }
            row.button = addon.Widgets.frame("Button", nil, panel)
            row.button:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
            section.rows[i] = row
        end
        panel.sections[kind] = section
    end
    panel.stale = label(panel)
    panel.stale:SetTextColor(unpack(GRAY))
    panel.hint = label(panel, WIDTH - 16)
    panel.hint:SetWordWrap(true)
    panel.hint:SetTextColor(unpack(GRAY))
    panel:Hide(); DealsUI.frame = panel
    return panel
end

local function buyVisible(auction)
    if not shown(auction) or shown(auction.AuctionsFrame) or shown(auction.CommoditiesSellFrame) or shown(auction.ItemSellFrame) then return false end
    return shown(auction.BrowseResultsFrame) or shown(auction.CommoditiesBuyFrame) or shown(auction.ItemBuyFrame)
end

-- Pedir el precio de vendedor de un objeto sin cargar lanza una consulta al servidor: con miles a la vez
-- puede cortar la conexión, así que se piden pocos en cada cálculo.
local function vendorPrice(id, budget)
    if addon.Compat.has("C_Item.IsItemDataCachedByID") and not api("C_Item.IsItemDataCachedByID", id) then
        if budget.left > 0 then
            budget.left = budget.left - 1
            addon.Compat.call("C_Item.RequestLoadItemDataByID", id)
        end
        return nil
    end
    local vendor = addon.Valuation.vendor(id)
    return vendor and vendor.price
end

local function compute(now)
    local db, houseKey = GoldPilotDB or {}, addon.AuctionHouse.houseKey()
    local house = db.prices and db.prices[houseKey] or {}
    local items, latest, fresh = {}, nil, false
    local budget = { left = MAX_REQUESTS }
    for key in pairs(house) do
        if type(key) == "number" then
            local price = addon.Prices.get(db, houseKey, key)
            if price and price.t and now - price.t <= addon.Deals.defaults.maxAge then
                fresh = true
                latest = math.max(latest or 0, price.t)
                local history = addon.Prices.history(db, houseKey, key)
                items[#items + 1] = { itemID = key, min = price.min, p50 = price.p50, qty = price.qty,
                    t = price.t, history = history.daily, vendor = vendorPrice(key, budget) }
            end
        end
    end
    return addon.Deals.find(items, { now = now, small = addon.Settings.get("dealsSmall") }), latest, fresh
end

local function itemName(id)
    local ok, key = addon.Compat.call("C_AuctionHouse.MakeItemKey", id)
    if not ok or not key then return nil, nil end
    local info = api("C_AuctionHouse.GetItemKeyInfo", key)
    if type(info) == "table" and type(info.itemName) == "string" then return info.itemName, key end
    addon.Compat.call("C_Item.RequestLoadItemDataByID", id)
    return nil, key
end

local OPEN_OWNER, OPEN_RETRIES = "deals-open", 12

-- SelectBrowseResult solo enseña la ficha del objeto: los precios hay que pedirlos aparte.
local function requestPrices(key, attempt)
    local ok, ready = addon.Compat.call("C_AuctionHouse.IsThrottledMessageSystemReady")
    if ok and ready == false and attempt < OPEN_RETRIES then
        addon.Timer.after(0.25, function() requestPrices(key, attempt + 1) end, OPEN_OWNER)
        return
    end
    addon.Compat.call("C_AuctionHouse.SendSearchQuery", key, {}, false)
end

local function searchByName(auction, name)
    local bar = auction.SearchBar
    if not (name and bar and bar.SearchBox and type(bar.SearchBox.SetText) == "function") then return end
    pcall(bar.SearchBox.SetText, bar.SearchBox, name)
    local button = bar.SearchButton
    if not (button and type(button.Click) == "function" and pcall(button.Click, button)) then
        addon.Log:info(addon.L.DEALS_SEARCH)
    end
end

local function openItem(row, attempt)
    if inCombat() then return end
    local auction = _G and _G.AuctionHouseFrame
    if not shown(auction) then return end
    local name, key = itemName(row.itemID)
    -- Sin los datos del objeto cargados no se puede abrir ni buscar: se espera a que lleguen.
    if not name then
        if attempt < OPEN_RETRIES then
            addon.Timer.after(0.25, function() openItem(row, attempt + 1) end, OPEN_OWNER)
        end
        return
    end
    DealsUI.opened = { deal = row, key = key, itemID = row.itemID, wasVisible = false }
    if type(auction.SelectBrowseResult) == "function"
        and pcall(auction.SelectBrowseResult, auction, { itemKey = key }) then
        requestPrices(key, 0)
    else
        searchByName(auction, name)
    end
end

local function setPoint(widget, x, y)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", DealsUI.frame, "TOPLEFT", x, y)
end

local function render()
    if inCombat() then return end
    local auction = _G and _G.AuctionHouseFrame
    local panel = createPanel(auction)
    local opened = DealsUI.opened
    local buysVisible = shown(auction and auction.CommoditiesBuyFrame) or shown(auction and auction.ItemBuyFrame)
    if opened and buysVisible then opened.wasVisible = true end
    if opened and opened.wasVisible and not buysVisible then DealsUI.opened, DealsUI.live, opened = nil, nil, nil end
    if not panel or not buyVisible(auction) or addon.Settings.get("deals") == false then
        if DealsUI.frame then DealsUI.frame:Hide() end
        DealsUI.active = false
        return
    end
    local rows = DealsUI.results or { resale = {}, vendor = {} }
    local now = time()
    panel.age:SetText(DealsUI.latest and string.format(addon.L.DEALS_AGE, addon.Theme.age(math.max(0, now - DealsUI.latest))) or "")
    panel.age:ClearAllPoints(); panel.age:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -panel.contentTop); panel.age:Show()
    local y = panel.contentTop + 18
    panel.checkbox:ClearAllPoints(); panel.checkbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -y)
    if panel.checkbox.SetChecked then panel.checkbox:SetChecked(addon.Settings.get("dealsSmall")) end
    panel.checkbox:Show(); panel.checkbox.label:Show()
    y = y + 28
    if DealsUI.live then
        panel.live:ClearAllPoints(); panel.live:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -y)
        panel.live:SetText(DealsUI.live.text); panel.live:SetTextColor(unpack(DealsUI.live.color)); panel.live:Show()
        y = y + (DealsUI.live.height or 32)
    else panel.live:Hide() end
    if not DealsUI.fresh then
        for _, section in pairs(panel.sections) do
            section.title:Hide(); for _, col in ipairs(section.columns) do col:Hide() end
            section.empty:Hide(); for _, row in ipairs(section.rows) do row.name:Hide(); row.price:Hide(); row.max:Hide(); row.profit:Hide(); row.button:Hide() end
        end
        panel.stale:ClearAllPoints(); panel.stale:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -y)
        panel.stale:SetText(addon.L.DEALS_STALE); panel.stale:Show(); y = y + 24
        panel.hint:Hide()
    else
        panel.stale:Hide()
        for _, kind in ipairs({ "resale", "vendor" }) do
            local section, list = panel.sections[kind], rows[kind] or {}
            section.title:SetText(kind == "resale" and addon.L.DEALS_SECTION_RESALE or addon.L.DEALS_SECTION_VENDOR)
            section.title:ClearAllPoints(); section.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -y); section.title:Show(); y = y + 16
            for index, key in ipairs({ "price", "max", "profit" }) do
                section.columns[index]:SetText(index == 1 and addon.L.DEALS_COL_PRICE or index == 2 and addon.L.DEALS_COL_MAX or addon.L.DEALS_COL_PROFIT)
                section.columns[index]:ClearAllPoints(); section.columns[index]:SetPoint("TOPRIGHT", panel, "TOPLEFT", ({ 238, 312, 392 })[index], -y)
                section.columns[index]:SetTextColor(unpack(GRAY)); section.columns[index]:Show()
            end
            y = y + 16
            if #list == 0 then
                section.empty:ClearAllPoints(); section.empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -y)
                section.empty:SetText(addon.L.DEALS_NONE); section.empty:Show(); y = y + ROW_HEIGHT
                for _, row in ipairs(section.rows) do row.name:Hide(); row.price:Hide(); row.max:Hide(); row.profit:Hide(); row.button:Hide() end
            else
                section.empty:Hide()
                for i, widgets in ipairs(section.rows) do
                    local deal = list[i]
                    if deal then
                        local name = itemName(deal.itemID)
                        local rowY = -y
                        setPoint(widgets.name, 8, rowY); widgets.name:SetText(addon.Widgets.truncate(name or "...", 22)); widgets.name:SetTextColor(unpack(PALE)); widgets.name:Show()
                        setPoint(widgets.price, 160, rowY); widgets.price:SetText(addon.Theme.money(deal.min)); widgets.price:SetTextColor(unpack(PALE)); widgets.price:Show()
                        setPoint(widgets.max, 238, rowY); widgets.max:SetText(addon.Theme.money(deal.maxPay)); widgets.max:SetTextColor(unpack(PALE)); widgets.max:Show()
                        setPoint(widgets.profit, 316, rowY); widgets.profit:SetText(addon.Theme.money(deal.profit)); widgets.profit:SetTextColor(unpack(kind == "resale" and GREEN or GOLD)); widgets.profit:Show()
                        widgets.button:ClearAllPoints(); widgets.button:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, rowY + 2); widgets.button:SetSize(WIDTH - 8, ROW_HEIGHT)
                        widgets.button:SetScript("OnClick", function() addon.Timer.cancelAll(OPEN_OWNER); DealsUI.opened, DealsUI.live = nil, nil; openItem(deal, 0) end); widgets.button:Show()
                        y = y + ROW_HEIGHT
                    else widgets.name:Hide(); widgets.price:Hide(); widgets.max:Hide(); widgets.profit:Hide(); widgets.button:Hide() end
                end
            end
            y = y + 4
        end
        panel.hint:ClearAllPoints(); panel.hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -y)
        panel.hint:SetText(addon.L.DEALS_HINT); panel.hint:Show(); y = y + 32
    end
    panel:SetHeight(y + 8)
    panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", auction, "TOPRIGHT", 4, -30); panel:Show()
    DealsUI.active = true
end

local function recalculate()
    DealsUI.results, DealsUI.latest, DealsUI.fresh = compute(time())
    DealsUI.cacheTime = time()
    render()
end

local function liveResults(itemID, isCommodity, itemKey)
    local listings = {}
    if isCommodity then
        local count = math.min(MAX_REQUESTS, tonumber(api("C_AuctionHouse.GetNumCommoditySearchResults", itemID)) or 0)
        for i = 1, count do
            local info = api("C_AuctionHouse.GetCommoditySearchResultInfo", itemID, i)
            if type(info) == "table" then listings[#listings + 1] = { price = info.unitPrice, qty = info.quantity, own = info.numOwnerItems } end
        end
    else
        local count = math.min(MAX_REQUESTS, tonumber(api("C_AuctionHouse.GetNumItemSearchResults", itemKey)) or 0)
        for i = 1, count do
            local info = api("C_AuctionHouse.GetItemSearchResultInfo", itemKey, i)
            if type(info) == "table" then listings[#listings + 1] = { price = info.buyoutAmount, qty = info.quantity, own = info.containsOwnerItem } end
        end
    end
    return addon.Sell.otherMin(listings)
end

local function updateLive(eventID, eventKey, isCommodity)
    local opened = DealsUI.opened
    if not opened then return end
    local eventItemID = type(eventID) == "table" and eventID.itemID or eventID
    if eventItemID == nil and type(eventKey) == "table" then eventItemID = eventKey.itemID end
    if tonumber(eventItemID) ~= tonumber(opened.itemID) then return end
    local current = liveResults(opened.itemID, isCommodity, opened.key)
    local name = itemName(opened.itemID) or "..."
    if current then
        local result = addon.Deals.check(opened.deal, current)
        local key = result.good and "DEALS_LIVE_GOOD" or "DEALS_LIVE_BAD"
        DealsUI.live = { text = string.format(addon.L[key], name, addon.Theme.money(current), addon.Theme.money(result.gain)),
            color = result.good and GREEN or RED, height = 32 }
    else
        DealsUI.live = { text = string.format(addon.L.DEALS_LIVE_GONE, name), color = RED, height = 32 }
    end
    render()
end

local function poll()
    if inCombat() then return true end
    local auction = _G and _G.AuctionHouseFrame
    local opened = DealsUI.opened
    local buysVisible = shown(auction and auction.CommoditiesBuyFrame) or shown(auction and auction.ItemBuyFrame)
    if opened and buysVisible then opened.wasVisible = true end
    if opened and opened.wasVisible and not buysVisible then DealsUI.opened, DealsUI.live = nil, nil end
    if addon.Settings.get("deals") == false or not buyVisible(auction) then
        if DealsUI.frame then DealsUI.frame:Hide() end
        DealsUI.active = false
        return true
    end
    if not DealsUI.active then
        if time() - DealsUI.cacheTime > 60 then recalculate() else render() end
    end
    return true
end

function DealsUI:start()
    if not self.timer then self.timer = addon.Timer.every(0.5, poll, self.owner) end
end
function DealsUI:refresh()
    self.cacheTime = 0
    if self.active then recalculate() elseif self.frame then render() end
end
function DealsUI:hide()
    if inCombat() then return false end
    addon.Timer.cancelAll(self.owner); addon.Timer.cancelAll(OPEN_OWNER); self.timer = nil; self.active = false
    self.opened, self.live = nil, nil
    if self.frame then self.frame:Hide() end
    return true
end

addon.Modules:register("deals", { onEnable = function()
    addon.Events:subscribe("deals", "AUCTION_HOUSE_SHOW", function() DealsUI:start() end)
    addon.Events:subscribe("deals", "AUCTION_HOUSE_CLOSED", function() DealsUI:hide() end)
    addon.Events:subscribe("deals", "PLAYER_REGEN_ENABLED", poll)
    addon.Events:subscribe("deals", "GOLDPILOT_SCAN_PROGRESS", function(progress)
        if progress ~= nil then return end
        DealsUI.cacheTime = 0
        if DealsUI.active then recalculate() end
    end)
    addon.Events:subscribe("deals", "ITEM_DATA_LOAD_RESULT", function(id)
        if DealsUI.active then for _, kind in ipairs({ "resale", "vendor" }) do for _, row in ipairs((DealsUI.results or {})[kind] or {}) do if row.itemID == id then render(); break end end end end
    end)
    addon.Events:subscribe("deals", "COMMODITY_SEARCH_RESULTS_UPDATED", function(itemID) updateLive(itemID, nil, true) end)
    addon.Events:subscribe("deals", "ITEM_SEARCH_RESULTS_UPDATED", function(itemKey) updateLive(itemKey, itemKey, false) end)
    addon.Events:subscribe("deals", "GOLDPILOT_SETTING_CHANGED", function(key, value)
        if key == "deals" then if value then DealsUI:start() else DealsUI:hide() end
        elseif key == "dealsSmall" and DealsUI.frame then
            if DealsUI.frame.checkbox.SetChecked then DealsUI.frame.checkbox:SetChecked(value == true) end
            if DealsUI.active then render() end
        end
    end)
end })
return DealsUI
