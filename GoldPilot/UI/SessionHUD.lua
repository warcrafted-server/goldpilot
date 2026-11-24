local _, addon = ...

addon.SessionHUD = {}
local HUD = addon.SessionHUD

local WIDTH, HEIGHT, INTERVAL = 190, 64, 5

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function now()
    local ok, value = addon.Compat.call("time")
    return ok and tonumber(value) or 0
end

local function settings()
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.settings = GoldPilotDB.settings or {}
    return GoldPilotDB.settings
end

local function enabled()
    return settings().hud ~= false
end

local function text(parent, size, color)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if label.SetFont then label:SetFont("Fonts/FRIZQT__.TTF", size or 12, "") end
    if label.SetTextColor then label:SetTextColor(unpack(color or { 0.92, 0.86, 0.72 })) end
    if label.SetJustifyH then label:SetJustifyH("LEFT") end
    if label.SetWordWrap then label:SetWordWrap(false) end
    label:SetText("")
    return label
end

local function border(frame)
    local color = { 0.72, 0.55, 0.2, 0.9 }
    local top = frame:CreateTexture(nil, "OVERLAY")
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    if top.SetHeight then top:SetHeight(1) end
    top:SetColorTexture(unpack(color))
    local bottom = frame:CreateTexture(nil, "OVERLAY")
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    if bottom.SetHeight then bottom:SetHeight(1) end
    bottom:SetColorTexture(unpack(color))
    local left = frame:CreateTexture(nil, "OVERLAY")
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    if left.SetWidth then left:SetWidth(1) end
    left:SetColorTexture(unpack(color))
    local right = frame:CreateTexture(nil, "OVERLAY")
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    if right.SetWidth then right:SetWidth(1) end
    right:SetColorTexture(unpack(color))
end

local function tooltip(frame)
    if not GameTooltip then return end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:AddLine(addon.L.HUD_TITLE, 1, 0.82, 0.2)
    local rows = HUD.value and HUD.value.rows or {}
    local shown = 0
    for _, row in ipairs(rows) do
        if shown >= 5 then break end
        if row.kind ~= "none" then
            local name = addon.InventoryUI.itemName(row.itemID, row.key)
            GameTooltip:AddLine(string.format("%s ×%d", name, row.qty) .. "  "
                .. addon.Theme.money(row.value), 1, 1, 1)
            shown = shown + 1
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(addon.L.HUD_COIN .. ": " .. addon.Theme.money(HUD.value and HUD.value.coin or 0), 1, 1, 1)
    GameTooltip:AddLine(addon.L.HUD_NOTE, 0.78, 0.72, 0.55, true)
    GameTooltip:Show()
end

local function hideTooltip(frame)
    if not GameTooltip then return end
    if GameTooltip.IsOwned and not GameTooltip:IsOwned(frame) then return end
    GameTooltip:Hide()
end

local function build()
    if HUD.frame or inCombat() then return HUD.frame end
    GoldPilotCharDB = GoldPilotCharDB or {}
    GoldPilotCharDB.hud = GoldPilotCharDB.hud or {}
    local saved = GoldPilotCharDB.hud
    local frame = addon.Widgets.frame("Frame", nil, UIParent, "BackdropTemplate")
    HUD.frame = frame
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(saved.x) or 0, tonumber(saved.y) or -220)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not inCombat() then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local centerX, centerY = UIParent:GetCenter()
        if x and y and centerX and centerY then saved.x, saved.y = x - centerX, y - centerY end
    end)
    frame:SetScript("OnEnter", function(self) tooltip(self) end)
    frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.06, 0.04, 0.78)
    border(frame)

    frame.rateText = text(frame, 15, { 1, 0.82, 0.2 })
    frame.rateText:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -9)
    if frame.rateText.SetWidth then frame.rateText:SetWidth(160) end
    frame.totalText = text(frame, 11, { 0.92, 0.86, 0.72 })
    frame.totalText:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
    if frame.totalText.SetWidth then frame.totalText:SetWidth(164) end
    frame.noteText = text(frame, 10, { 0.55, 0.5, 0.42 })
    frame.noteText:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -48)
    if frame.noteText.SetWidth then frame.noteText:SetWidth(164) end

    local close = addon.Widgets.frame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function()
        if inCombat() then return end
        HUD:setEnabled(false)
    end)
    frame.closeButton = close
    return frame
