local _, addon = ...

addon.Widgets = {}
local Widgets = addon.Widgets

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function frame(kind, name, parent, template)
    if template then
        local ok, result = pcall(CreateFrame, kind, name, parent, template)
        if ok and result then return result end
    end
    return CreateFrame(kind, name, parent)
end

local function backdrop(object, color)
    if object.SetBackdrop then
        pcall(object.SetBackdrop, object, {
            bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
    end
    if object.SetBackdropColor then pcall(object.SetBackdropColor, object, unpack(color or { 0.12, 0.09, 0.06, 0.96 })) end
end

local function text(parent, value, size, color)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if label.SetFont then label:SetFont("Fonts/FRIZQT__.TTF", size or 12, "") end
    if label.SetTextColor then label:SetTextColor(unpack(color or { 0.92, 0.86, 0.72 })) end
    label:SetText(value or "")
    return label
end

function Widgets.window(name, title, width, height)
    local root = frame("Frame", name, UIParent, "BackdropTemplate")
    root:SetSize(width, height)
    root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    root:SetFrameStrata("DIALOG")
    root:SetMovable(true)
    root:EnableMouse(true)
    root:SetClampedToScreen(true)
    backdrop(root)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(self) if not inCombat() then self:StartMoving() end end)
    root:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local heading = text(root, title, 16, { 1, 0.82, 0.2 })
    heading:SetPoint("TOPLEFT", root, "TOPLEFT", 16, -12)
    local close = frame("Button", nil, root, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() root:Hide() end)
    root.closeButton = close
    root.title = heading
    return root
end

function Widgets.tabs(parent, definitions, onChange)
    local bar = frame("Frame", nil, parent)
    bar:SetSize(720, 34)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -42)
    bar.buttons, bar.selected = {}, nil
    function bar:select(name)
        if inCombat() then return false end
        self.selected = name
        for _, item in ipairs(self.buttons) do
            if item.name == name then item:SetText("|cffffd100" .. item.label .. "|r")
            else item:SetText("|cffd8c7a3" .. item.label .. "|r") end
        end
        if onChange then onChange(name) end
    end
    for i, item in ipairs(definitions) do
        local button = frame("Button", nil, bar)
        button:SetSize(140, 28)
        button:SetPoint("LEFT", bar, "LEFT", (i - 1) * 146, 0)
        button.name, button.label = item.name, item.label
        button:SetText(item.label)
        button:SetScript("OnClick", function() bar:select(item.name) end)
        bar.buttons[#bar.buttons + 1] = button
    end
    return bar
end

function Widgets.list(parent, onSelect)
    local scroll = frame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -84)
    scroll:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 16, 16)
    scroll:SetWidth(320)
    local content = frame("Frame", nil, scroll)
    content:SetSize(300, 1)
    scroll:SetScrollChild(content)
    scroll.rows, scroll.data, scroll.selected, scroll.onSelect = {}, {}, nil, onSelect
    local offset = 0
    local function visibleCount()
        local height = scroll.GetHeight and scroll:GetHeight() or 360
        return math.max(1, math.ceil((height or 360) / 28) + 1)
    end
    local render
    local function createRow(index)
        local row = frame("Button", nil, content)
        row:SetSize(300, 28)
        row.text = text(row, "", 12)
        row.text:SetPoint("LEFT", row, "LEFT", 24, 0)
        row.rightText = text(row, "", 11)
        row.rightText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row:SetScript("OnClick", function(self)
            if inCombat() then return end
            scroll.selected = self.dataIndex
            if scroll.onSelect then scroll.onSelect(self.data) end
            render()
        end)
        scroll.rows[index] = row
        return row
    end
    render = function()
        local start = math.floor(offset / 28) + 1
        local count = math.min(math.max(0, #scroll.data - start + 1), visibleCount())
        for index = 1, count do
            local dataIndex = start + index - 1
            local row, data = scroll.rows[index] or createRow(index), scroll.data[dataIndex]
            row.data, row.dataIndex = data, dataIndex
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(dataIndex - 1) * 28)
            local badge = data.class and addon.Theme and addon.Theme.badge(data.class) or ""
            row.text:SetText((data.header and "|cffffd100" or "") .. badge .. (data.text or "") .. (data.header and "|r" or ""))
            row.rightText:SetText(data.right or "")
            if data.color and row.text.SetTextColor then row.text:SetTextColor(unpack(data.color)) end
            if data.rightColor and row.rightText.SetTextColor then row.rightText:SetTextColor(unpack(data.rightColor)) end
            if data.icon then
                row.icon = row.icon or row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(16, 16)
                row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
                row.icon:SetTexture(data.icon)
                row.icon:Show()
            elseif row.icon then row.icon:Hide() end
            row.background = row.background or row:CreateTexture(nil, "BACKGROUND")
            row.background:SetAllPoints()
            row.background:SetColorTexture(dataIndex == scroll.selected and 0.45 or 0.13, 0.1, 0.07, 0.8)
            if row.SetHighlightTexture then row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight") end
            row:Show()
        end
        for index = count + 1, #scroll.rows do scroll.rows[index]:Hide() end
    end
    function scroll:setRows(rows)
        if inCombat() then return false end
        self.data = rows or {}
        offset = 0
        content:SetHeight(math.max(1, #self.data * 28))
        render()
    end
    scroll:SetScript("OnVerticalScroll", function(_, value)
        offset = math.max(0, tonumber(value) or 0)
        render()
    end)
    return scroll
end

function Widgets.detail(parent)
    local panel = frame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 352, -84)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 16)
    backdrop(panel, { 0.09, 0.07, 0.05, 0.88 })
    panel.lines = {}
    function panel:setLines(lines)
        if inCombat() then return false end
        for _, line in ipairs(self.lines) do line:Hide() end
        self.lines = {}
        for i, value in ipairs(lines or {}) do
            local label = text(self, type(value) == "table" and value.text or value, 12,
                type(value) == "table" and value.color or nil)
            label:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -12 - (i - 1) * 20)
            self.lines[#self.lines + 1] = label
        end
    end
    return panel
end

function Widgets.metrics(parent, values)
    local strip = frame("Frame", nil, parent)
    strip:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 16, 16)
    strip:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 16)
    strip:SetHeight(42)
    strip.items = {}
    function strip:setItems(items)
        if inCombat() then return false end
        for _, item in ipairs(self.items) do item:Hide() end
        self.items = {}
        for i, item in ipairs(items or {}) do
            local label = text(self, (item.label or "") .. "  " .. (item.value or ""), 11, item.color)
            label:SetPoint("LEFT", self, "LEFT", (i - 1) * 220, 0)
            self.items[#self.items + 1] = label
        end
        return true
    end
    for i, item in ipairs(values or {}) do
        local label = text(strip, (item.label or "") .. "  " .. (item.value or ""), 11, item.color)
        label:SetPoint("LEFT", strip, "LEFT", (i - 1) * 220, 0)
        strip.items[#strip.items + 1] = label
    end
    return strip
end

function Widgets.checkbox(parent, label, checked, callback)
    local box = frame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(28, 28)
    box:SetChecked(checked == true)
    local caption = text(parent, label, 13)
    caption:SetPoint("LEFT", box, "RIGHT", 6, 0)
    box.label = caption
    box:SetScript("OnClick", function(self)
        local value
        if self.GetChecked then value = self:GetChecked() else value = not self.checked end
        self.checked = value
        if callback then callback(value == true) end
    end)
    return box
end

return Widgets
