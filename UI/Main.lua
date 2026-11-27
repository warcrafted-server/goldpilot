local _, addon = ...

addon.Main = { tabs = {}, tabOrder = {}, registeredTabs = {} }
local Main = addon.Main

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function window()
    GoldPilotCharDB = GoldPilotCharDB or {}
    GoldPilotCharDB.window = GoldPilotCharDB.window or {}
    return GoldPilotCharDB.window
end

local function setPoint(frame, saved)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(saved.x) or 0, tonumber(saved.y) or 0)
end

local function buildWindow()
    if Main.frame then return Main.frame end
    local frame = addon.Widgets.window("GoldPilotMainFrame", addon.L.WINDOW_TITLE, 760, 520)
    Main.frame = frame
    local saved = window()
    setPoint(frame, saved)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local centerX, centerY = UIParent:GetCenter()
        if x and y and centerX and centerY then saved.x, saved.y = x - centerX, y - centerY end
    end)
    if type(UISpecialFrames) ~= "table" then UISpecialFrames = {} end
    local registered
    for _, name in ipairs(UISpecialFrames) do if name == "GoldPilotMainFrame" then registered = true end end
    if not registered then UISpecialFrames[#UISpecialFrames + 1] = "GoldPilotMainFrame" end

    local pages = {}
    local function showTab(name)
        if inCombat() then return end
        Main.activeTab = name
        for tabName, page in pairs(pages) do
            if tabName == name then page:Show() else page:Hide() end
        end
        local builder = Main.tabs[name]
        if builder then builder(pages[name], frame) end
    end
    Main.tabsBar = addon.Widgets.tabs(frame, showTab)
    Main.pages = pages
    Main.selectTab = showTab

    local function addPage(name, label, builder)
        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -24)
        page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        page:Hide()
        pages[name] = page
        Main.tabs[name] = builder
        Main.tabsBar:add(name, label)
        Main.tabOrder[#Main.tabOrder + 1] = name
    end

    addPage("now", addon.L.TAB_NOW or "now", Main.tabs.now or function() end)
    addPage("inventory", addon.L.TAB_INVENTORY, Main.tabs.inventory or function(page)
        local label = page.placeholder
        if not label then
            label = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetPoint("CENTER", page, "CENTER", 0, 0)
            page.placeholder = label
        end
        label:SetText(addon.L.COMING_SOON)
    end)
    addPage("ledger", addon.L.TAB_LEDGER, Main.tabs.ledger or function() end)
    for _, tab in ipairs(Main.registeredTabs) do
        if tab.name == "trading" then addPage(tab.name, tab.label or tab.name, tab.builder) end
    end
    addPage("zones", addon.L.TAB_ZONES or "zones", Main.tabs.zones or function() end)
    addPage("settings", addon.L.TAB_SETTINGS, function(page)
        local function sync()
            for key, box in pairs(page.checkboxes or {}) do
                box:SetChecked(addon.Settings.get(key) == true)
            end
        end
        if not page.checkboxes then
            page.checkboxes = {}
            local function column(left, right)
                local panel = addon.Widgets.panel(page, page.GetFrameLevel and page:GetFrameLevel())
                panel:SetPoint("TOPLEFT", page, "TOPLEFT", left, -52)
                panel:SetPoint("BOTTOMRIGHT", page, "BOTTOMLEFT", right, 16)
                return panel
            end
            local function fill(panel, sections, x)
                local y = -16
                for _, section in ipairs(sections) do
                    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, y)
                    title:SetText(addon.L["SETTING_" .. string.upper(section)])
                    y = y - 24
                    for _, definition in ipairs(addon.Settings.list(section)) do
                        local box = addon.Widgets.checkbox(page, addon.L[definition.label],
                            addon.Settings.get(definition.key) == true, function(checked)
                                if inCombat() then return end
                                addon.Settings.set(definition.key, checked)
                            end)
                        box:SetPoint("TOPLEFT", page, "TOPLEFT", x, y - 52)
                        page.checkboxes[definition.key] = box
                        y = y - 32
                    end
                    y = y - 16
                end
            end
            local leftSections, rightSections = {}, {}
            for _, section in ipairs(addon.Settings.sections()) do
                if section == "fields" then rightSections[#rightSections + 1] = section
                else leftSections[#leftSections + 1] = section end
            end
            fill(column(14, 376), leftSections, 24)
            fill(column(384, 746), rightSections, 394)
        end
        sync()
    end)
    for _, tab in ipairs(Main.registeredTabs) do
        if tab.name ~= "inventory" and tab.name ~= "now" and tab.name ~= "ledger" and
            tab.name ~= "trading" and tab.name ~= "zones" then
            addPage(tab.name, tab.label or tab.name, tab.builder)
        end
    end

    Main.widgets = {
        list = addon.Widgets.list(frame),
        detail = addon.Widgets.detail(frame),
        metrics = addon.Widgets.metrics(frame, {}),
    }
    Main.widgets.list:Hide()
    Main.widgets.detail:Hide()
    Main.widgets.metrics:Hide()
    Main.tabsBar:select("now")
    frame:Hide()
    return frame
end

function Main:registerTab(name, builder, label)
    if type(name) ~= "string" or type(builder) ~= "function" then return false end
    self.tabs[name] = builder
    local found = false
    for _, tab in ipairs(self.registeredTabs) do
        if tab.name == name then
            tab.builder = builder
            if label ~= nil then tab.label = label end
            found = true
        end
    end
    if not found then self.registeredTabs[#self.registeredTabs + 1] = { name = name, builder = builder, label = label } end
    if self.frame and not self.pages[name] then
        local page = CreateFrame("Frame", nil, self.frame)
        page:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -24)
        page:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)
        page:Hide()
        self.pages[name] = page
        self.tabsBar:add(name, label or name)
        self.tabOrder[#self.tabOrder + 1] = name
    end
    return true
end

function Main:show()
    if inCombat() then addon.Log:info(addon.L.COMBAT_BLOCKED); return false end
    local frame = buildWindow()
    frame:Show()
    if self.tabsBar then self.tabsBar:select(self.activeTab or "now") end
    return true
end

function Main:hide()
    if self.frame then self.frame:Hide() end
end

function Main:toggle()
    if inCombat() then addon.Log:info(addon.L.COMBAT_BLOCKED); return false end
    local frame = buildWindow()
    if frame.IsShown and frame:IsShown() then frame:Hide(); return true end
    return self:show()
end