end

function HUD:enabled()
    return enabled()
end

function HUD:schedule()
    if self.timer then return end
    if not self.frame or (self.frame.IsShown and not self.frame:IsShown()) then return end
    self.timer = true
    addon.Compat.call("C_Timer.After", INTERVAL, function()
        HUD.timer = false
        HUD:refresh()
    end)
end

function HUD:refresh()
    if inCombat() then self.pending = true; return false end
    self.pending = false
    local dbSettings = settings()
    GoldPilotCharDB = GoldPilotCharDB or {}
    local session = GoldPilotCharDB.session
    local current = now()
    if dbSettings.hud == false or not session or addon.Sessions.expired(session, current) then
        if self.frame and self.frame.IsShown and self.frame:IsShown() then
            hideTooltip(self.frame)
            self.frame:Hide()
        end
        return false
    end
    local frame = build()
    if not frame then return false end
    local active = addon.Sessions.active(session, current)
    local value = addon.Sessions.value(GoldPilotDB, addon.AuctionHouse.houseKey(),
        { coin = session.coin, items = session.items }, current, addon.ItemData.auctionable)
    self.value, self.active = value, active
    if active < 60 then
        frame.rateText:SetText(addon.L.HUD_MEASURING)
    else
        frame.rateText:SetText(string.format(addon.L.HUD_RATE,
            addon.Theme.money(addon.Sessions.rate(value.total, active) or 0)))
    end
    local paused = current - (tonumber(session.last) or current) > addon.Sessions.defaults.idle
    if paused then
        frame.totalText:SetText(string.format(addon.L.HUD_TOTAL_PAUSED, addon.Theme.money(value.total),
            addon.L.HUD_PAUSED))
    else
        frame.totalText:SetText(string.format(addon.L.HUD_TOTAL, addon.Theme.money(value.total),
            math.floor(active / 60)))
    end
    if value.unpriced > 0 then
        frame.noteText:SetText(string.format(addon.L.HUD_UNPRICED, value.unpriced))
        frame.noteText:Show()
    else
        frame.noteText:SetText("")
        frame.noteText:Hide()
    end
    frame:Show()
    self:schedule()
    return true
end

function HUD:setEnabled(value)
    local dbSettings = settings()
    dbSettings.hud = value ~= false
    if dbSettings.hud then
        self:refresh()
    elseif inCombat() then
        self.pending = true
    elseif self.frame and self.frame.IsShown and self.frame:IsShown() then
        hideTooltip(self.frame)
        self.frame:Hide()
    end
    return dbSettings.hud
end

function HUD:toggle()
    return self:setEnabled(not enabled())
end

local function report(session)
    local current = now()
    local value = addon.Sessions.value(GoldPilotDB or {}, addon.AuctionHouse.houseKey(),
        { coin = session.coin, items = session.items }, current, addon.ItemData.auctionable)
    local active = tonumber(session.active) or 0
    local rate = addon.Sessions.rate(value.total, active) or 0
    addon.Log:info(string.format(addon.L.SESSION_SUMMARY, math.floor(active / 60),
        addon.Theme.money(value.total), addon.Theme.money(rate)))
    if value.unpriced > 0 then
        addon.Log:info(string.format(addon.L.SESSION_UNPRICED, value.unpriced))
    end
end

addon.Modules:register("session-hud", {
    onEnable = function()
        addon.Events:subscribe("session-hud", "PLAYER_REGEN_ENABLED", function()
            if HUD.pending or HUD.frame then HUD:refresh() end
        end)
        addon.Loot.onLoot = function() HUD:refresh() end
        addon.Loot.onFinish = function(session, saved)
            if saved then report(session) end
            HUD:refresh()
        end
        HUD:refresh()
    end,
})

return HUD
