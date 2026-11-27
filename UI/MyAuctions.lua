local _, addon = ...

local MyAuctions = { owner = "my-auctions", queried = false, active = false }
addon.MyAuctions = MyAuctions

local WIDTH, ROW_HEIGHT = 360, 20
local GOLD = { 0.9, 0.72, 0.29 }
local RED, GREEN, PALE, GRAY = { 1, 0.3, 0.25 }, { 0.4, 0.9, 0.4 }, { 0.92, 0.82, 0.55 }, { 0.65, 0.65, 0.65 }

local function call(object, method, ...)
    if not object or type(object[method]) ~= "function" then return nil end
    local ok, value = pcall(object[method], object, ...)
    if ok then return value end
end

local function shown(object) return object and call(object, "IsShown") == true end
local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function api(path, ...)
    local ok, a, b = addon.Compat.call(path, ...)
    if ok then return a, b end
end

local function createPanel(parent)
    if MyAuctions.frame or not parent or inCombat() then return MyAuctions.frame end
    local frame = addon.Widgets.sidePanel(parent, addon.L.MYAUCTIONS_TITLE, WIDTH)
    if not frame then return nil end
    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.summary:SetFont("Fonts/FRIZQT__.TTF", 11, "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -frame.contentTop)
    frame.rows = {}
    for i = 1, 8 do
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetFont("Fonts/FRIZQT__.TTF", 10, ""); label:SetWidth(150); label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        local value = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        value:SetFont("Fonts/FRIZQT__.TTF", 10, ""); value:SetWidth(60); value:SetJustifyH("RIGHT")
        value:SetWordWrap(false)
        local button = addon.Widgets.frame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(66, 18)
        frame.rows[i] = { label = label, value = value, button = button }
    end
    frame.more = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.more:SetFont("Fonts/FRIZQT__.TTF", 10, "")
    frame.more:SetTextColor(unpack(GRAY))
    frame.more:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -1)
    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.hint:SetFont("Fonts/FRIZQT__.TTF", 10, ""); frame.hint:SetWidth(WIDTH - 16)
    frame.hint:SetWordWrap(true)
    frame.hint:SetTextColor(unpack(GRAY)); frame.hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -1)
    frame:Hide(); MyAuctions.frame = frame
    return frame
end

local function itemKey(info, commodity)
    local id = tonumber(info.itemKey and info.itemKey.itemID)
    if commodity then return id end
    return (info.itemLink and addon.ItemKey.fromLink(info.itemLink, true)) or id
end

local function itemName(info)
    local keyInfo = api("C_AuctionHouse.GetItemKeyInfo", info.itemKey)
    if type(keyInfo) == "table" and type(keyInfo.itemName) == "string" then return keyInfo.itemName end
    return info.name or info.itemLink or tostring(info.itemKey and info.itemKey.itemID or "?")
end

