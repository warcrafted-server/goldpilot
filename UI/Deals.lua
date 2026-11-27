local _, addon = ...

local DealsUI = { owner = "deals", cacheTime = 0, active = false }
addon.DealsUI = DealsUI

local WIDTH, ROW_HEIGHT = 360, 20
local MAX_REQUESTS = 50
local GREEN, GOLD, PALE, GRAY = { 0.4, 0.9, 0.4 }, { 0.9, 0.72, 0.29 }, { 0.92, 0.82, 0.55 }, { 0.65, 0.65, 0.65 }

local function call(object, method, ...)
    if not object or type(object[method]) ~= "function" then return nil end
    local ok, value = pcall(object[method], object, ...)
    if ok then return value end
end
local function shown(object) return object and call(object, "IsShown") == true end
local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function api(path, ...) local ok, a = addon.Compat.call(path, ...); if ok then return a end end

local function truncate(text)
    text = tostring(text or "?")
    local chars, cut = 0, 0
    for index = 1, #text do
        local byte = string.byte(text, index)
        if byte < 128 or byte >= 192 then
            chars = chars + 1
            if chars == 20 then cut = index end
            if chars == 22 then return string.sub(text, 1, cut) .. "…" end
        end
    end
    return text
end

local function createPanel(parent)
    if DealsUI.frame or not parent or inCombat() then return DealsUI.frame end
    local panel = addon.Widgets.sidePanel(parent, addon.L.DEALS_TITLE, WIDTH)
    if not panel then return nil end
    panel.age = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.age:SetFont("Fonts/FRIZQT__.TTF", 10, ""); panel.age:SetTextColor(unpack(GRAY))
    panel.age:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -panel.contentTop)
    panel.rows = {}
    for index = 1, 10 do
        local name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetFont("Fonts/FRIZQT__.TTF", 10, ""); name:SetWidth(150); name:SetJustifyH("LEFT"); name:SetWordWrap(false)
        local price = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        price:SetFont("Fonts/FRIZQT__.TTF", 10, ""); price:SetWidth(72); price:SetJustifyH("RIGHT"); price:SetWordWrap(false)
        local profit = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        profit:SetFont("Fonts/FRIZQT__.TTF", 10, ""); profit:SetWidth(112); profit:SetJustifyH("RIGHT"); profit:SetWordWrap(false)
        local button = addon.Widgets.frame("Button", nil, panel)
        button:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
        panel.rows[index] = { name = name, price = price, profit = profit, button = button }
    end
    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.empty:SetFont("Fonts/FRIZQT__.TTF", 10, ""); panel.empty:SetTextColor(unpack(GRAY))
    panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.hint:SetFont("Fonts/FRIZQT__.TTF", 10, ""); panel.hint:SetWidth(WIDTH - 16); panel.hint:SetWordWrap(true); panel.hint:SetTextColor(unpack(GRAY))
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
    return addon.Deals.find(items, { now = now }), latest, fresh
end

local function itemName(id)
    local ok, key = addon.Compat.call("C_AuctionHouse.MakeItemKey", id)
    if not ok or not key then return nil, nil end
    local info = api("C_AuctionHouse.GetItemKeyInfo", key)
    if type(info) == "table" and type(info.itemName) == "string" then return info.itemName, key end
    addon.Compat.call("C_Item.RequestLoadItemDataByID", id)
    return nil, key
end

local function openItem(row)
    if inCombat() then return end
    local auction = _G and _G.AuctionHouseFrame
    if not auction then return end
    local name, key = itemName(row.itemID)
    local info = key and api("C_AuctionHouse.GetItemKeyInfo", key)
    if info and type(auction.SelectBrowseResult) == "function" then
        local ok = pcall(auction.SelectBrowseResult, auction, { itemKey = key })
        if ok then return end
    end
    if name and auction.SearchBar and auction.SearchBar.SearchBox and type(auction.SearchBar.SearchBox.SetText) == "function" then
        pcall(auction.SearchBar.SearchBox.SetText, auction.SearchBar.SearchBox, name)
        addon.Log:info(addon.L.DEALS_SEARCH)
    end
