local _, addon = ...

local LIST_WIDTH, DETAIL_X = 372, 418

local InventoryUI = { account = false, hideReserved = false, onlyWatched = false, filter = "" }
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

local function itemLookup(key, itemID)
    return type(key) == "string" and GoldPilotDB and GoldPilotDB.links and GoldPilotDB.links[key] or itemID
end

local function itemName(itemID, key)
    local lookup = itemLookup(key, itemID)
    local ok, name = addon.Compat.call("C_Item.GetItemInfo", lookup)
    if not ok then ok, name = addon.Compat.call("GetItemInfo", lookup) end
    if ok and type(name) == "string" and name ~= "" then return name end
    addon.Compat.call("C_Item.RequestLoadItemDataByID", itemID)
    return "[" .. itemID .. "]"
end

local function itemIcon(itemID, key)
    local lookup = itemLookup(key, itemID)
    local ok, icon = addon.Compat.call("C_Item.GetItemIconByID", lookup)
    if ok then return icon end
    ok, _, _, _, _, _, _, _, _, icon = addon.Compat.call("GetItemInfo", lookup)
    return ok and icon or nil
end

InventoryUI.itemName, InventoryUI.itemIcon = itemName, itemIcon

local function matches(name, filter)
    return filter == "" or string.find(string.lower(name), string.lower(filter), 1, true) ~= nil
end

local function formatRow(row)
    local name = itemName(row.itemID, row.key)
    local right = row.unitBest and addon.Theme.money(row.valueBest) or addon.L.INVENTORY_NO_PRICE
    local color
    if row.stale then color = { 0.5, 0.5, 0.5 }
    elseif row.action == "auction" then color = { 0.35, 0.9, 0.4 }
    elseif row.action == "vendor" then color = { 1, 0.8, 0.25 }
    else color = { 0.65, 0.65, 0.65 } end
    local star = row.watched and "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14|t " or ""
    return { key = row.key, itemID = row.itemID, text = star .. name .. " ×" .. row.qty,
        right = right, icon = itemIcon(row.itemID, row.key), color = color, rightColor = color,
        row = row, name = name }
end

local GOLD, MUTED, SOFT = { 1, 0.82, 0.2 }, { 0.55, 0.5, 0.42 }, { 0.78, 0.72, 0.55 }
local ACTION_COLORS = { auction = { 0.35, 0.9, 0.4 }, vendor = { 1, 0.8, 0.25 }, none = { 0.65, 0.65, 0.65 } }
local MAX_PLACES = 4

