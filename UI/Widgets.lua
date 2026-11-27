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

local function solidBackground(object, color)
    if not object.CreateTexture then return end
    local fill = object:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(unpack(color))
    object.solidFill = fill
end

Widgets.frame = frame

-- Recorta el borde gris que traen los iconos del juego.
local function cropIcon(texture)
    if texture.SetTexCoord then texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
end

local function hoverGlow(button)
    local glow = button:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 0.82, 0.2, 0.08)
end

local function selectionBand(button)
    local band = button:CreateTexture(nil, "ARTWORK")
    band:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    band:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    if band.SetWidth then band:SetWidth(2) end
    band:SetColorTexture(0.9, 0.72, 0.29, 1)
    return band
end

local function backdrop(object, color)
    color = color or { 0.12, 0.09, 0.06, 0.96 }
    solidBackground(object, { color[1], color[2], color[3], 1 })
    if object.SetBackdrop then
        pcall(object.SetBackdrop, object, {
            bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
    end
    if object.SetBackdropColor then pcall(object.SetBackdropColor, object, unpack(color)) end
    if object.SetBackdropBorderColor then pcall(object.SetBackdropBorderColor, object, 0.5, 0.4, 0.26, 1) end
end

local TEXT_COLOR = { 0.92, 0.86, 0.72 }

local function text(parent, value, size, color)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if label.SetFont then label:SetFont("Fonts/FRIZQT__.TTF", size or 12, "") end
    if label.SetTextColor then label:SetTextColor(unpack(color or { 0.92, 0.86, 0.72 })) end
    label:SetText(value or "")
    return label
end

-- Marco nativo con retrato; si el cliente no tiene la plantilla, marco propio con título y cierre.
function Widgets.window(name, title, width, height)
    local root = frame("Frame", name, UIParent, "PortraitFrameTemplate")
    local native = root.SetPortraitToAsset ~= nil or root.PortraitContainer ~= nil
    root:SetSize(width, height)
    root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    root:SetFrameStrata("HIGH")
    root:SetMovable(true)
    root:EnableMouse(true)
    root:SetClampedToScreen(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(self) if not inCombat() then self:StartMoving() end end)
    root:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    root.native = native

    if native then
        if root.SetTitle then pcall(root.SetTitle, root, title) end
        if root.SetPortraitToAsset then pcall(root.SetPortraitToAsset, root, addon.Theme.iconPath()) end
        solidBackground(root, { 0.082, 0.063, 0.043, 0.92 })
        -- El relleno no debe asomar por fuera del marco.
        if root.solidFill and root.solidFill.ClearAllPoints then
            root.solidFill:ClearAllPoints()
            root.solidFill:SetPoint("TOPLEFT", root, "TOPLEFT", 3, -22)
            root.solidFill:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -3, 3)
        end
        root.closeButton = root.CloseButton
    else
        backdrop(root)
        local heading = text(root, title, 14, { 0.9, 0.72, 0.29 })
        heading:SetPoint("TOPLEFT", root, "TOPLEFT", 16, -8)
        root.title = heading
    end
    if not root.closeButton then
        local close = frame("Button", nil, root, "UIPanelCloseButton")
        close:SetSize(24, 24)
        close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -4, -4)
        root.closeButton = close
    end
    root.closeButton:SetScript("OnClick", function() root:Hide() end)
    return root
end

-- Pestaña nativa colgada bajo la ventana; sin la plantilla, botón propio con fuente, fondo y línea.
function Widgets.tabButton(bar, name, label)
    local button = frame("Button", nil, bar, "PanelTabButtonTemplate")
    local previous = bar.buttons[#bar.buttons]
    button.name, button.label = name, label
    button.native = button.Left ~= nil or button.LeftActive ~= nil
    if button.native then
        button:SetText(label)
        if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, button, 24) end
        if button.GetWidth and (button:GetWidth() or 0) <= 0 then button:SetWidth(100) end
        if previous then button:SetPoint("TOPLEFT", previous, "TOPRIGHT", 3, 0)
        else button:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0) end
    else
        button:SetSize(120, 28)
        if previous then button:SetPoint("TOPLEFT", previous, "TOPRIGHT", 4, 0)
        else button:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0) end
        local fill = button:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        button.fill = fill
        if button.SetNormalFontObject then button:SetNormalFontObject("GameFontNormal") end
        button:SetText(label)
    end
    return button
end

