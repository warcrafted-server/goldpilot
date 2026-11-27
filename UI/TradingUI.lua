local _, addon = ...

local TradingUI = { filter = "all" }
addon.TradingUI = TradingUI

local GREEN, RED, GRAY = { 0.35, 0.9, 0.4 }, { 0.9, 0.45, 0.35 }, { 0.65, 0.65, 0.65 }
local GOLD, MUTED, SOFT = { 1, 0.82, 0.2 }, { 0.55, 0.5, 0.42 }, { 0.78, 0.72, 0.55 }
local UNKNOWN_ICON = "Interface/Icons/INV_Misc_QuestionMark"
local FILTERS = { "all", "resale", "stock", "personal" }

local function combat() return InCombatLockdown and InCombatLockdown() end
local function visible()
    return addon.Main and addon.Main.frame and addon.Main.frame.IsShown and addon.Main.frame:IsShown()
end
local function now()
    local ok, value = addon.Compat.call("time")
    return ok and tonumber(value) or 0
end
local function signed(value)
    value = tonumber(value) or 0
    if value == 0 then return addon.Theme.money(0), GRAY end
    return (value < 0 and "-" or "+") .. addon.Theme.money(math.abs(value)), value > 0 and GREEN or RED
end
local function allEntries(db)
    local entries, years = {}, {}
    for key in pairs(db and db.ledger or {}) do years[#years + 1] = key end
    table.sort(years, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
    for _, key in ipairs(years) do
        for _, entry in ipairs(db.ledger[key]) do entries[#entries + 1] = entry end
    end
    return entries
end
local function itemIcon(item)
    local id = item.itemID or addon.Ledger.itemID(GoldPilotDB, item.name)
    return id and addon.InventoryUI.itemIcon(id) or UNKNOWN_ICON
end
local function filterLabel(filter)
    return addon.L["TRADING_FILTER_" .. string.upper(filter or "all")]
end
local function include(item, filter)
    if filter == "personal" then return item.personal end
    if item.personal then return false end
    if filter == "resale" then return item.bought > 0 end
    if filter == "stock" then return item.stock > 0 end
    return true
end
local function detailLines(item)
    local L, lines = addon.L, {}
    local function add(label, right, color, gap)
        lines[#lines + 1] = { text = label, right = right, color = SOFT, rightColor = color, gap = gap }
    end
    -- La ficha no tiene desplazamiento: cada bloque ocupa dos líneas y los vacíos no se pintan.
    local function block(label, count, total, color, subLabel, subValue)
        add(string.format(label, count), total, color, 10)
        if subLabel then add(subLabel, subValue, color) end
    end
    lines[#lines + 1] = { text = item.name, color = GOLD, size = 14 }
    if item.bought > 0 then
        block(L.TRADING_BOUGHT, item.bought, addon.Theme.money(item.spent), nil, L.TRADING_AVERAGE, addon.Theme.money(item.avgBuy))
    end
    if item.sold > 0 then
        block(L.TRADING_SOLD, item.sold, addon.Theme.money(item.income), nil, L.TRADING_AVERAGE, addon.Theme.money(item.avgSell))
    end
    if item.vendorSold > 0 then add(string.format(L.TRADING_VENDOR, item.vendorSold), addon.Theme.money(item.vendorIncome), nil, 10) end
    if item.resold > 0 then
        local profit, color = signed(item.resaleProfit)
        local unit = signed(math.floor(item.resaleProfit / item.resold + 0.5))
        block(L.TRADING_RESOLD, item.resold, profit, color, L.TRADING_PER_UNIT, unit)
    end
    if item.other > 0 then block(L.TRADING_OTHER, item.other, addon.Theme.money(item.otherIncome)) end
    if item.stock > 0 then
        block(L.TRADING_UNSOLD, item.stock, addon.Theme.money(item.stockCost))
        local id = item.itemID or addon.Ledger.itemID(GoldPilotDB, item.name)
        local price = id and addon.Valuation.value(GoldPilotDB or {}, addon.AuctionHouse.houseKey(), id, now()).ref
        if price then
            local estimated = item.stock * math.floor(price.price * (1 - addon.Sell.CUT))
            local possible, color = signed(estimated - item.stockCost)
            add(L.TRADING_ESTIMATED .. " " .. addon.Theme.badge(price.class), addon.Theme.money(estimated), color)
            add(L.TRADING_POSSIBLE, possible, color)
        else
            add(L.TRADING_ESTIMATED, L.TRADING_NO_PRICE, GRAY)
        end
    end
    return lines
end
function TradingUI:refresh()
    if combat() or not visible() or not self.page or addon.Main.activeTab ~= "trading" then return false end
    GoldPilotDB, GoldPilotCharDB = GoldPilotDB or {}, GoldPilotCharDB or {}
    GoldPilotDB.personal = GoldPilotDB.personal or {}
    self.filter = GoldPilotCharDB.tradingFilter or "all"
    local items, totals = addon.Trading.analyze(allEntries(GoldPilotDB), GoldPilotDB.personal)
    table.sort(items, function(a, b)
        local aa, bb = math.abs(a.resaleProfit), math.abs(b.resaleProfit)
        if aa ~= bb then return aa > bb end
        if a.last ~= b.last then return a.last > b.last end
        return a.name < b.name
    end)
    local rows, selected, included = {}, nil, false
    for _, item in ipairs(items) do
        if include(item, self.filter) then
            included = true
            local right, color
            if item.resold > 0 then right, color = signed(item.resaleProfit)
            elseif item.stock > 0 then right, color = string.format(addon.L.TRADING_STOCK_ROW, item.stock), GRAY
            else right, color = "+" .. addon.Theme.money(item.income), { 1, 1, 1 } end
            rows[#rows + 1] = { key = item.name, text = item.name, right = right, rightColor = color,
                icon = itemIcon(item), item = item }
            if self.selectedName == item.name then selected = item end
        end
    end
    if not selected then self.selectedName = nil end
    self.widgets.list.selected = self.selectedName
    self.widgets.list:setRows(rows)
    local resale, resaleColor = signed(totals.resaleProfit)
    local balance, balanceColor = signed(totals.balance)
    self.widgets.metrics:setItems({
        { label = addon.L.TRADING_SPENT, value = addon.Theme.money(totals.spent) },
        { label = addon.L.TRADING_INCOME, value = addon.Theme.money(totals.income) },
        { label = addon.L.TRADING_RESALE, value = resale, color = resaleColor },
        { label = addon.L.TRADING_STOCK, value = addon.Theme.money(totals.stockCost) },
        { label = addon.L.TRADING_BALANCE, value = balance, color = balanceColor },
    })
    if #items == 0 then self.page.emptyText:SetText(addon.L.TRADING_EMPTY); self.page.emptyText:Show()
    else self.page.emptyText:Hide() end
    self.filterButton:SetText(filterLabel(self.filter))
    self.personalButton:SetEnabled(selected ~= nil)
    self.personalButton:SetText(selected and selected.personal and addon.L.TRADING_UNMARK_PERSONAL or addon.L.TRADING_MARK_PERSONAL)
    if selected then self.widgets.detail:setLines(detailLines(selected))
    else self.widgets.detail:setLines({ { text = addon.L.TRADING_PICK, color = GRAY } }) end
    return true
end

function TradingUI:build(page)
    if self.page == page and page._tradingBuilt then return self:refresh() end
    self.page, page._tradingBuilt = page, true
    self.widgets = { list = addon.Widgets.list(page, nil, 372), detail = addon.Widgets.detail(page),
        metrics = addon.Widgets.metrics(page, {}) }
    self.widgets.list:ClearAllPoints()
    self.widgets.list:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -108)
    self.widgets.list:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 20, 38)
    self.widgets.list:SetWidth(372)
    self.widgets.detail:ClearAllPoints()
    self.widgets.detail:SetPoint("TOPLEFT", page, "TOPLEFT", 424, -104)
    self.widgets.detail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -14, 34)
    self.widgets.detail.contentWidth = 298
    self.widgets.metrics:ClearAllPoints()
    self.widgets.metrics:SetPoint("TOPLEFT", page, "TOPLEFT", 76, -12)
    self.widgets.metrics.contentWidth = 668
    local background = addon.Widgets.panel(page, self.widgets.list.GetFrameLevel and self.widgets.list:GetFrameLevel() - 1)
    background:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -104)
    background:SetPoint("BOTTOMRIGHT", page, "BOTTOMLEFT", 418, 34)
    page.emptyText = background:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    page.emptyText:SetPoint("CENTER", background, "CENTER", 0, 0)
    if page.emptyText.SetWidth then page.emptyText:SetWidth(340) end
    page.emptyText:Hide()
    self.filterButton = addon.Widgets.selector(page, 150)
    self.filterButton:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -72)
    self.filterButton:SetScript("OnClick", function()
        if combat() then return end
        local index = 1
        for i, key in ipairs(FILTERS) do if key == self.filter then index = i end end
        GoldPilotCharDB = GoldPilotCharDB or {}
        GoldPilotCharDB.tradingFilter = FILTERS[index % #FILTERS + 1]
        self:refresh()
    end)
    self.personalButton = addon.Widgets.frame("Button", nil, page, "UIPanelButtonTemplate")
    self.personalButton:SetSize(230, 24)
    self.personalButton:SetPoint("TOPLEFT", page, "TOPLEFT", 176, -72)
    self.personalButton:SetScript("OnClick", function()
        if combat() or not self.selectedName then return end
        GoldPilotDB = GoldPilotDB or {}
        GoldPilotDB.personal = GoldPilotDB.personal or {}
        if GoldPilotDB.personal[self.selectedName] then GoldPilotDB.personal[self.selectedName] = nil
        else GoldPilotDB.personal[self.selectedName] = true end
        self:refresh()
    end)
    self.note = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.note:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 424, 8)
    self.note:SetWidth(320)
    self.note:SetText(addon.L.TRADING_NOTE)
    if self.note.SetTextColor then self.note:SetTextColor(0.55, 0.55, 0.55) end
    self.widgets.list.onSelect = function(row)
        if combat() then return end
        self.selectedName = row.item.name
        self:refresh()
    end
    return self:refresh()
end

addon.Main:registerTab("trading", function(page) TradingUI:build(page) end, addon.L.TAB_TRADING)

addon.Modules:register("trading-ui", { onEnable = function()
    for _, event in ipairs({ "MAIL_INBOX_UPDATE", "MAIL_CLOSED", "GET_ITEM_INFO_RECEIVED" }) do
        addon.Events:subscribe("trading-ui", event, function()
            if visible() and addon.Main.activeTab == "trading" then TradingUI:refresh() end
        end, event == "GET_ITEM_INFO_RECEIVED" and 0.1 or 1)
    end
end })

return TradingUI
