local _, addon = ...

addon.ScanBar = {}
local ScanBar = addon.ScanBar

local WIDTH, HEIGHT, INTERVAL = 260, 18, 1
local GOLD = { 0.72, 0.55, 0.2, 0.9 }

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function now()
    local ok, value = addon.Compat.call("time")
    return ok and tonumber(value) or 0
end

local function edge(frame, first, second, horizontal)
    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetPoint(first, frame, first, 0, 0)
    texture:SetPoint(second, frame, second, 0, 0)
    if horizontal then
        if texture.SetHeight then texture:SetHeight(1) end
    elseif texture.SetWidth then
        texture:SetWidth(1)
    end
    texture:SetColorTexture(unpack(GOLD))
end

local function border(frame)
    edge(frame, "TOPLEFT", "TOPRIGHT", true)
    edge(frame, "BOTTOMLEFT", "BOTTOMRIGHT", true)
    edge(frame, "TOPLEFT", "BOTTOMLEFT", false)
    edge(frame, "TOPRIGHT", "BOTTOMRIGHT", false)
end

local function label(frame)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if text.SetFont then text:SetFont("Fonts/FRIZQT__.TTF", 11, "") end
    if text.SetTextColor then text:SetTextColor(1, 0.82, 0.2) end
    if text.SetJustifyH then text:SetJustifyH("CENTER") end
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetText("")
    return text
end

-- La barra se crea con el primer progreso; mientras no hay escaneo no ocupa nada.
local function build()
    if ScanBar.frame or inCombat() then return ScanBar.frame end
    local frame = addon.Widgets.frame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    local anchor = _G.AuctionHouseFrame
    if anchor then
        frame:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.08, 0.06, 0.04, 0.78)
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    fill:SetColorTexture(0.72, 0.55, 0.2, 0.35)
    border(frame)
    frame.fill = fill
    frame.text = label(frame)
    frame:Hide()
    ScanBar.frame = frame
    return frame
end

function ScanBar:hide()
    local frame = self.frame
    if frame and frame.IsShown and frame:IsShown() then frame:Hide() end
    return false
end

-- El texto lleva los segundos transcurridos, así que se refresca una vez por segundo mientras dure el escaneo.
function ScanBar:schedule()
    if inCombat() or (self.timer and self.timer:active()) then return end
    self.timer = addon.Timer.after(INTERVAL, function()
        local progress = addon.FullScan and addon.FullScan.progress
        if progress then ScanBar:update(progress) end
    end, "scan-bar")
end

function ScanBar:update(progress)
    if inCombat() then return false end
    if not progress then return self:hide() end
    local frame = build()
    if not frame then return false end
    local percent = addon.FullScan and addon.FullScan:percent() or 0
    local elapsed = math.max(0, now() - (tonumber(progress.started) or now()))
    if progress.phase == "wait" then
        frame.text:SetText(string.format(addon.L.SCAN_BAR_WAIT, percent, elapsed))
        self:schedule()
    elseif progress.phase == "cooldown" then
        local left = math.max(0, math.floor((tonumber(progress["until"]) or now()) - now()))
        frame.text:SetText(string.format(addon.L.SCAN_BAR_COOLDOWN, math.floor(left / 60), left % 60))
        self:schedule()
    else
        frame.text:SetText(string.format(addon.L.SCAN_BAR_READ, percent, elapsed))
        self:schedule()
    end
    if frame.fill.SetWidth then frame.fill:SetWidth(math.max(2, (WIDTH - 2) * percent / 100)) end
    frame:Show()
    return true
end

addon.Modules:register("scan-bar", {
    onEnable = function()
        addon.Events:subscribe("scan-bar", "GOLDPILOT_SCAN_PROGRESS", function(progress)
            ScanBar:update(progress)
        end)
        addon.Events:subscribe("scan-bar", "PLAYER_REGEN_ENABLED", function()
            ScanBar:update(addon.FullScan.progress)
        end)
        if addon.FullScan and addon.FullScan.progress then ScanBar:update(addon.FullScan.progress) end
    end,
})

return ScanBar