function Widgets.tabs(parent, onChange)
    local bar = frame("Frame", nil, parent)
    bar:SetSize(720, 32)
    bar:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 12, 2)
    bar.buttons, bar.selected = {}, nil
    function bar:mark(name)
        self.selected = name
        for _, button in ipairs(self.buttons) do
            local active = button.name == name
            if button.native then
                local paint = active and PanelTemplates_SelectTab or PanelTemplates_DeselectTab
                if paint then pcall(paint, button) end
            elseif button.fill then
                button.fill:SetColorTexture(active and 0.42 or 0.13, active and 0.31 or 0.1, active and 0.12 or 0.07, 0.96)
            end
        end
    end
    function bar:select(name)
        if inCombat() then return false end
        self:mark(name)
        if onChange then onChange(name) end
    end
    function bar:add(name, label)
        local button = Widgets.tabButton(self, name, label)
        button:SetScript("OnClick", function() bar:select(name) end)
        self.buttons[#self.buttons + 1] = button
        if self.selected then self:mark(self.selected) end
        return button
    end
    return bar
end

-- Recuadro oscuro con borde bronce, por detrás de los controles de la página.
function Widgets.panel(parent, level)
    local panel = frame("Frame", nil, parent, "BackdropTemplate")
    if panel.SetFrameLevel and level then panel:SetFrameLevel(math.max(0, level)) end
    backdrop(panel, { 0.09, 0.07, 0.05, 1 })
    return panel
end

function Widgets.sidePanel(parent, title, width)
    if inCombat() or not parent then return nil end
    local panel = frame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(width, 100)
    panel:SetFrameStrata("DIALOG")
    backdrop(panel, { 0.09, 0.07, 0.05, 0.97 })
    panel.icon = panel:CreateTexture(nil, "ARTWORK")
    panel.icon:SetSize(16, 16)
    panel.icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    panel.icon:SetTexture(addon.Theme.iconPath())
    panel.title = text(panel, title, 12, { 0.9, 0.72, 0.29 })
    panel.title:SetPoint("LEFT", panel.icon, "RIGHT", 6, 0)
    panel.separator = panel:CreateTexture(nil, "ARTWORK")
    panel.separator:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -30)
    panel.separator:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -30)
    panel.separator:SetHeight(1)
    panel.separator:SetColorTexture(0.5, 0.4, 0.26, 0.6)
    panel.contentTop = 36
    return panel
end

-- Selector de vista o filtro: oscuro y con flecha, para no confundirlo con un botón de acción.
function Widgets.selector(parent, width)
    local button = frame("Button", nil, parent)
    button:SetSize(width, 24)
    local border = button:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.42, 0.33, 0.2, 1)
    local fill = button:CreateTexture(nil, "BORDER")
    fill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(0.1, 0.075, 0.05, 1)
    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", button, "RIGHT", -5, 0)
    arrow:SetTexture("Interface/ChatFrame/ChatFrameExpandArrow")
    hoverGlow(button)
    if button.SetNormalFontObject then button:SetNormalFontObject("GameFontNormal") end
    return button
end

