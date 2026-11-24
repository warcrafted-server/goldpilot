local _, addon = ...

local NowUI = {}
addon.NowUI = NowUI

local COLORS = {
    auction = { 0.35, 0.9, 0.4 }, vendor = { 1, 0.8, 0.25 }, mail = { 0.4, 0.75, 1 },
    elsewhere = { 0.75, 0.55, 1 }, trend_up = { 0.35, 0.9, 0.4 },
    trend_down = { 0.9, 0.45, 0.35 }, refresh = { 0.6, 0.6, 0.6 },
}
local ICONS = {
    auction = "INV_Misc_Coin_01", vendor = "INV_Misc_Bag_10", mail = "INV_Letter_15",
    elsewhere = "INV_Box_01", trend_up = "Spell_ChargePositive",
    trend_down = "Spell_ChargeNegative", refresh = "INV_Misc_Note_01",
}

local function combat()
    return InCombatLockdown and InCombatLockdown()
end

local function visible()
    return addon.Main and addon.Main.frame and addon.Main.frame.IsShown and addon.Main.frame:IsShown()
end

local function currentTime()
    local ok, value = addon.Compat.call("time")
    return ok and tonumber(value) or 0
end

local function confidence(value)
    if value >= 0.75 then return addon.L.NOW_HIGH end
    if value >= 0.5 then return addon.L.NOW_MEDIUM end
    return addon.L.NOW_LOW
end

local function cardKey(card)
    return table.concat({ tostring(card.id or card.kind), tostring(card.char or ""), tostring(card.where or "") }, "|")
end

local function amount(card)
    if card.id == "refresh" or ((card.id == "mail" or card.id == "mail_other") and (card.gain or 0) <= 0) then
        return ""
    end
    local value = addon.Theme.money(math.abs(card.gain or 0))
    if card.id == "trend_up" or card.id == "trend_down" then
        return (card.gain < 0 and "-" or "+") .. value
    end
    return "+" .. value
end

local function title(card)
    local L, id = addon.L, card.id
    if id == "auction" then return string.format(card.count == 1 and L.NOW_AUCTION_ONE or L.NOW_AUCTION, card.count) end
    if id == "vendor" then return string.format(card.count == 1 and L.NOW_VENDOR_ONE or L.NOW_VENDOR, card.count) end
    if id == "mail" then return L.NOW_MAIL end
    if id == "mail_other" then return string.format(L.NOW_MAIL_OTHER, card.char or "unknown") end
    if id == "elsewhere" then
        return string.format(card.where == "bank" and L.NOW_ELSEWHERE_BANK or L.NOW_ELSEWHERE_BAGS, card.char or "unknown")
    end
    if id == "trend_up" then return L.NOW_TREND_UP end
    if id == "trend_down" then return L.NOW_TREND_DOWN end
    return L.NOW_REFRESH
end

local function reason(card, current)
    local L = addon.L
    local id = card.id
    if id == "auction" then return card.crowded and L.NOW_REASON_CROWDED or L.NOW_REASON_AUCTION end
    if id == "vendor" then return L.NOW_REASON_VENDOR end
    if id == "mail" or id == "mail_other" then
        if card.count == 0 then return L.NOW_REASON_MAIL_GOLD end
        if card.gain > 0 then
            return string.format(card.count == 1 and L.NOW_REASON_MAIL_BOTH_ONE or L.NOW_REASON_MAIL_BOTH, card.count)
        end
        return string.format(card.count == 1 and L.NOW_REASON_MAIL_ITEMS_ONE or L.NOW_REASON_MAIL_ITEMS, card.count)
    end
    if id == "elsewhere" then
        if not card.seen or card.seen == 0 then
            return string.format(card.count == 1 and L.NOW_REASON_ELSEWHERE_ONE or L.NOW_REASON_ELSEWHERE, card.count)
        end
        return string.format(card.count == 1 and L.NOW_REASON_ELSEWHERE_SEEN_ONE or L.NOW_REASON_ELSEWHERE_SEEN,
            card.count, addon.Theme.age(current - card.seen))
    end
    if id == "trend_up" or id == "trend_down" then
        return string.format(card.count == 1 and L.NOW_REASON_TREND_ONE or L.NOW_REASON_TREND,
            card.count, addon.Advice.defaults.trendPercent)
    end
    return string.format(card.count == 1 and L.NOW_REASON_REFRESH_ONE or L.NOW_REASON_REFRESH, card.count)
end