local function ownedAuctions()
    local rows = api("C_AuctionHouse.GetOwnedAuctions")
    if type(rows) == "table" then return rows end
    local count = tonumber(api("C_AuctionHouse.GetNumOwnedAuctions")) or 0
    rows = {}
    for i = 1, count do
        local info = api("C_AuctionHouse.GetOwnedAuctionInfo", i)
        if type(info) == "table" then rows[#rows + 1] = info end
    end
    return rows
end

local function converted()
    local result, enqueued = {}, {}
    for _, info in ipairs(ownedAuctions()) do
        local id, buyout = tonumber(info.itemKey and info.itemKey.itemID), tonumber(info.buyoutAmount)
        local isCommodity = api("C_AuctionHouse.GetItemKeyInfo", info.itemKey)
        isCommodity = type(isCommodity) == "table" and isCommodity.isCommodity == true
        if id and buyout and buyout > 0 then
            local quantity = math.max(1, tonumber(info.quantity) or 1)
            local key = itemKey(info, isCommodity)
            local name = itemName(info)
            result[#result + 1] = { auctionID = info.auctionID, itemID = id, key = key, name = name,
                quantity = quantity, unitPrice = isCommodity and buyout or math.floor(buyout / quantity),
                status = info.status, timeLeft = info.timeLeftSeconds }
            if tonumber(info.status) ~= 1 and not enqueued[id] then
                enqueued[id] = true
                addon.AuctionHouse:enqueue(id, true)
            end
        end
    end
    return result
end
MyAuctions.convertOwned = converted

local function truncate(text)
    text = tostring(text or "?")
    local chars, cut = 0, 0
    for index = 1, #text do
        local byte = string.byte(text, index)
        if byte < 128 or byte >= 192 then
            chars = chars + 1
            if chars == 22 then cut = index end
            if chars == 24 then return string.sub(text, 1, cut) .. "…" end
        end
    end
    return text
end

local function render()
    if inCombat() then return end
    local auction = _G and _G.AuctionHouseFrame
    local panel = createPanel(auction)
    if not panel then return end
    local frame = auction and auction.AuctionsFrame
    if addon.Settings.get("myAuctions") == false or not shown(frame) then MyAuctions:hide(); return end
    local rows, summary = addon.Owned.review(converted(), function(key)
        local db = GoldPilotDB or {}
        local houseKey = addon.AuctionHouse:houseKey()
        local price = addon.Prices.get(db, houseKey, key)
        local value = addon.Valuation.value(db, houseKey, key, time())
        return price and { min = price.min, t = price.t, ref = value.ref and value.ref.price,
            vendor = value.vendor and value.vendor.price } or nil
    end, time())
    panel.summary:SetText(string.format(addon.L.MYAUCTIONS_SUMMARY, summary.undercut, summary.ok, summary.sold))
    panel.summary:SetTextColor(unpack(summary.undercut > 0 and RED or PALE))
    local count = math.min(8, #rows)
    for index, widgets in ipairs(panel.rows) do
        local row = rows[index]
        if row then
            local y = -(panel.contentTop + 20) - (index - 1) * ROW_HEIGHT
            widgets.label:ClearAllPoints(); widgets.label:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
            widgets.label:SetWidth(150)
            widgets.label:SetText(truncate(row.auction.name)); widgets.label:SetTextColor(unpack(PALE)); widgets.label:Show()
            widgets.value:ClearAllPoints(); widgets.value:SetPoint("TOPLEFT", panel, "TOPLEFT", 160, y)
            local state, color, text
            if row.state == "undercut" then state, color, text = addon.L.MYAUCTIONS_UNDERCUT, RED,
                string.format(addon.L.MYAUCTIONS_UNDERCUT, addon.Theme.money(row.min))
            elseif row.state == "ok" then state, color, text = addon.L.MYAUCTIONS_OK, GREEN, ""
            elseif row.state == "sold" then state, color, text = addon.L.MYAUCTIONS_SOLD, GOLD, addon.L.MYAUCTIONS_SOLD
            else state, color, text = addon.L.MYAUCTIONS_UNKNOWN, GRAY, addon.L.MYAUCTIONS_UNKNOWN end
            widgets.value:SetText(addon.Theme.money(row.auction.unitPrice))
            widgets.value:SetTextColor(unpack(PALE)); widgets.value:Show()
            widgets.state = widgets.state or panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            if widgets.state.SetFont then widgets.state:SetFont("Fonts/FRIZQT__.TTF", 10, "") end
            if widgets.state.SetJustifyH then widgets.state:SetJustifyH("RIGHT") end
            if widgets.state.SetWordWrap then widgets.state:SetWordWrap(false) end
            widgets.state:ClearAllPoints()
            widgets.state:SetPoint("TOPRIGHT", panel, "TOPRIGHT", row.state == "undercut" and -76 or -8, y)
            if widgets.state.SetWidth then widgets.state:SetWidth(row.state == "undercut" and 70 or 80) end
            widgets.state:SetText(text ~= "" and text or state)
            widgets.stateKind = row.state
            if widgets.state.SetTextColor then widgets.state:SetTextColor(unpack(color)) end
            widgets.state:Show()
            widgets.button:ClearAllPoints(); widgets.button:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, y + 1)
            if row.state == "undercut" then
                -- Se redibuja cada 0,5 s: mientras espera la confirmación debe conservar el «¿Seguro?».
                local confirming = MyAuctions.confirmID == row.auction.auctionID and MyAuctions.confirmText
                widgets.button:SetText(confirming or addon.L.MYAUCTIONS_CANCEL); widgets.button:Show()
                widgets.button:SetScript("OnClick", function()
                    if inCombat() then return end
                    local now = time()
                    if MyAuctions.confirmID == row.auction.auctionID and now <= (MyAuctions.confirmUntil or 0) then
                        MyAuctions.confirmID = nil
                        local ok = addon.Compat.call("C_AuctionHouse.CancelAuction", row.auction.auctionID)
                        if ok then addon.Log:info(string.format(addon.L.MYAUCTIONS_CANCELED, addon.Theme.money(row.suggestion and row.suggestion.price or math.max(1, row.min - 1)))) end
                    else
                        MyAuctions.confirmID, MyAuctions.confirmUntil = row.auction.auctionID, now + 4
                        local cost = api("C_AuctionHouse.GetCancelCost", row.auction.auctionID)
                        MyAuctions.confirmText = cost and (addon.L.MYAUCTIONS_CONFIRM .. " " .. addon.Theme.money(cost)) or addon.L.MYAUCTIONS_CONFIRM
                        widgets.button:SetText(MyAuctions.confirmText)
                        addon.Timer.after(4, function() if MyAuctions.confirmID == row.auction.auctionID then MyAuctions.confirmID = nil; render() end end, MyAuctions.owner)
                    end
                end)
            else widgets.button:Hide() end
        else widgets.label:Hide(); widgets.value:Hide(); widgets.button:Hide(); if widgets.state then widgets.state:Hide() end end
    end
    if #rows > count then
        panel.more:ClearAllPoints(); panel.more:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -(panel.contentTop + 20) - count * ROW_HEIGHT)
        panel.more:SetText(string.format(addon.L.MYAUCTIONS_MORE, #rows - count)); panel.more:Show()
    else panel.more:Hide() end
    if summary.undercut > 0 or summary.sold > 0 then
        panel.hint:ClearAllPoints(); panel.hint:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -(panel.contentTop + 20) - count * ROW_HEIGHT - (#rows > count and 17 or 0))
        panel.hint:SetText(addon.L.MYAUCTIONS_HINT); panel.hint:Show()
    else panel.hint:Hide() end
    local lines = math.max(1, count) * ROW_HEIGHT
    if #rows == 0 then
        panel.rows[1].label:SetText(addon.L.MYAUCTIONS_EMPTY); panel.rows[1].label:SetTextColor(unpack(GRAY)); panel.rows[1].label:Show()
        panel:SetHeight(panel.contentTop + 28)
    else panel:SetHeight(panel.contentTop + 20 + lines + (#rows > count and 18 or 0) + ((summary.undercut > 0 or summary.sold > 0) and 30 or 8)) end
    panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", auction, "TOPRIGHT", 4, -30); panel:Show()
    MyAuctions.active = true
end

function MyAuctions:hide()
    if inCombat() then return false end
    addon.Timer.cancelAll(self.owner); self.timer = nil; self.active = false; self.queried = false
    if self.frame then self.frame:Hide() end
    return true
end

local function poll()
    if inCombat() then return true end
    local auction = _G and _G.AuctionHouseFrame
    local visible = addon.Settings.get("myAuctions") ~= false and shown(auction and auction.AuctionsFrame)
    if not visible then
        if addon.Settings.get("myAuctions") == false then MyAuctions:hide()
        else
            if MyAuctions.frame then MyAuctions.frame:Hide() end
            MyAuctions.active, MyAuctions.queried = false, false
        end
        return true
    end
    if not MyAuctions.queried then
        MyAuctions.queried = true
        addon.Compat.call("C_AuctionHouse.QueryOwnedAuctions", {})
    end
    render()
    return true
end

function MyAuctions:start()
    if not self.timer then self.timer = addon.Timer.every(0.5, poll, self.owner) end
end

addon.Modules:register("my-auctions", {
    onEnable = function()
        addon.Events:subscribe("my-auctions", "AUCTION_HOUSE_SHOW", function()
            MyAuctions:start()
        end)
        addon.Events:subscribe("my-auctions", "AUCTION_HOUSE_CLOSED", function() MyAuctions:hide() end)
        addon.Events:subscribe("my-auctions", "OWNED_AUCTIONS_UPDATED", function() if MyAuctions.active then render() end end)
        addon.Events:subscribe("my-auctions", "COMMODITY_SEARCH_RESULTS_UPDATED", function() if MyAuctions.active then render() end end)
        addon.Events:subscribe("my-auctions", "ITEM_SEARCH_RESULTS_UPDATED", function() if MyAuctions.active then render() end end)
        addon.Events:subscribe("my-auctions", "PLAYER_REGEN_ENABLED", poll)
        addon.Events:subscribe("my-auctions", "GOLDPILOT_SETTING_CHANGED", function(key, value)
            if key == "myAuctions" then
                if value then MyAuctions:start() else MyAuctions:hide() end
            end
        end)
    end,
})

return MyAuctions