function Widgets.list(parent, onSelect, width)
    width = width or 320
    local scroll = frame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -84)
    scroll:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 16, 16)
    scroll:SetWidth(width)
    local content = frame("Frame", nil, scroll)
    content:SetSize(width - 4, 1)
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
        row:SetSize(width - 4, 28)
        row.text = text(row, "", 12)
        row.rightText = text(row, "", 11)
        row.rightText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        if row.text.SetJustifyH then row.text:SetJustifyH("LEFT") end
        if row.text.SetWordWrap then row.text:SetWordWrap(false) end
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints()
        row.band = selectionBand(row)
        hoverGlow(row)
        row:SetScript("OnClick", function(self)
            if inCombat() then return end
            scroll.selected = self.data.key or self.dataIndex
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
            -- Las filas se reciclan: sin color propio hay que volver al de partida.
            if row.text.SetTextColor then row.text:SetTextColor(unpack(data.color or TEXT_COLOR)) end
            if row.rightText.SetTextColor then row.rightText:SetTextColor(unpack(data.rightColor or TEXT_COLOR)) end
            if row.text.ClearAllPoints then row.text:ClearAllPoints() end
            row.text:SetPoint("LEFT", row, "LEFT", data.icon and 34 or 10, 0)
            row.text:SetPoint("RIGHT", row.rightText, "LEFT", -8, 0)
            if data.icon then
                row.icon = row.icon or row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(20, 20)
                row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
                cropIcon(row.icon)
                row.icon:SetTexture(data.icon)
                row.icon:Show()
            elseif row.icon then row.icon:Hide() end
            if scroll.selected ~= nil and (data.key or dataIndex) == scroll.selected then
                row.background:SetColorTexture(0.27, 0.2, 0.1, 0.95)
                row.band:Show()
            else
                local shade = dataIndex % 2 == 0 and 0.105 or 0.13
                row.background:SetColorTexture(shade, shade * 0.78, shade * 0.55, 0.8)
                row.band:Hide()
            end
            row:Show()
        end
        for index = count + 1, #scroll.rows do scroll.rows[index]:Hide() end
    end
    function scroll:setRows(rows)
        if inCombat() then return false end
        self.data = rows or {}
        local height = #self.data * 28
        content:SetHeight(math.max(1, height))
        local bar = self.ScrollBar
        if bar and bar.Show then
            if height > (self.GetHeight and self:GetHeight() or 360) then bar:Show() else bar:Hide() end
        end
        -- Refrescar no debe perder la posición; si la lista se acorta, se ajusta al nuevo final.
        local limit = math.max(0, height - (scroll.GetHeight and scroll:GetHeight() or 360))
        if offset > limit then
            offset = limit
            if scroll.SetVerticalScroll then scroll:SetVerticalScroll(limit) end
        end
        render()
    end
    scroll:SetScript("OnVerticalScroll", function(_, value)
        offset = math.max(0, tonumber(value) or 0)
        render()
    end)
    return scroll
end

-- Ancho real del texto ya puesto; nil si el cliente aún no lo sabe.
local function stringWidth(label)
    local value = label.GetStringWidth and label:GetStringWidth() or 0
    return value > 0 and value or nil
end

function Widgets.detail(parent)
    local panel = frame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 352, -84)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 16)
    backdrop(panel, { 0.09, 0.07, 0.05, 0.95 })
    panel.lines = {}
    function panel:setLines(lines)
        if inCombat() then return false end
        lines = lines or {}
        self.labels, self.values = self.labels or {}, self.values or {}
        for _, label in ipairs(self.labels) do label:Hide() end
        for _, label in pairs(self.values) do label:Hide() end
        self.lines = {}
        local width = self.contentWidth or 300
        for i, value in ipairs(lines) do
            local line = type(value) == "table" and value or { text = value }
            local label = self.labels[i]
            if not label then
                label = text(self, "", 12)
                if label.SetJustifyH then label:SetJustifyH("LEFT") end
                self.labels[i] = label
            end
            if label.SetFont then label:SetFont("Fonts/FRIZQT__.TTF", line.size or 12, "") end
            if label.SetWidth then label:SetWidth(line.right and width * 0.62 or width) end
            if label.ClearAllPoints then label:ClearAllPoints() end
            if i > 1 then label:SetPoint("TOPLEFT", self.labels[i - 1], "BOTTOMLEFT", 0, -(line.gap or 4))
            else label:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -12) end
            label:SetText(line.text or "")
            if label.SetTextColor then label:SetTextColor(unpack(line.color or { 0.92, 0.86, 0.72 })) end
            label:Show()
            if line.right then
                local right = self.values[i]
                if not right then
                    right = text(self, "", 12)
                    if right.SetJustifyH then right:SetJustifyH("RIGHT") end
                    self.values[i] = right
                end
                if right.SetFont then right:SetFont("Fonts/FRIZQT__.TTF", line.size or 12, "") end
                if right.ClearAllPoints then right:ClearAllPoints() end
                right:SetPoint("TOPRIGHT", label, "TOPLEFT", width, 0)
                right:SetText(line.right)
                local used = stringWidth(right)
                if used and label.SetWidth then label:SetWidth(math.max(width * 0.4, width - used - 8)) end
                if right.SetTextColor then right:SetTextColor(unpack(line.rightColor or { 1, 1, 1 })) end
                right:Show()
            end
            self.lines[i] = label
        end
    end
    return panel
end