local function detail(card, current)
    local L, lines = addon.L, {}
    lines[#lines + 1] = { text = title(card), size = 14, color = { 1, 0.82, 0.2 } }
    if card.id ~= "refresh" then
        local value = amount(card)
        local trust = confidence(card.confidence or 0)
        if value ~= "" or trust ~= "" then lines[#lines + 1] = { text = value, right = trust, size = 12 } end
    end
    lines[#lines + 1] = { text = L.NOW_WHY, size = 11, color = { 0.55, 0.5, 0.42 }, gap = 10 }
    local why
    if card.id == "auction" then
        why = L.NOW_WHY_AUCTION
        if card.crowded then why = why .. " " .. L.NOW_WHY_CROWDED end
    elseif card.id == "vendor" then
        why = L.NOW_WHY_VENDOR
    elseif card.id == "mail" or card.id == "mail_other" then
        if card.seen and card.seen > 0 then
            why = string.format(L.NOW_WHY_MAIL, addon.Theme.age(current - card.seen))
        else
            why = card.id == "mail_other" and string.format(L.NOW_WHY_MAIL_OTHER, card.char or "unknown") or L.NOW_WHY_MAIL_NEVER
        end
    elseif card.id == "elsewhere" then
        local place = L[card.where == "bank" and "NOW_PLACE_BANK" or "NOW_PLACE_BAGS"]
        if card.seen and card.seen > 0 then
            why = string.format(L.NOW_WHY_ELSEWHERE, card.char or "unknown", place, addon.Theme.age(current - card.seen))
        else
            why = string.format(L.NOW_WHY_ELSEWHERE_NEVER, card.char or "unknown", place)
        end
    elseif card.id == "trend_up" or card.id == "trend_down" then
        why = L.NOW_WHY_TREND
    else
        why = L.NOW_WHY_REFRESH
    end
    lines[#lines + 1] = { text = why, size = 11 }
    if card.items and #card.items > 0 then
        lines[#lines + 1] = { text = L.NOW_TOP, size = 11, color = { 0.55, 0.5, 0.42 }, gap = 10 }
        for _, item in ipairs(card.items) do
            local name = addon.InventoryUI.itemName(item.itemID, item.key)
            local right
            if card.id == "trend_up" or card.id == "trend_down" then
                right = (item.percent < 0 and "-" or "+") .. tostring(math.abs(item.percent)) .. "%"
            else
                right = addon.Theme.money(math.abs(item.value or 0))
            end
            lines[#lines + 1] = { text = name .. " ×" .. tostring(item.qty), right = right, size = 11 }
        end
        if card.count > #card.items and card.id ~= "mail" and card.id ~= "mail_other" then
            lines[#lines + 1] = { text = string.format(L.NOW_MORE, card.count - #card.items), size = 11 }
        end
    end
    if card.oldest then lines[#lines + 1] = { text = L.NOW_OLDEST, right = addon.Theme.age(current - card.oldest), size = 11 } end
    return lines
end

function NowUI:refresh()
    if combat() or not visible() or not self.page or addon.Main.activeTab ~= "now" then return false end
    GoldPilotCharDB = GoldPilotCharDB or {}
    if GoldPilotCharDB.nowAccount == nil then GoldPilotCharDB.nowAccount = false end
    self.scopeButton:SetText(GoldPilotCharDB.nowAccount and addon.L.INVENTORY_SCOPE_ACCOUNT
        or addon.L.INVENTORY_SCOPE_CHARACTER)
    local db, current = GoldPilotDB or {}, currentTime()
    local charOk, char = addon.Compat.call("UnitName", "player")
    if not charOk or type(char) ~= "string" then char = "unknown" end
    local function quality(key)
        local link = db.links and db.links[key] or key
        local ok, _, _, itemQuality = addon.Compat.call("C_Item.GetItemInfo", link)
        if not ok then ok, _, _, itemQuality = addon.Compat.call("GetItemInfo", link) end
        return ok and itemQuality or nil
    end
    local built = addon.Advice.build({ db = db, houseKey = addon.AuctionHouse.houseKey(), char = char,
        now = current, quality = quality, account = GoldPilotCharDB.nowAccount })
    local data = {}
    for i, card in ipairs(built.cards or {}) do
        if i > 6 then break end
        local id = card.id == "mail_other" and "mail" or card.id
        data[#data + 1] = { key = cardKey(card), card = card, title = title(card), reason = reason(card, current),
            right = amount(card), rightColor = COLORS[id], confidence = card.id == "refresh" and "" or confidence(card.confidence or 0),
            icon = "Interface/Icons/" .. (ICONS[id] or ICONS.refresh), accent = COLORS[id] }
    end
    local cards = self.widgets.cards
    local chosen
    for _, item in ipairs(data) do
        if item.key == cards.selectedKey then chosen = item; break end
    end
    if not chosen then chosen = data[1] end
    self.selected = chosen
    cards.selectedKey = chosen and chosen.key or nil
    cards:setCards(data)
    if chosen then
        self.widgets.detail:setLines(detail(chosen.card, current))
        local kind = chosen.card.id
        if kind == "auction" or kind == "vendor" or kind == "elsewhere" then self.inventoryButton:Show()
        else self.inventoryButton:Hide() end
    else
        self.widgets.detail:setLines({})
        self.inventoryButton:Hide()
    end
    local totals = built.totals or {}
    self.widgets.metrics:setItems({
        { label = addon.L.NOW_METRIC_TOTAL, value = addon.Theme.money(totals.now or 0), color = { 0.5, 0.88, 0.54 } },
        { label = addon.L.NOW_METRIC_MAIL, value = addon.Theme.money(totals.mail or 0) },
        { label = addon.L.NOW_METRIC_ELSEWHERE, value = addon.Theme.money(totals.elsewhere or 0) },
        { label = addon.L.NOW_METRIC_PRICES,
            value = db.scan and type(db.scan.t) == "number" and type(db.scan.items) == "number"
                and addon.Theme.age(current - db.scan.t) or addon.L.NOW_NEVER },
    })
    if #data == 0 then
        self.page.emptyText:SetText(next(db.prices or {}) == nil and addon.L.NOW_EMPTY_SCAN or addon.L.NOW_EMPTY)
        self.page.emptyText:Show()
    else
        self.page.emptyText:Hide()
    end
    return true
end

function NowUI:build(page)
    if self.page == page and page._nowBuilt then return self:refresh() end
    self.page, page._nowBuilt = page, true
    self.widgets = { cards = addon.Widgets.cards(page, nil, 420), detail = addon.Widgets.detail(page),
        metrics = addon.Widgets.metrics(page, {}) }
    self.widgets.cards:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -76)
    self.widgets.detail:ClearAllPoints()
    self.widgets.detail:SetPoint("TOPLEFT", page, "TOPLEFT", 450, -72)
    self.widgets.detail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -14, 52)
    self.widgets.detail.contentWidth = 272
    self.widgets.metrics:ClearAllPoints()
    self.widgets.metrics:SetPoint("TOPLEFT", page, "TOPLEFT", 76, -12)
    self.widgets.metrics.contentWidth = 668
    page.emptyText = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    page.emptyText:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -190)
    if page.emptyText.SetWidth then page.emptyText:SetWidth(400) end
    page.emptyText:SetText(addon.L.NOW_EMPTY)
    page.emptyText:Hide()
    self.inventoryButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    self.inventoryButton:SetSize(150, 24)
    self.inventoryButton:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 458, 20)
    self.inventoryButton:SetText(addon.L.NOW_VIEW_INVENTORY)
    self.inventoryButton:SetScript("OnClick", function()
        if combat() then return end
        local card = self.selected and self.selected.card
        local ok, current = addon.Compat.call("UnitName", "player")
        addon.InventoryUI.account = card and card.char and card.char ~= "" and (not ok or card.char ~= current) or false
        addon.InventoryUI.filter = ""
        if addon.InventoryUI.filterBox then addon.InventoryUI.filterBox:SetText("") end
        addon.Main.tabsBar:select("inventory")
    end)
    self.scopeButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    self.scopeButton:SetSize(150, 24)
    self.scopeButton:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 16, 20)
    self.scopeButton:SetScript("OnClick", function()
        if combat() then return end
        GoldPilotCharDB = GoldPilotCharDB or {}
        GoldPilotCharDB.nowAccount = not (GoldPilotCharDB.nowAccount == true)
        self:refresh()
    end)
    self.scopeButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:AddLine(addon.L.NOW_SCOPE_HELP, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    self.scopeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.widgets.cards.onSelect = function(item)
        self.selected = item
        self:refresh()
    end
    return self:refresh()
end

addon.Main:registerTab("now", function(page) NowUI:build(page) end)

addon.Modules:register("now-ui", { onEnable = function()
    local delays = { BAG_UPDATE_DELAYED = 0.5, MAIL_INBOX_UPDATE = 1,
        GET_ITEM_INFO_RECEIVED = 0.1, BANKFRAME_OPENED = 0.5 }
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "MAIL_INBOX_UPDATE", "GET_ITEM_INFO_RECEIVED",
        "AUCTION_HOUSE_CLOSED", "BANKFRAME_OPENED" }) do
        addon.Events:subscribe("now-ui", event, function()
            if visible() and addon.Main.activeTab == "now" then NowUI:refresh() end
        end, delays[event])
    end
end })

return NowUI