-- La ficha responde por orden: qué hago, cuánto gano, por qué y dónde lo tengo.
local function detailLines(row, name)
    local L, money = addon.L, addon.Theme.money
    local lines = {}
    local function add(label, right, rightColor)
        lines[#lines + 1] = { text = label, right = right, color = SOFT, rightColor = rightColor }
    end
    local function section(title) lines[#lines + 1] = { text = title, color = MUTED, size = 11, gap = 10 } end
    local function dim(value) return "|cff8a8a8a" .. value .. "|r" end

    lines[1] = { text = name .. "  ×" .. row.qty, color = GOLD, size = 14 }
    lines[2] = { text = L.INVENTORY_BEST_OPTION, right = L["INVENTORY_ACTION_" .. string.upper(row.action)], size = 13, gap = 8,
        color = { 0.92, 0.86, 0.72 }, rightColor = ACTION_COLORS[row.action] }
    if row.action ~= "none" then
        lines[3] = { text = string.format(L.INVENTORY_YOU_GET, row.qtySellable), right = money(row.valueBest), size = 13,
            color = { 0.92, 0.86, 0.72 } }
    end

    section(L.INVENTORY_PER_UNIT)
    add(L.TOOLTIP_ROW_VENDOR, row.vendorUnit and money(row.vendorUnit) or dim(L.TOOLTIP_NO_VENDOR))
    local observation = row.qtyAuction > 0 and addon.Prices.get(GoldPilotDB or {}, addon.AuctionHouse.houseKey(), row.key)
    if observation then
        local cut = GoldPilotDB and GoldPilotDB.houses and GoldPilotDB.houses[addon.AuctionHouse.houseKey()]
        cut = cut and tonumber(cut.cut) or 0.05
        local net = math.floor(observation.p50 * (1 - cut))
        add(L.TOOLTIP_ROW_LAST, money(observation.min))
        add(L.TOOLTIP_ROW_MEDIAN, money(observation.p50))
        add(string.format(L.INVENTORY_NET_UNIT, math.floor(cut * 100 + 0.5)), money(net))
        if row.vendorUnit and not row.stale then
            local gain = net - row.vendorUnit
            add(L.INVENTORY_DIFFERENCE, (gain < 0 and "-" or "+") .. money(math.abs(gain)),
                gain > 0 and ACTION_COLORS.auction or { 0.9, 0.45, 0.35 })
        end
        section(L.INVENTORY_MARKET)
        add(L.TOOLTIP_ROW_FORSALE, string.format(L.TOOLTIP_UNITS, observation.qty))
        local age = addon.Theme.age(math.max(0, now() - observation.t))
        add(L.INVENTORY_SEEN, row.stale and dim(age .. " - " .. L.TOOLTIP_STALE) or age)
    elseif row.qtyAuction > 0 then
        add(L.TOOLTIP_ROW_AUCTION, dim(L.TOOLTIP_NO_AUCTION))
    end

    section(L.INVENTORY_WHERE)
    for i, part in ipairs(row.breakdown) do
        if i > MAX_PLACES then
            add(string.format(L.INVENTORY_MORE_PLACES, #row.breakdown - MAX_PLACES), "")
            break
        end
        add(part.char .. " · " .. (part.where == "bags" and L.INVENTORY_BAGS or L.INVENTORY_BANK), tostring(part.qty))
    end
    if row.qtyReserved > 0 then add(L.INVENTORY_RESERVED_COUNT, tostring(row.qtyReserved)) end
    if row.qtyBound > 0 then add(L.INVENTORY_BOUND_COUNT, tostring(row.qtyBound)) end
    return lines
end

local function buttonHelp(button, text)
    if not button.SetScript then return end
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.helpTitle or "", 1, 0.82, 0.2)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function makeButton(parent, label, x, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(120, 24)
    button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, 20)
    button:SetText(label)
    button:SetScript("OnClick", function() if not inCombat() then callback() end end)
    return button
end

local function setEnabled(button, enabled)
    local method = enabled and button.Enable or button.Disable
    if method then method(button) end
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
        if (not self.hideReserved or not row.reserved) and (not self.onlyWatched or row.watched) then
            local formatted = formatRow(row)
            if matches(formatted.name, self.filter) then
                rows[#rows + 1], shown[#shown + 1] = formatted, row
            end
        end
    end
    self.page._inventoryRows = shown
    self.widgets.list.selected = self.selected and self.selected.key or nil
    self.widgets.list:setRows(rows)
    self.widgets.metrics:setItems({
        { label = addon.L.INVENTORY_BEST, value = addon.Theme.money(built.totals.valueBest), color = { 0.5, 0.88, 0.54 } },
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
        for _, row in ipairs(shown) do if row.key == self.selected.key then selectedName = itemName(row.itemID, row.key); self.selected = row; break end end
        if selectedName then self.widgets.detail:setLines(detailLines(self.selected, selectedName))
        else self.selected = nil end
    end
    self.scopeButton:SetText(self.account and addon.L.INVENTORY_SCOPE_ACCOUNT or addon.L.INVENTORY_SCOPE_CHARACTER)
    self.hideCheckbox:SetChecked(self.hideReserved)
    self.watchedCheckbox:SetChecked(self.onlyWatched)
    if self.selected then
        self.reserveButton:SetText(self.selected.reserved and addon.L.INVENTORY_UNRESERVE or addon.L.INVENTORY_RESERVE)
        self.watchButton:SetText(self.selected.watched and addon.L.INVENTORY_UNWATCH or addon.L.INVENTORY_WATCH)
    else
        self.widgets.detail:setLines({ { text = addon.L.INVENTORY_PICK, color = { 0.65, 0.65, 0.65 } } })
    end
    setEnabled(self.reserveButton, self.selected ~= nil)
    setEnabled(self.watchButton, self.selected ~= nil)
    return true
end

function InventoryUI:build(page)
    if self.page == page and page._inventoryBuilt then return self:refresh() end
    self.page, page._inventoryBuilt = page, true
    page._inventoryRows = {}
    self.widgets = { list = addon.Widgets.list(page, nil, LIST_WIDTH), detail = addon.Widgets.detail(page), metrics = addon.Widgets.metrics(page, {}) }
    self.widgets.list:ClearAllPoints()
    self.widgets.list:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -108)
    self.widgets.list:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 20, 20)
    self.widgets.list:SetWidth(LIST_WIDTH)
    self.widgets.detail:ClearAllPoints()
    self.widgets.detail:SetPoint("TOPLEFT", page, "TOPLEFT", DETAIL_X, -104)
    self.widgets.detail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -14, 52)
    self.widgets.detail.contentWidth = 330 - 24
    self.widgets.metrics:ClearAllPoints()
    self.widgets.metrics:SetPoint("TOPLEFT", page, "TOPLEFT", 76, -12)
    self.widgets.metrics.contentWidth = 668
    local listBackground = addon.Widgets.frame("Frame", nil, page, "BackdropTemplate")
    listBackground:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -104)
    listBackground:SetPoint("BOTTOMRIGHT", page, "BOTTOMLEFT", 20 + LIST_WIDTH + 26, 16)
    if listBackground.SetFrameLevel and self.widgets.list.GetFrameLevel then
        listBackground:SetFrameLevel(math.max(0, self.widgets.list:GetFrameLevel() - 1))
    end
    if listBackground.SetBackdrop then
        pcall(listBackground.SetBackdrop, listBackground, { edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12 })
    end
    if listBackground.CreateTexture then
        local fill = listBackground:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(0.09, 0.07, 0.05, 1)
    end
    page.emptyText = listBackground:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    page.emptyText:SetPoint("CENTER", listBackground, "CENTER", 0, 0)
    if page.emptyText.SetWidth then page.emptyText:SetWidth(340) end
    page.emptyText:Hide()
    self.scopeButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    self.scopeButton:SetSize(150, 24)
    self.scopeButton:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -72)
    self.scopeButton:SetScript("OnClick", function() if not inCombat() then self.account = not self.account; self:refresh() end end)
    self.hideCheckbox = addon.Widgets.checkbox(page, addon.L.INVENTORY_HIDE_RESERVED, self.hideReserved, function(value)
        if not inCombat() then self.hideReserved = value; self:refresh() end
    end)
    self.hideCheckbox:SetPoint("TOPLEFT", page, "TOPLEFT", 176, -70)
    self.watchedCheckbox = addon.Widgets.checkbox(page, addon.L.INVENTORY_ONLY_WATCHED, self.onlyWatched, function(value)
        if not inCombat() then self.onlyWatched = value; self:refresh() end
    end)
    self.watchedCheckbox:SetPoint("TOPLEFT", page, "TOPLEFT", 356, -70)
    self.filterBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    self.filterBox:SetSize(190, 24)
    self.filterBox:SetPoint("TOPRIGHT", page, "TOPRIGHT", -16, -72)
    if self.filterBox.SetAutoFocus then self.filterBox:SetAutoFocus(false) end
    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("LEFT", self.filterBox, "LEFT", 8, 0)
    if hint.SetTextColor then hint:SetTextColor(0.5, 0.5, 0.5) end
    hint:SetText(addon.L.INVENTORY_FILTER)
    local function updateHint(box)
        if (box:GetText() or "") == "" and not (box.HasFocus and box:HasFocus()) then hint:Show() else hint:Hide() end
    end
    self.filterBox:SetScript("OnTextChanged", function(box)
        updateHint(box)
        if inCombat() then return end
        self.filter = box:GetText() or ""
        self:refresh()
    end)
    self.filterBox:SetScript("OnEditFocusGained", function() hint:Hide() end)
    self.filterBox:SetScript("OnEditFocusLost", updateHint)
    self.filterBox:SetScript("OnEscapePressed", function(box)
        box:SetText("")
        if box.ClearFocus then box:ClearFocus() end
    end)
    self.filterBox:SetScript("OnEnterPressed", function(box) if box.ClearFocus then box:ClearFocus() end end)
    self.widgets.list.onSelect = function(formatted)
        if inCombat() then return end
        self.selected = formatted.row
        self.widgets.detail:setLines(detailLines(self.selected, formatted.name))
        self:refresh()
    end
    self.reserveButton = makeButton(page, addon.L.INVENTORY_RESERVE, DETAIL_X + 8, function()
        GoldPilotDB.reserved = GoldPilotDB.reserved or {}
        if self.selected.reserved then
            GoldPilotDB.reserved[self.selected.key] = nil
            self:refresh()
            return
        end
        local amount = IsShiftKeyDown and IsShiftKeyDown() and 1 or self.selected.qty
        GoldPilotDB.reserved[self.selected.key] = math.min(self.selected.qty - self.selected.qtyBound,
            (tonumber(GoldPilotDB.reserved[self.selected.key]) or 0) + amount)
        self:refresh()
    end)
    self.watchButton = makeButton(page, addon.L.INVENTORY_WATCH, DETAIL_X + 138, function()
        GoldPilotDB.watch = GoldPilotDB.watch or {}
        GoldPilotDB.watch[self.selected.itemID] = not GoldPilotDB.watch[self.selected.itemID] or nil
        self:refresh()
    end)
    self.reserveButton.helpTitle, self.watchButton.helpTitle = addon.L.INVENTORY_RESERVE, addon.L.INVENTORY_WATCH
    buttonHelp(self.reserveButton, addon.L.INVENTORY_RESERVE_HELP)
    buttonHelp(self.watchButton, addon.L.INVENTORY_WATCH_HELP)
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