end

local function render()
    if inCombat() then return end
    local auction = _G and _G.AuctionHouseFrame
    local panel = createPanel(auction)
    if not panel or not buyVisible(auction) or addon.Settings.get("deals") == false then
        if DealsUI.frame then DealsUI.frame:Hide() end
        DealsUI.active = false
        return
    end
    local rows = DealsUI.results or {}
    local now, count = time(), #rows
    panel.age:ClearAllPoints(); panel.age:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -panel.contentTop)
    panel.age:SetText(DealsUI.latest and string.format(addon.L.DEALS_AGE, addon.Theme.age(math.max(0, now - DealsUI.latest))) or "")
    panel.age:Show()
    for index, widgets in ipairs(panel.rows) do
        local deal = rows[index]
        if deal then
            local name = itemName(deal.itemID)
            local y = -(panel.contentTop + 18) - (index - 1) * ROW_HEIGHT
            widgets.name:ClearAllPoints(); widgets.name:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
            widgets.name:SetText(truncate(name or "...")); widgets.name:SetTextColor(unpack(PALE)); widgets.name:Show()
            widgets.price:ClearAllPoints(); widgets.price:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, y)
            widgets.price:SetText(addon.Theme.money(deal.min)); widgets.price:SetTextColor(unpack(PALE)); widgets.price:Show()
            widgets.profit:ClearAllPoints(); widgets.profit:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, y)
            local text = string.format(addon.L.DEALS_PROFIT, addon.Theme.money(deal.profit))
            if deal.kind == "resale" then text = text .. string.format(" -%d %%", deal.percent) end
            widgets.profit:SetText(text); widgets.profit:SetTextColor(unpack(deal.kind == "vendor" and GOLD or GREEN)); widgets.profit:Show()
            widgets.button:ClearAllPoints(); widgets.button:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, y + 2); widgets.button:SetSize(WIDTH - 8, ROW_HEIGHT)
            widgets.button:SetScript("OnClick", function() openItem(deal) end); widgets.button:Show()
        else
            widgets.name:Hide(); widgets.price:Hide(); widgets.profit:Hide(); widgets.button:Hide()
        end
    end
    if count == 0 then
        panel.empty:ClearAllPoints(); panel.empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -(panel.contentTop + 22))
        panel.empty:SetText(DealsUI.fresh and addon.L.DEALS_EMPTY or addon.L.DEALS_STALE); panel.empty:Show()
    else panel.empty:Hide() end
    panel.hint:ClearAllPoints(); panel.hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -(panel.contentTop + 20 + count * ROW_HEIGHT + (count == 0 and 20 or 0)))
    panel.hint:SetText(addon.L.DEALS_HINT); panel.hint:Show()
    panel:SetHeight(panel.contentTop + 20 + count * ROW_HEIGHT + (count == 0 and 60 or 34))
    panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", auction, "TOPRIGHT", 4, -30); panel:Show()
    DealsUI.active = true
end

local function recalculate()
    DealsUI.results, DealsUI.latest, DealsUI.fresh = compute(time())
    DealsUI.cacheTime = time()
    render()
end

local function poll()
    if inCombat() then return true end
    local auction = _G and _G.AuctionHouseFrame
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
function DealsUI:hide()
    if inCombat() then return false end
    addon.Timer.cancelAll(self.owner); self.timer = nil; self.active = false
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
        if DealsUI.active then for _, row in ipairs(DealsUI.results or {}) do if row.itemID == id then render(); break end end end
    end)
    addon.Events:subscribe("deals", "GOLDPILOT_SETTING_CHANGED", function(key, value)
        if key == "deals" then if value then DealsUI:start() else DealsUI:hide() end end
    end)
end })
return DealsUI
