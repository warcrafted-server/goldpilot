local _, addon = ...

local View = {}
addon.ShoppingView = View

local GREEN, RED, GRAY = { 0.4, 0.9, 0.4 }, { 1, 0.3, 0.25 }, { 0.65, 0.65, 0.65 }

local function label(parent, width, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetFont("Fonts/FRIZQT__.TTF", 10, "")
    text:SetWordWrap(false)
    if width then text:SetWidth(width) end
    if justify then text:SetJustifyH(justify) end
    return text
end

local function money(value)
    return value and addon.Theme.money(value) or addon.L.SHOP_NO_DATA
end

function View.render(panel, y, openItem)
    local db, house = GoldPilotDB or {}, addon.AuctionHouse.houseKey()
    local entries = addon.Shopping.list(db)
    local now = time()
    table.sort(entries, function(a, b)
        local aBuy = addon.Shopping.evaluate(a, addon.Prices.get(db, house, a.itemID), now).state == "buy"
        local bBuy = addon.Shopping.evaluate(b, addon.Prices.get(db, house, b.itemID), now).state == "buy"
        if aBuy ~= bBuy then return aBuy end
        return a.itemID < b.itemID
    end)
    panel.shopping = panel.shopping or { rows = {} }
    local view = panel.shopping
    view.now = view.now or label(panel, 78, "RIGHT")
    view.max = view.max or label(panel, 74, "RIGHT")
    view.now:ClearAllPoints(); view.now:SetPoint("TOPRIGHT", panel, "TOPLEFT", 238, -y)
    view.max:ClearAllPoints(); view.max:SetPoint("TOPRIGHT", panel, "TOPLEFT", 316, -y)
    view.now:SetText(addon.L.SHOP_COL_NOW); view.max:SetText(addon.L.SHOP_COL_MAX)
    view.now:SetTextColor(unpack(GRAY)); view.max:SetTextColor(unpack(GRAY)); view.now:Show(); view.max:Show()
    y = y + 18
    if #entries == 0 then
        view.empty = view.empty or label(panel, 380)
        view.empty:ClearAllPoints(); view.empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -y)
        view.empty:SetWordWrap(true); view.empty:SetText(addon.L.SHOP_EMPTY); view.empty:Show()
        y = y + 38
    else
        if view.empty then view.empty:Hide() end
        for index = 1, 10 do
            local entry = entries[index]
            local row = view.rows[index]
            if entry then
                if not row then
                    row = { name = label(panel, 150), now = label(panel, 78, "RIGHT"), max = label(panel, 74, "RIGHT") }
                    row.button = addon.Widgets.frame("Button", nil, panel)
                    row.remove = addon.Widgets.frame("Button", nil, panel, "UIPanelButtonTemplate")
                    row.remove:SetSize(22, 18); row.remove:SetText("X")
                    row.remove:SetScript("OnClick", function(self) addon.Shopping.remove(GoldPilotDB, self.itemID); addon.DealsUI:refresh() end)
                    view.rows[index] = row
                end
                local name = addon.DealsUI.itemName(entry.itemID)
                local price = addon.Prices.get(db, house, entry.itemID)
                local result = addon.Shopping.evaluate(entry, price, time())
                local rowY = -y
                row.name:ClearAllPoints(); row.name:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, rowY)
                row.name:SetText(addon.Widgets.truncate(name or ("#" .. entry.itemID), 22)); row.name:Show()
                row.now:ClearAllPoints(); row.now:SetPoint("TOPRIGHT", panel, "TOPLEFT", 238, rowY)
                row.now:SetText(result.state == "unknown" and addon.L.SHOP_NO_DATA or money(result.price))
                row.now:SetTextColor(unpack(result.state == "buy" and GREEN or result.state == "wait" and RED or GRAY)); row.now:Show()
                row.max:ClearAllPoints(); row.max:SetPoint("TOPRIGHT", panel, "TOPLEFT", 316, rowY)
                row.max:SetText(money(entry.max)); row.max:SetTextColor(unpack(GRAY)); row.max:Show()
                row.remove:ClearAllPoints(); row.remove:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, rowY + 3)
                row.remove.itemID = entry.itemID; row.remove:Show()
                row.button:ClearAllPoints(); row.button:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, rowY + 2)
                row.button:SetSize(350, 20); row.button:SetScript("OnClick", function() openItem({ itemID = entry.itemID }, 0) end); row.button:Show()
                y = y + 20
            elseif row then
                row.name:Hide(); row.now:Hide(); row.max:Hide(); row.button:Hide(); row.remove:Hide()
            end
        end
        if #entries > 10 then
            view.more = view.more or label(panel)
            view.more:ClearAllPoints(); view.more:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -y)
            view.more:SetText(string.format(addon.L.SHOP_MORE, #entries - 10)); view.more:Show(); y = y + 18
        elseif view.more then view.more:Hide() end
    end
    return y
end

function View.hide(panel)
    local view = panel.shopping
    if not view then return end
    if view.now then view.now:Hide() end
    if view.max then view.max:Hide() end
    if view.empty then view.empty:Hide() end
    if view.more then view.more:Hide() end
    for _, row in ipairs(view.rows) do
        row.name:Hide(); row.now:Hide(); row.max:Hide(); row.button:Hide(); row.remove:Hide()
    end
end

return View
