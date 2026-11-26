local mock = { events = {}, output = {}, timers = {}, frames = {}, items = {} }
_G.GoldPilotMainFrame = nil
WorldMapFrame = nil
UISpecialFrames = {}
function CreateFrame(kind, name, parent, template)
    if template and mock.missingTemplates and mock.missingTemplates[template] then error("unknown template") end
    local frame = { kind = kind, name = name, parent = parent, template = template }
    if name then _G[name] = frame end
    mock.frames[#mock.frames + 1] = frame
    function frame:RegisterEvent(event) mock.events[event] = self end
    function frame:UnregisterEvent(event) mock.events[event] = nil end
    function frame:SetScript(script, fn) self.handler = fn; self.scripts = self.scripts or {}; self.scripts[script] = fn end
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:SetPoint(_, _, _, x, y) self.x, self.y = x, y end
    function frame:ClearAllPoints() end
    function frame:SetAllPoints() end
    function frame:SetFrameStrata() end
    function frame:SetFrameLevel(value) self.level = value end
    function frame:GetFrameLevel() return self.level or 0 end
    function frame:SetMovable() end
    function frame:EnableMouse() end
    function frame:RegisterForDrag() end
    function frame:SetClampedToScreen() end
    function frame:IsShown() return not self.hidden end
    function frame:SetWidth(w) self.width = w end
    function frame:SetHeight(h) self.height = h end
    function frame:GetHeight() return self.height or 360 end
    function frame:GetWidth() return self.width or 1 end
    function frame:SetScrollChild(child) self.scrollChild = child end
    function frame:SetText(value) self.value = value end
    function frame:SetEnabled(value) self.enabled = value end
    function frame:GetText() return self.value end
    function frame:SetChecked(value) self.checked = value == true end
    function frame:GetChecked() return self.checked end
    function frame:SetHighlightTexture(value) self.highlight = value end
    function frame:SetBackdrop(value) self.backdrop = value end
    function frame:SetBackdropColor(...) self.backdropColor = { ... } end
    function frame:StartMoving() self.moving = true end
    function frame:StopMovingOrSizing() self.moving = false end
    function frame:Hide() self.hidden = true end
    function frame:Show() self.hidden = false end
    function frame:CreateTexture()
        local texture = {}
        function texture:SetAllPoints() end
        function texture:SetTexture(value) self.texture = value end
        function texture:SetSize(w, h) self.width, self.height = w, h end
        function texture:SetWidth(value) self.width = value end
        function texture:SetHeight(value) self.height = value end
        function texture:SetPoint(...) self.point = { ... } end
        function texture:SetAllPoints() end
        function texture:SetColorTexture(...) self.color = { ... } end
        function texture:Show() self.hidden = false end
        function texture:Hide() self.hidden = true end
        return texture
    end
    function frame:CreateLine()
        local line = {}
        function line:SetColorTexture(...) self.color = { ... } end
        function line:SetThickness(value) self.thickness = value end
        function line:SetStartPoint(...) self.start = { ... } end
        function line:SetEndPoint(...) self.finish = { ... } end
        function line:Show() self.hidden = false end
        function line:Hide() self.hidden = true end
        return line
    end
    function frame:CreateFontString()
        local font = {}
        function font:SetFont(...) self.font = { ... } end
        function font:SetTextColor(...) self.color = { ... } end
        function font:SetText(value) self.value = value end
        function font:SetWordWrap(value) self.wordWrap = value end
        function font:SetWidth(value) self.width = value end
        function font:SetJustifyH(value) self.justify = value end
        function font:GetText() return self.value end
        function font:SetPoint(...) self.point = { ... } end
        function font:Hide() self.hidden = true end
        function font:Show() self.hidden = false end
        return font
    end
    function frame:GetCenter() return self.x or 0, self.y or 0 end
    return frame
end
UIParent = CreateFrame("Frame", "UIParent")
UISpecialFrames = {}
function print(...) mock.output[#mock.output + 1] = table.concat({ ... }, " ") end
function GetLocale() return "enUS" end
local function itemInfo(itemID)
    itemID = tonumber(itemID)
    local item = itemID and mock.items[itemID] or nil
    if not item then return nil end
    local name = item.name or ("Item " .. itemID)
    return name, "item:" .. itemID, 1, 1, 1, "class", "subclass", item.stack or 1,
        "", 123, item.sell, nil, nil, item.bind or 0
end
C_Item = {
    GetItemInfoInstant = function(itemID)
        itemID = tonumber(itemID)
        local item = itemID and mock.items[itemID] or nil
        return itemID, "class", "subclass", "", 123, item and item.class or 7, item and item.subclass or nil
    end,
    GetItemInfo = itemInfo,
    RequestLoadItemDataByID = function() end,
}
function GetItemInfo(itemID) return itemInfo(itemID) end
function GetItemInfoInstant(itemID)
    local item = mock.items[tonumber(itemID)]
    itemID = tonumber(itemID)
    return itemID, "class", "subclass", "", 123, item and item.class or 7, item and item.subclass or nil
end
function InCombatLockdown() return mock.combat == true end
function time() return 200000 end
function date(format, value) return os.date(format, value) end
function UnitName() return "Player" end
Minimap = { GetShape = function() return "ROUND" end, GetCenter = function() return 0, 0 end }
GameTooltip = { SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
SlashCmdList = {}
C_Timer = { After = function(_, fn) mock.timers[#mock.timers + 1] = fn end }
mock.loot = {}
mock.fishing = false
mock.mapID, mock.mapX, mock.mapY = 1, 0.5, 0.5
function mock.enableLoot()
    function GetNumLootItems() return #mock.loot end
    function GetLootSlotLink(slot)
        local entry = mock.loot[slot]
        return entry and entry.link or nil
    end
    function GetLootSourceInfo(slot)
        local entry = mock.loot[slot]
        if not entry then return nil end
        local values = {}
        for _, source in ipairs(entry.sources or {}) do
            values[#values + 1] = source.guid
            values[#values + 1] = source.qty
        end
        return unpack(values)
    end
    function IsFishingLoot() return mock.fishing == true end
    C_Map = {
        GetBestMapForUnit = function() return mock.mapID end,
        GetPlayerMapPosition = function()
            local x, y = mock.mapX, mock.mapY
            if mock.mapFields then return { x = x, y = y } end
            return { GetXY = function() return x, y end }
        end,
    }
end
function mock.fire(event, ...)
    if mock.events[event] then mock.events[event].handler(nil, event, ...) end
end
function mock.flushTimers()
    local timers = mock.timers; mock.timers = {}
    for _, fn in ipairs(timers) do fn() end
end
return mock