function Widgets.cards(parent, onSelect, width)
    width = width or 420
    local panel = frame("Frame", nil, parent)
    panel:SetSize(width, 6 * 60 - 4)
    panel.items, panel.onSelect = {}, onSelect
    local function makeCard(index)
        local button = frame("Button", nil, panel)
        button:SetSize(width, 56)
        button.fill = button:CreateTexture(nil, "BACKGROUND")
        button.fill:SetAllPoints()
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(32, 32)
        button.icon:SetPoint("LEFT", button, "LEFT", 10, 0)
        cropIcon(button.icon)
        hoverGlow(button)
        button.title = text(button, "", 13, { 0.92, 0.86, 0.72 })
        button.reason = text(button, "", 11, { 0.64, 0.58, 0.49 })
        button.amount = text(button, "", 13)
        button.confidence = text(button, "", 10, { 0.64, 0.58, 0.49 })
        button.band = button:CreateTexture(nil, "OVERLAY")
        button.band:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.band:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        if button.band.SetWidth then button.band:SetWidth(3) end
        panel.items[index] = button
        button:SetScript("OnClick", function(self)
            if inCombat() then return end
            panel.selectedKey = self.data.key
            panel:setCards(panel.data)
            if panel.onSelect then panel.onSelect(self.data) end
        end)
        return button
    end
    function panel:setCards(list)
        if inCombat() then return false end
        self.data = list or {}
        for i = 1, math.min(#self.data, 6) do
            local data = self.data[i]
            local button = self.items[i] or makeCard(i)
            button:SetSize(width, 56)
            if button.ClearAllPoints then button:ClearAllPoints() end
            button:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(i - 1) * 60)
            button.data = data
            button.fill:SetColorTexture(data.key == self.selectedKey and 0.2 or 0.04,
                data.key == self.selectedKey and 0.15 or 0.03,
                data.key == self.selectedKey and 0.08 or 0.02,
                data.key == self.selectedKey and 0.9 or 0.75)
            button.band:SetColorTexture(unpack(data.accent or { 0.6, 0.6, 0.6 }))
            button.icon:SetTexture(data.icon or "")
            button.title:SetText(data.title or "")
            button.reason:SetText(data.reason or "")
            button.amount:SetText(data.right or "")
            if button.amount.SetTextColor then button.amount:SetTextColor(unpack(data.rightColor or { 1, 1, 1 })) end
            button.confidence:SetText(data.confidence or "")
            local textWidth = math.max(40, width - 52 - 120)
            for _, label in ipairs({ button.title, button.reason }) do
                if label.ClearAllPoints then label:ClearAllPoints() end
                label:SetPoint("TOPLEFT", button, "TOPLEFT", 52, label == button.title and -8 or -31)
                local used = stringWidth(label == button.title and button.amount or button.confidence)
                if label.SetWidth then label:SetWidth(used and math.max(40, width - 72 - used) or textWidth) end
                if label.SetJustifyH then label:SetJustifyH("LEFT") end
            end
            if button.amount.ClearAllPoints then button.amount:ClearAllPoints() end
            button.amount:SetPoint("TOPRIGHT", button, "TOPRIGHT", -10, -10)
            if button.confidence.ClearAllPoints then button.confidence:ClearAllPoints() end
            button.confidence:SetPoint("TOPRIGHT", button, "TOPRIGHT", -10, -31)
            if button.reason.SetWordWrap then button.reason:SetWordWrap(false) end
            if button.title.SetWordWrap then button.title:SetWordWrap(false) end
            button:Show()
        end
        for i = math.min(#self.data, 6) + 1, #self.items do self.items[i]:Hide() end
        return true
    end
    return panel
end

-- Tarjetas de métricas: valor grande y etiqueta debajo.
function Widgets.metrics(parent, values)
    local strip = frame("Frame", nil, parent)
    strip:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 16, 16)
    strip:SetSize(664, 50)
    strip.items = {}
    local function card(index)
        local item = frame("Frame", nil, strip)
        local fill = item:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(0.04, 0.03, 0.02, 0.75)
        local edge = item:CreateTexture(nil, "BORDER")
        edge:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
        edge:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
        edge:SetSize(10, 1)
        edge:SetColorTexture(0.35, 0.27, 0.19, 1)
        item.value = text(item, "", 15, { 1, 1, 1 })
        item.value:SetPoint("TOP", item, "TOP", 0, -8)
        item.label = text(item, "", 11, { 0.64, 0.58, 0.49 })
        item.label:SetPoint("BOTTOM", item, "BOTTOM", 0, 7)
        strip.items[index] = item
        return item
    end
    function strip:setItems(items)
        if inCombat() then return false end
        items = items or {}
        local gap, total = 8, self.contentWidth or 664
        local width = (total - gap * math.max(0, #items - 1)) / math.max(1, #items)
        for i, data in ipairs(items) do
            local item = self.items[i] or card(i)
            item:SetSize(width, 50)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", self, "TOPLEFT", (i - 1) * (width + gap), 0)
            item.value:SetText(data.value or "")
            item.label:SetText(data.label or "")
            if item.value.SetTextColor then item.value:SetTextColor(unpack(data.color or { 1, 1, 1 })) end
            item:Show()
        end
        for i = #items + 1, #self.items do self.items[i]:Hide() end
        return true
    end
    strip:setItems(values)
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
