local _, addon = ...

local InventoryUI = { account = false, hideReserved = false, filter = "" }
addon.InventoryUI = InventoryUI

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function visible()
    return addon.Main and addon.Main.frame and addon.Main.frame.IsShown and addon.Main.frame:IsShown()
end

local function now()
    local ok, value = addon.Compat.call("time")
    return ok and tonumber(value) or 0
end

local function currentCharacter()
    local ok, name = addon.Compat.call("UnitName", "player")
    return ok and type(name) == "string" and name or "unknown"
end

local function itemName(itemID)
    local ok, name = addon.Compat.call("C_Item.GetItemInfo", itemID)
    if not ok then ok, name = addon.Compat.call("GetItemInfo", itemID) end
    if ok and type(name) == "string" and name ~= "" then return name end
    addon.Compat.call("C_Item.RequestLoadItemDataByID", itemID)
    return "[" .. itemID .. "]"
end

local function itemIcon(itemID)
    local ok, icon = addon.Compat.call("C_Item.GetItemIconByID", itemID)
    if ok then return icon end
    ok, _, _, _, _, _, _, _, _, icon = addon.Compat.call("GetItemInfo", itemID)
    return ok and icon or nil
end

local function matches(name, filter)
    return filter == "" or string.find(string.lower(name), string.lower(filter), 1, true) ~= nil
end

local function formatRow(row)
    local name = itemName(row.itemID)
    local right = row.unitBest and addon.Theme.money(row.valueBest) or addon.L.INVENTORY_NO_PRICE
    local color
    if row.stale then color = { 0.5, 0.5, 0.5 }
    elseif row.action == "auction" then color = { 0.35, 0.9, 0.4 }
    elseif row.action == "vendor" then color = { 1, 0.8, 0.25 }
    else color = { 0.65, 0.65, 0.65 } end
    return { itemID = row.itemID, text = name .. " ×" .. row.qty,
        right = right, icon = itemIcon(row.itemID), color = color, rightColor = color,
        row = row, name = name }
end

