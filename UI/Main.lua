local _, addon = ...

addon.Main = { tabs = {}, tabOrder = {}, registeredTabs = {} }
local Main = addon.Main

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function settings()
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.settings = GoldPilotDB.settings or {}
    if GoldPilotDB.settings.tooltip == nil then GoldPilotDB.settings.tooltip = true end
    if GoldPilotDB.settings.routeWaypoint == nil then GoldPilotDB.settings.routeWaypoint = true end
    GoldPilotDB.settings.minimap = GoldPilotDB.settings.minimap or { hidden = false }
    if GoldPilotDB.settings.minimap.hidden == nil then GoldPilotDB.settings.minimap.hidden = false end
    GoldPilotCharDB = GoldPilotCharDB or {}
    GoldPilotCharDB.window = GoldPilotCharDB.window or {}
    return GoldPilotDB.settings, GoldPilotCharDB.window
end

local function setPoint(frame, saved)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(saved.x) or 0, tonumber(saved.y) or 0)
end

local function buildWindow()
    if Main.frame then return Main.frame end
    local frame = addon.Widgets.window("GoldPilotMainFrame", addon.L.WINDOW_TITLE, 760, 520)
    Main.frame = frame
    local _, saved = settings()
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
    addPage("zones", addon.L.TAB_ZONES or "zones", Main.tabs.zones or function() end)
    addPage("settings", addon.L.TAB_SETTINGS, function(page)
        local dbSettings = settings()
        if not page.minimapCheckbox then
            local function column(left, right)
                local panel = addon.Widgets.panel(page, page.GetFrameLevel and page:GetFrameLevel())
                panel:SetPoint("TOPLEFT", page, "TOPLEFT", left, -52)
                panel:SetPoint("BOTTOMRIGHT", page, "BOTTOMLEFT", right, 16)
                return panel
            end
            local function heading(panel, y, label)
                local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, y)
                title:SetText(label)
            end
            local left, right = column(14, 376), column(384, 746)
            heading(left, -16, addon.L.SETTING_GENERAL)
            heading(left, -132, addon.L.SETTING_GATHERING)
            heading(right, -16, addon.L.SETTING_FIELDS)
            page.minimapCheckbox = addon.Widgets.checkbox(page, addon.L.SETTING_MINIMAP,
                not dbSettings.minimap.hidden, function(checked)
                    if inCombat() then return end
                    dbSettings.minimap.hidden = not checked
                    if addon.Minimap and addon.Minimap.setVisible then addon.Minimap:setVisible(checked) end
                end)
            page.minimapCheckbox:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -92)
            page.tooltipCheckbox = addon.Widgets.checkbox(page, addon.L.SETTING_TOOLTIP,
                dbSettings.tooltip ~= false, function(checked)
                    if inCombat() then return end
                    dbSettings.tooltip = checked
                end)
            page.tooltipCheckbox:SetPoint("TOPLEFT", page, "TOPLEFT", 394, -92)
            page.fieldCheckboxes = {}
            dbSettings.tooltipFields = dbSettings.tooltipFields or {}
            for i, field in ipairs({ "vendor", "last", "median", "advice" }) do
                local box = addon.Widgets.checkbox(page, addon.L["SETTING_FIELD_" .. string.upper(field)],
                    dbSettings.tooltipFields[field] ~= false, function(checked)
                        if inCombat() then return end
                        dbSettings.tooltipFields[field] = checked
                    end)
                box:SetPoint("TOPLEFT", page, "TOPLEFT", 412, -128 - (i - 1) * 32)
                page.fieldCheckboxes[field] = box
            end
            page.scanCheckbox = addon.Widgets.checkbox(page, addon.L.SETTING_FULLSCAN,
                dbSettings.fullScan ~= false, function(checked)
                    if inCombat() then return end
                    dbSettings.fullScan = checked
                end)
            page.scanCheckbox:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -128)
            page.hudCheckbox = addon.Widgets.checkbox(page, addon.L.SETTING_HUD,
                dbSettings.hud ~= false, function(checked)
                    if inCombat() then return end
                    if addon.SessionHUD then addon.SessionHUD:setEnabled(checked)
                    else dbSettings.hud = checked end
                end)
            page.hudCheckbox:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -208)
            page.waypointCheckbox = addon.Widgets.checkbox(page, addon.L.SETTING_WAYPOINT,
                dbSettings.routeWaypoint ~= false, function(checked)
                    if inCombat() then return end
                    dbSettings.routeWaypoint = checked
                    if addon.RouteFollow and addon.RouteFollow.setWaypoint then
                        addon.RouteFollow:setWaypoint(checked)
                    end
                end)
            page.waypointCheckbox:SetPoint("TOPLEFT", page, "TOPLEFT", 24, -244)
        else
            page.minimapCheckbox:SetChecked(not dbSettings.minimap.hidden)
            page.tooltipCheckbox:SetChecked(dbSettings.tooltip ~= false)
            for field, box in pairs(page.fieldCheckboxes) do
                box:SetChecked((dbSettings.tooltipFields or {})[field] ~= false)
            end
            page.scanCheckbox:SetChecked(dbSettings.fullScan ~= false)
            page.hudCheckbox:SetChecked(dbSettings.hud ~= false)
            page.waypointCheckbox:SetChecked(dbSettings.routeWaypoint ~= false)
        end
    end)
    for _, tab in ipairs(Main.registeredTabs) do
        if tab.name ~= "inventory" and tab.name ~= "now" and tab.name ~= "ledger" and tab.name ~= "zones" then
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
