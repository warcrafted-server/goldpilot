local _, addon = ...

local LedgerUI = { account = true, period = 30 }
addon.LedgerUI = LedgerUI

local GREEN, RED, GRAY = { 0.35, 0.9, 0.4 }, { 0.9, 0.45, 0.35 }, { 0.65, 0.65, 0.65 }
local GOLD, MUTED, SOFT = { 1, 0.82, 0.2 }, { 0.55, 0.5, 0.42 }, { 0.78, 0.72, 0.55 }

local UNKNOWN_ICON = "Interface/Icons/INV_Misc_QuestionMark"

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

local function currentCharacter()
    local ok, name = addon.Compat.call("UnitName", "player")
    return ok and type(name) == "string" and name or "unknown"
end

local function signed(value)
    value = tonumber(value) or 0
    if value == 0 then return addon.Theme.money(0), GRAY end
    return (value < 0 and "-" or "+") .. addon.Theme.money(math.abs(value)), value > 0 and GREEN or RED
end

local function periodLabel(period)
    if period == 7 then return addon.L.LEDGER_PERIOD_7 end
    if period == 0 then return addon.L.LEDGER_PERIOD_ALL end
    return addon.L.LEDGER_PERIOD_30
end

local function detailLines(item, entries, account)
    local L, lines = addon.L, {}
    local function add(label, value, color)
        lines[#lines + 1] = { text = label, right = value, color = SOFT, rightColor = color }
    end
    local function section(label)
        lines[#lines + 1] = { text = label, color = MUTED, size = 11, gap = 10 }
    end
    local amount, color = signed(item.balance)
    lines[#lines + 1] = { text = item.name, color = GOLD, size = 14 }
    add(L.LEDGER_BALANCE, amount, color)
    if item.sold > 0 then
        section(L.LEDGER_SALES)
        add(L.LEDGER_UNITS, tostring(item.sold))
        add(L.LEDGER_SALE_GROSS, addon.Theme.money(item.gross))
        add(L.LEDGER_CUT, addon.Theme.money(item.cut))
        add(L.LEDGER_DEPOSIT, addon.Theme.money(item.deposit))
        add(L.LEDGER_NET, addon.Theme.money(item.net), item.net > 0 and GREEN or item.net < 0 and RED or GRAY)
        add(L.LEDGER_AVERAGE, addon.Theme.money(math.floor(item.gross / item.sold)))
    end
    if item.bought > 0 then
        section(L.LEDGER_PURCHASES)
        add(L.LEDGER_UNITS, tostring(item.bought))
        add(L.LEDGER_SPENT, addon.Theme.money(item.spent))
        add(L.LEDGER_AVERAGE, addon.Theme.money(math.floor(item.spent / item.bought)))
    end
    if item.returned > 0 then add(L.LEDGER_RETURNED, tostring(item.returned)) end
    local chars = {}
    if account then
        for name in pairs(item.chars) do chars[#chars + 1] = name end
        table.sort(chars)
    end
    if #chars > 1 then
        section(L.LEDGER_BY_CHARACTER)
        for _, name in ipairs(chars) do
            local value, charColor = signed(item.chars[name])
            add(name, value, charColor)
        end
    end
    section(L.LEDGER_RECENT)
    local kinds = { sell = L.LEDGER_SALE, buy = L.LEDGER_PURCHASE, return_ = L.LEDGER_RETURN }
    for i = 1, math.min(6, #entries) do
        local entry = entries[i]
        local kind = entry.kind == "return" and kinds.return_ or entry.kind == "sell" and entry.venue == "vendor" and L.LEDGER_VENDOR_SALE or kinds[entry.kind]
        local text = string.format(kind, tonumber(entry.qty) or 0)
        text = text .. " |cff8a8a8a" .. addon.Theme.age(math.max(0, currentTime() - (tonumber(entry.t) or 0))) .. "|r"
        local net, netColor = signed(entry.net)
        add(text, net, netColor)
    end
    return lines
end

-- El cliente solo encuentra por nombre los objetos que ya tiene cargados; si no, queda para el próximo escaneo.
local function itemIcon(item)
    local itemID = item.itemID or addon.Ledger.itemID(GoldPilotDB, item.name)
    if not itemID then
        local ok, found = addon.Compat.call("C_Item.GetItemInfoInstant", item.name)
        if not ok or not tonumber(found) then ok, found = addon.Compat.call("GetItemInfoInstant", item.name) end
        itemID = ok and tonumber(found) or nil
        if itemID then addon.Ledger.learn(GoldPilotDB, item.name, itemID) end
    end
    return itemID and addon.InventoryUI.itemIcon(itemID) or UNKNOWN_ICON
end

function LedgerUI:refresh()
    if combat() or not visible() or not self.page or addon.Main.activeTab ~= "ledger" then return false end
    GoldPilotDB, GoldPilotCharDB = GoldPilotDB or {}, GoldPilotCharDB or {}
    if GoldPilotCharDB.ledgerAccount == nil then GoldPilotCharDB.ledgerAccount = true end
    if GoldPilotCharDB.ledgerPeriod == nil then GoldPilotCharDB.ledgerPeriod = 30 end
    self.account, self.period = GoldPilotCharDB.ledgerAccount == true, tonumber(GoldPilotCharDB.ledgerPeriod) or 30
    local since = self.period == 0 and 0 or currentTime() - self.period * 86400
    local char
    if not self.account then char = currentCharacter() end
    local items, rows, selected = addon.Ledger.items(GoldPilotDB, since, char), {}, nil
    for _, item in ipairs(items) do
        local value, color = signed(item.balance)
        rows[#rows + 1] = { key = item.name, text = item.name, right = value, rightColor = color,
            icon = itemIcon(item), item = item }
        if self.selectedName == item.name then selected = item end
    end
    if not selected then self.selectedName = nil end
    self.widgets.list.selected = self.selectedName
    self.widgets.list:setRows(rows)
    local summary = addon.Ledger.summary(GoldPilotDB, since, char)
    local balance, balanceColor = signed(summary.balance)
    self.widgets.metrics:setItems({
        { label = addon.L.LEDGER_GROSS, value = addon.Theme.money(summary.gross) },
        { label = addon.L.LEDGER_CUT, value = addon.Theme.money(summary.cut) },
        { label = addon.L.LEDGER_SPENT, value = addon.Theme.money(summary.spent) },
        { label = addon.L.LEDGER_BALANCE, value = balance, color = balanceColor },
    })
    local hasRecords = false
    for _, year in pairs(GoldPilotDB.ledger or {}) do
        if #year > 0 then hasRecords = true; break end
    end
    if #items == 0 then
        self.page.emptyText:SetText(hasRecords and addon.L.LEDGER_EMPTY_PERIOD or addon.L.LEDGER_EMPTY)
        self.page.emptyText:Show()
    else
        self.page.emptyText:Hide()
    end
    self.scopeButton:SetText(self.account and addon.L.INVENTORY_SCOPE_ACCOUNT or addon.L.INVENTORY_SCOPE_CHARACTER)
    self.periodButton:SetText(periodLabel(self.period))
    if selected then
        self.widgets.detail:setLines(detailLines(selected, addon.Ledger.entries(GoldPilotDB, since, char,
            selected.name, 6), self.account))
    else
        self.widgets.detail:setLines({ { text = addon.L.LEDGER_PICK, color = GRAY } })
    end
    return true
end

function LedgerUI:build(page)
    if self.page == page and page._ledgerBuilt then return self:refresh() end
    self.page, page._ledgerBuilt = page, true
    self.widgets = { list = addon.Widgets.list(page, nil, 372), detail = addon.Widgets.detail(page),
        metrics = addon.Widgets.metrics(page, {}) }
    self.widgets.list:ClearAllPoints()
    self.widgets.list:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -108)
    self.widgets.list:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 20, 20)
    self.widgets.list:SetWidth(372)
    self.widgets.detail:ClearAllPoints()
    self.widgets.detail:SetPoint("TOPLEFT", page, "TOPLEFT", 424, -104)
    self.widgets.detail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -14, 16)
    self.widgets.detail.contentWidth = 298
    self.widgets.metrics:ClearAllPoints()
    self.widgets.metrics:SetPoint("TOPLEFT", page, "TOPLEFT", 76, -12)
    self.widgets.metrics.contentWidth = 668
    local list = self.widgets.list
    local background = addon.Widgets.panel(page, list.GetFrameLevel and list:GetFrameLevel() - 1)
    background:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -104)
    background:SetPoint("BOTTOMRIGHT", page, "BOTTOMLEFT", 418, 16)
    page.emptyText = background:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    page.emptyText:SetPoint("CENTER", background, "CENTER", 0, 0)
    if page.emptyText.SetWidth then page.emptyText:SetWidth(340) end
    page.emptyText:Hide()
    self.scopeButton = addon.Widgets.selector(page, 150)
    self.scopeButton:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -72)
    self.scopeButton:SetScript("OnClick", function()
        if combat() then return end
        GoldPilotCharDB = GoldPilotCharDB or {}
        GoldPilotCharDB.ledgerAccount = not (GoldPilotCharDB.ledgerAccount == true)
        self:refresh()
    end)
    self.periodButton = addon.Widgets.selector(page, 150)
    self.periodButton:SetPoint("TOPLEFT", page, "TOPLEFT", 176, -72)
    self.periodButton:SetScript("OnClick", function()
        if combat() then return end
        local periods = { 7, 30, 0 }
        local current = GoldPilotCharDB and tonumber(GoldPilotCharDB.ledgerPeriod) or 30
        local index = current == 7 and 1 or current == 30 and 2 or 3
        GoldPilotCharDB = GoldPilotCharDB or {}
        GoldPilotCharDB.ledgerPeriod = periods[index % #periods + 1]
        self:refresh()
    end)
    self.widgets.list.onSelect = function(row)
        if combat() then return end
        self.selectedName = row.item.name
        self:refresh()
    end
    return self:refresh()
end

addon.Main:registerTab("ledger", function(page) LedgerUI:build(page) end, addon.L.TAB_LEDGER)

addon.Modules:register("ledger-ui", { onEnable = function()
    local delays = { MAIL_INBOX_UPDATE = 1, GET_ITEM_INFO_RECEIVED = 0.1 }
    for _, event in ipairs({ "MAIL_INBOX_UPDATE", "MAIL_CLOSED", "GET_ITEM_INFO_RECEIVED" }) do
        addon.Events:subscribe("ledger-ui", event, function()
            if visible() and addon.Main.activeTab == "ledger" then LedgerUI:refresh() end
        end, delays[event])
    end
end })

return LedgerUI