local function detailLines(row, name)
    local lines = { { text = name, color = { 1, 0.82, 0.2 } },
        string.format(addon.L.INVENTORY_TOTAL, row.qty, row.qtySellable, row.qtyReserved) }
    for _, part in ipairs(row.breakdown) do
        lines[#lines + 1] = string.format(addon.L.INVENTORY_BREAKDOWN, part.char,
            part.where == "bags" and addon.L.INVENTORY_BAGS or addon.L.INVENTORY_BANK, part.qty)
    end
    lines[#lines + 1] = string.format(addon.L.INVENTORY_VENDOR, row.vendorUnit and addon.Theme.money(row.vendorUnit) or addon.L.INVENTORY_NO_PRICE)
    local observation = addon.Prices.get(GoldPilotDB or {}, addon.AuctionHouse.houseKey(), row.itemID)
    if observation then
        lines[#lines + 1] = string.format(addon.L.INVENTORY_AUCTION, addon.Theme.money(observation.p50),
            addon.Theme.money(observation.min), observation.qty, addon.Theme.age(math.max(0, now() - observation.t)))
        if row.stale then lines[#lines + 1] = addon.L.INVENTORY_STALE_LABEL end
    else
        lines[#lines + 1] = addon.L.INVENTORY_NO_AUCTION
    end
    lines[#lines + 1] = string.format(addon.L.INVENTORY_NET, row.valueAuction > 0 and addon.Theme.money(row.valueAuction) or addon.L.INVENTORY_NO_PRICE)
    if row.cutAssumed then lines[#lines + 1] = addon.L.TOOLTIP_CUT_ASSUMED end
    local reason
    if row.action == "auction" then
        if row.vendorUnit then
            reason = string.format(addon.L.INVENTORY_REASON_AUCTION,
                addon.Theme.money(math.max(0, (row.unitBest or 0) - row.vendorUnit)))
        else reason = addon.L.INVENTORY_REASON_AUCTION_ONLY end
    elseif row.action == "vendor" then reason = addon.L.INVENTORY_REASON_VENDOR
    else reason = addon.L.INVENTORY_REASON_NONE end
    lines[#lines + 1] = string.format(addon.L.INVENTORY_RECOMMENDATION, addon.L["INVENTORY_ACTION_" .. string.upper(row.action)])
    lines[#lines + 1] = reason
    return lines
end

local function makeButton(parent, label, x, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(120, 24)
    button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, 60)
    button:SetText(label)
    button:SetScript("OnClick", function() if not inCombat() then callback() end end)
    return button
end

function InventoryUI:refresh()
    if inCombat() or not visible() or not self.page then return false end
    GoldPilotDB = GoldPilotDB or {}
    local db = GoldPilotDB
    local key = addon.AuctionHouse.houseKey()
    local scope
    if not self.account then scope = currentCharacter() end
    local built = addon.Inventory.build(db, key, scope, now())
    local rows, shown = {}, {}
    for _, row in ipairs(built.rows) do
        if (not self.hideReserved or not row.reserved) then
            local formatted = formatRow(row)
            if matches(formatted.name, self.filter) then
                rows[#rows + 1], shown[#shown + 1] = formatted, row
            end
        end
    end
    self.page._inventoryRows = shown
    self.widgets.list:setRows(rows)
    self.widgets.metrics:setItems({
        { label = addon.L.INVENTORY_BEST, value = addon.Theme.money(built.totals.valueBest) },
        { label = addon.L.INVENTORY_VENDOR_TOTAL, value = addon.Theme.money(built.totals.valueVendor) },
        { label = addon.L.INVENTORY_WITHOUT_PRICE, value = tostring(built.totals.withoutPrice) },
        { label = addon.L.INVENTORY_STALE, value = tostring(built.totals.stale) },
    })
    if #rows == 0 then
        local message = (next(db.prices or {}) == nil) and addon.L.INVENTORY_EMPTY_PRICES or addon.L.INVENTORY_EMPTY
        self.page.emptyText:SetText(message)
        self.page.emptyText:Show()
    else self.page.emptyText:Hide() end
    if self.selected then
        local selectedName
        for _, row in ipairs(shown) do if row.itemID == self.selected.itemID then selectedName = itemName(row.itemID); self.selected = row; break end end
        if selectedName then self.widgets.detail:setLines(detailLines(self.selected, selectedName)) end
    end
    self.scopeButton:SetText(self.account and addon.L.INVENTORY_SCOPE_ACCOUNT or addon.L.INVENTORY_SCOPE_CHARACTER)
    self.hideCheckbox:SetChecked(self.hideReserved)
    if self.selected then
        self.reserveButton:SetText(self.selected.reserved and addon.L.INVENTORY_UNRESERVE or addon.L.INVENTORY_RESERVE)
        self.watchButton:SetText(self.selected.watched and addon.L.INVENTORY_UNWATCH or addon.L.INVENTORY_WATCH)
    end
    return true
end

function InventoryUI:build(page)
    if self.page == page and page._inventoryBuilt then return self:refresh() end
    self.page, page._inventoryBuilt = page, true
    page._inventoryRows = {}
    self.widgets = { list = addon.Widgets.list(page), detail = addon.Widgets.detail(page), metrics = addon.Widgets.metrics(page, {}) }
    self.widgets.list:ClearAllPoints()
    self.widgets.list:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -116)
    self.widgets.list:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 16, 58)
    self.widgets.detail:ClearAllPoints()
    self.widgets.detail:SetPoint("TOPLEFT", page, "TOPLEFT", 352, -116)
    self.widgets.detail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -16, 58)
    page.emptyText = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    page.emptyText:SetPoint("CENTER", page, "CENTER", 0, 0)
    page.emptyText:Hide()
    self.scopeButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    self.scopeButton:SetSize(150, 24)
    self.scopeButton:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -12)
    self.scopeButton:SetScript("OnClick", function() if not inCombat() then self.account = not self.account; self:refresh() end end)
    self.hideCheckbox = addon.Widgets.checkbox(page, addon.L.INVENTORY_HIDE_RESERVED, self.hideReserved, function(value)
        if not inCombat() then self.hideReserved = value; self:refresh() end
    end)
    self.hideCheckbox:SetPoint("TOPLEFT", page, "TOPLEFT", 180, -10)
    self.filterBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    self.filterBox:SetSize(190, 24)
    self.filterBox:SetPoint("TOPRIGHT", page, "TOPRIGHT", -16, -12)
    if self.filterBox.SetAutoFocus then self.filterBox:SetAutoFocus(false) end
    self.filterBox:SetText(addon.L.INVENTORY_FILTER)
    if self.filterBox.SetScript then self.filterBox:SetScript("OnTextChanged", function(box)
        if inCombat() then return end
        self.filter = box:GetText() or ""
        self:refresh()
    end) end
    self.widgets.list.onSelect = function(formatted)
        if inCombat() then return end
        self.selected = formatted.row
        self.widgets.detail:setLines(detailLines(self.selected, formatted.name))
        self.reserveButton:Show(); self.watchButton:Show()
    end
    self.reserveButton = makeButton(page, addon.L.INVENTORY_RESERVE, 352, function()
        GoldPilotDB.reserved = GoldPilotDB.reserved or {}
        if self.selected.reserved then
            GoldPilotDB.reserved[self.selected.itemID] = nil
            self:refresh()
            return
        end
        local amount = IsShiftKeyDown and IsShiftKeyDown() and 1 or self.selected.qty
        GoldPilotDB.reserved[self.selected.itemID] = math.min(self.selected.qty,
            (tonumber(GoldPilotDB.reserved[self.selected.itemID]) or 0) + amount)
        self:refresh()
    end)
    self.watchButton = makeButton(page, addon.L.INVENTORY_WATCH, 482, function()
        GoldPilotDB.watch = GoldPilotDB.watch or {}
        GoldPilotDB.watch[self.selected.itemID] = not GoldPilotDB.watch[self.selected.itemID] or nil
        self:refresh()
    end)
    self.reserveButton:Hide(); self.watchButton:Hide()
    return self:refresh()
end

addon.Main:registerTab("inventory", function(page) InventoryUI:build(page) end)

addon.Modules:register("inventory-ui", {
    onEnable = function()
        local function refresh() if visible() then InventoryUI:refresh() end end
        for _, event in ipairs({ "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED",
            "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_CLOSED" }) do
            local delay = event == "BAG_UPDATE_DELAYED" and 0.5 or event == "GET_ITEM_INFO_RECEIVED" and 0.1 or nil
            addon.Events:subscribe("inventory-ui", event, refresh, delay)
        end
    end,
})

return InventoryUI
