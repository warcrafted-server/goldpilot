local _, addon = ...

local ZonesUI = {}
addon.ZonesUI = ZonesUI

local GREEN, GRAY = { 0.35, 0.9, 0.4 }, { 0.65, 0.65, 0.65 }
local GOLD, MUTED, SOFT = { 1, 0.82, 0.2 }, { 0.55, 0.5, 0.42 }, { 0.78, 0.72, 0.55 }
local VIEWS = { "zones", "sessions" }
local KINDS = { "all", "herb", "ore" }
local ROUTE_KIND = { all = nil, herb = "herb", ore = "ore" }
local MEASURED = 300

local function combat()
    return InCombatLockdown and InCombatLockdown()
end

local function visible()
    return addon.Main and addon.Main.frame and addon.Main.frame.IsShown and addon.Main.frame:IsShown()
end

local function currentTime()
    local ok, value = addon.Compat.call("time")
    return ok and tonumber(value) or 0
end

local function viewLabel(view)
    return view == "sessions" and addon.L.ZONES_VIEW_SESSIONS or addon.L.ZONES_VIEW_ZONES
end

local function kindLabel(kind)
    if kind == "herb" then return addon.L.ZONES_KIND_HERB end
    if kind == "ore" then return addon.L.ZONES_KIND_ORE end
    return addon.L.ZONES_KIND_ALL
end

local function shortDate(session)
    local stamp = tonumber(session.stop) or tonumber(session.start) or 0
    local ok, value = addon.Compat.call("date", "%d/%m", stamp)
    if ok and type(value) == "string" and value ~= "" then return value end
    return tostring(stamp)
end

local function mainZone(session)
    local bestID, bestActive
    for id, map in pairs(session.maps or {}) do
        local active = tonumber(map.active) or 0
        if not bestActive or active > bestActive then bestID, bestActive = tonumber(id), active end
    end
    if bestID then return addon.RoutePlan.mapName(bestID) end
    return addon.L.ZONES_NO_ZONE
end

local function minutes(seconds)
    return math.floor((tonumber(seconds) or 0) / 60)
end

local function sessionValue(session, now)
    return addon.Sessions.value(GoldPilotDB or {}, addon.AuctionHouse.houseKey(),
        { coin = session.coin, items = session.items }, now, addon.ItemData.auctionable)
end

local function section(lines, label)
    lines[#lines + 1] = { text = label, color = MUTED, size = 11, gap = 10 }
end

local function addLine(lines, label, right, rightColor)
    lines[#lines + 1] = { text = label, right = right, color = SOFT, rightColor = rightColor }
end

function ZonesUI:routeMatches()
    local plan = addon.RoutePlan and addon.RoutePlan.active
    if not plan or not plan.route then return false end
    return plan.mapID == self.selectedMap and plan.kind == ROUTE_KIND[self.kind]
end

function ZonesUI:routeLines(lines, mapID)
    local L = addon.L
    local plan = addon.RoutePlan and addon.RoutePlan.active
    if plan and plan.mapID == mapID and plan.route then
        section(lines, L.ZONES_ROUTE)
        addLine(lines, string.format(L.ZONES_ROUTE_STOPS, #plan.route.stops))
        addLine(lines, string.format(L.ZONES_ROUTE_POINTS, tonumber(plan.route.points) or 0))
        if plan.yards then addLine(lines, string.format(L.ZONES_ROUTE_YARDS, plan.yards)) end
        local follow = addon.RouteFollow
        if follow and follow.plan == plan and follow.next then
            addLine(lines, string.format(L.ZONES_ROUTE_NEXT, follow.next, #plan.route.stops))
        end
        local visits, hits = addon.Visits.totals(GoldPilotDB or {}, plan.mapID, plan.kind)
        if visits > 0 then addLine(lines, string.format(L.ZONES_ROUTE_VISITS, hits, visits)) end
        addLine(lines, string.format(L.ZONES_ROUTE_OWN, (plan.stats and plan.stats.own) or 0,
            (plan.stats and plan.stats.seed) or 0))
        addLine(lines, string.format(L.ZONES_ROUTE_SKIP, (plan.stats and plan.stats.skill) or 0,
            (plan.stats and plan.stats.unpriced) or 0))
        lines[#lines + 1] = { text = L.ZONES_ROUTE_NOTE, color = MUTED, size = 11, gap = 6 }
        if plan.skills and plan.skills.known == false then
            lines[#lines + 1] = { text = L.ZONES_NO_SKILL, color = SOFT, size = 11 }
        end
        return
    end
    local last = self.lastPlan
    if last and last.mapID == mapID then
        section(lines, L.ZONES_ROUTE)
        if last.route then
            addLine(lines, string.format(L.ZONES_ROUTE_STOPS, #last.route.stops))
            addLine(lines, string.format(L.ZONES_ROUTE_POINTS, tonumber(last.route.points) or 0))
            if last.yards then addLine(lines, string.format(L.ZONES_ROUTE_YARDS, last.yards)) end
        else
            lines[#lines + 1] = { text = L.ZONES_NO_ROUTE, color = SOFT, size = 11 }
        end
        if last.skills and last.skills.known == false then
            lines[#lines + 1] = { text = L.ZONES_NO_SKILL, color = SOFT, size = 11 }
        end
    end
end

function ZonesUI:zoneDetail(row)
    local L, lines = addon.L, {}
    lines[#lines + 1] = { text = addon.RoutePlan.mapName(row.mapID), size = 14, color = GOLD }
    local zone = row.zone
    if zone and zone.active >= MEASURED and zone.rate then
        addLine(lines, L.ZONES_MEASURED, addon.Theme.money(zone.rate) .. L.NOW_PER_HOUR, GREEN)
        addLine(lines, L.ZONES_ACTIVE, string.format(L.ZONES_ACTIVE_MIN, minutes(zone.active)))
        addLine(lines, L.ZONES_METRIC_SESSIONS, tostring(zone.sessions))
    else
        lines[#lines + 1] = { text = L.ZONES_NO_DATA, color = SOFT, size = 12, gap = 6 }
    end
    if zone and #zone.rows > 0 then
        section(lines, L.NOW_TOP)
        for index = 1, math.min(5, #zone.rows) do
            local item = zone.rows[index]
            local name = addon.InventoryUI.itemName(item.itemID, item.key)
            addLine(lines, name .. " ×" .. tostring(item.qty),
                item.value > 0 and addon.Theme.money(item.value) or L.INVENTORY_NO_PRICE)
        end
    end
    self:routeLines(lines, row.mapID)
    return lines
end

function ZonesUI:sessionDetail(entry, now)
    local L, session, lines = addon.L, entry.session, {}
    lines[#lines + 1] = { text = shortDate(session) .. " · " .. mainZone(session), size = 14, color = GOLD }
    if entry.current then lines[#lines + 1] = { text = L.ZONES_ONGOING, color = GREEN, size = 11 } end
    local value = sessionValue(session, now)
    local active = entry.current and addon.Sessions.active(session, now) or (tonumber(session.active) or 0)
    addLine(lines, L.ZONES_SESSION_CHAR, tostring(session.char or "unknown"))
    addLine(lines, L.ZONES_ACTIVE, string.format(L.ZONES_ACTIVE_MIN, minutes(active)))
    addLine(lines, L.ZONES_SESSION_TOTAL, addon.Theme.money(value.total))
    local rate = addon.Sessions.rate(value.total, active)
    addLine(lines, L.ZONES_SESSION_RATE, rate and addon.Theme.money(rate) .. L.NOW_PER_HOUR or L.ZONES_NONE)
    addLine(lines, L.ZONES_SESSION_COIN, addon.Theme.money(value.coin))
    addLine(lines, L.ZONES_SESSION_NODES, tostring(tonumber(session.nodes) or 0))
    if #value.rows > 0 then
        section(lines, L.NOW_TOP)
        for index = 1, math.min(8, #value.rows) do
            local item = value.rows[index]
            local name = addon.InventoryUI.itemName(item.itemID, item.key)
            addLine(lines, name .. " ×" .. tostring(item.qty),
                item.value > 0 and addon.Theme.money(item.value) or L.INVENTORY_NO_PRICE)
        end
    end
    if value.unpriced > 0 then
        lines[#lines + 1] = { text = string.format(L.ZONES_UNPRICED, value.unpriced), color = GRAY, size = 11 }
    end
    return lines
end

function ZonesUI:zoneRows(now)
    local db = GoldPilotDB or {}
    local zones = addon.Sessions.zones(db, addon.AuctionHouse.houseKey(), now,
        { minActive = 1, current = GoldPilotCharDB and GoldPilotCharDB.session })
    local zoneByMap = {}
    for _, zone in ipairs(zones) do zoneByMap[zone.mapID] = zone end
    local currentMap = addon.RoutePlan.currentMap()
    local order, seen = {}, {}
    local function push(id)
        id = tonumber(id)
        if id and id > 0 and not seen[id] then
            seen[id] = true
            order[#order + 1] = id
        end
    end
    push(currentMap)
    for _, zone in ipairs(zones) do push(zone.mapID) end
    local nodeMaps = {}
    for key in pairs(db.nodes or {}) do
        local id = tonumber(key)
        if id then nodeMaps[#nodeMaps + 1] = id end
    end
    table.sort(nodeMaps)
    for _, id in ipairs(nodeMaps) do push(id) end
    local rows = {}
    for _, id in ipairs(order) do
        local zone, here = zoneByMap[id], id == currentMap
        local text = addon.RoutePlan.mapName(id)
        if here then text = text .. addon.L.ZONES_HERE end
        local right, color = addon.L.ZONES_UNMEASURED, GRAY
        if zone and zone.active >= MEASURED and zone.rate then
            right, color = addon.Theme.money(zone.rate) .. addon.L.NOW_PER_HOUR, GREEN
        end
        rows[#rows + 1] = { key = id, mapID = id, text = text, right = right, rightColor = color,
            zone = zone, here = here }
    end
    return rows, zones
end

function ZonesUI:sessionRows(now)
    local db = GoldPilotDB or {}
    local entries = {}
    local current = GoldPilotCharDB and GoldPilotCharDB.session
    if current then entries[#entries + 1] = { session = current, current = true } end
    local saved = {}
    for _, session in ipairs(db.sessions or {}) do saved[#saved + 1] = session end
    table.sort(saved, function(a, b)
        local av = tonumber(a.stop) or tonumber(a.start) or 0
        local bv = tonumber(b.stop) or tonumber(b.start) or 0
        if av ~= bv then return av > bv end
        return tostring(a.char) < tostring(b.char)
    end)
    for _, session in ipairs(saved) do entries[#entries + 1] = { session = session } end
    local rows = {}
    for index, entry in ipairs(entries) do
        local value = sessionValue(entry.session, now)
        local text = shortDate(entry.session) .. " · " .. mainZone(entry.session)
        if entry.current then text = addon.L.ZONES_ONGOING .. " · " .. text end
        rows[#rows + 1] = { key = index, text = text, right = addon.Theme.money(value.total),
            rightColor = GREEN, entry = entry }
    end
    return rows, entries
end

function ZonesUI:metrics(zones, now)
    local L, db = addon.L, GoldPilotDB or {}
    local best
    for _, zone in ipairs(zones) do
        if zone.active >= MEASURED and zone.rate and (not best or zone.rate > best.rate) then best = zone end
    end
    local saved, active, nodes = db.sessions or {}, 0, 0
    for _, session in ipairs(saved) do
        active = active + (tonumber(session.active) or 0)
        nodes = nodes + (tonumber(session.nodes) or 0)
    end
    local current = GoldPilotCharDB and GoldPilotCharDB.session
    if current then
        active = active + addon.Sessions.active(current, now)
        nodes = nodes + (tonumber(current.nodes) or 0)
    end
    self.widgets.metrics:setItems({
        { label = L.ZONES_METRIC_RATE,
            value = best and addon.Theme.money(best.rate) .. L.NOW_PER_HOUR or L.ZONES_NONE, color = GREEN },
        { label = L.ZONES_METRIC_SESSIONS, value = tostring(#saved) },
        { label = L.ZONES_METRIC_MINUTES, value = tostring(minutes(active)) },
        { label = L.ZONES_METRIC_NODES, value = tostring(nodes) },
    })
end

function ZonesUI:refresh()
    if combat() or not visible() or not self.page or addon.Main.activeTab ~= "zones" then return false end
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotCharDB = GoldPilotCharDB or {}
    if GoldPilotCharDB.zonesView == nil then GoldPilotCharDB.zonesView = "zones" end
    if GoldPilotCharDB.routeKind == nil then GoldPilotCharDB.routeKind = "all" end
    self.view = GoldPilotCharDB.zonesView == "sessions" and "sessions" or "zones"
    local routeKind = GoldPilotCharDB.routeKind
    self.kind = (routeKind == "herb" or routeKind == "ore") and routeKind or "all"
    local now = currentTime()
    self.viewButton:SetText(viewLabel(self.view))
    self.kindButton:SetText(kindLabel(self.kind))
    self.routeButton:SetText(self:routeMatches() and addon.L.ZONES_CLEAR_ROUTE or addon.L.ZONES_CREATE_ROUTE)
    if self.view == "sessions" then
        self.kindButton:Hide()
        self.routeButton:Hide()
        local rows, entries = self:sessionRows(now)
        local selected
        for _, entry in ipairs(entries) do
            if entry.session == self.selectedSession then selected = entry end
        end
        if not selected then
            selected = entries[1]
            self.selectedSession = selected and selected.session or nil
        end
        self.widgets.list.selected = nil
        for _, row in ipairs(rows) do
            if row.entry == selected then self.widgets.list.selected = row.key end
        end
        self.widgets.list:setRows(rows)
        local _, zones = self:zoneRows(now)
        self:metrics(zones, now)
        if #rows == 0 then
            self.page.emptyText:SetText(addon.L.ZONES_NO_SESSIONS)
            self.page.emptyText:Show()
            self.widgets.detail:setLines({ { text = addon.L.ZONES_NO_SESSIONS, color = GRAY } })
        else
            self.page.emptyText:Hide()
            if selected then
                self.widgets.detail:setLines(self:sessionDetail(selected, now))
            else
                self.widgets.detail:setLines({ { text = addon.L.ZONES_PICK_SESSION, color = GRAY } })
            end
        end
        return true
    end
    self.kindButton:Show()
    self.routeButton:Show()
    local rows, zones = self:zoneRows(now)
    local selected
    for _, row in ipairs(rows) do
        if row.mapID == self.selectedMap then selected = row end
    end
    if not selected then
        selected = rows[1]
        self.selectedMap = selected and selected.mapID or nil
    end
    self.widgets.list.selected = self.selectedMap
    self.widgets.list:setRows(rows)
    self:metrics(zones, now)
    if #rows == 0 then
        self.page.emptyText:SetText(addon.L.ZONES_EMPTY)
        self.page.emptyText:Show()
        self.widgets.detail:setLines({ { text = addon.L.ZONES_EMPTY, color = GRAY } })
    else
        self.page.emptyText:Hide()
        if selected then
            self.widgets.detail:setLines(self:zoneDetail(selected))
        else
            self.widgets.detail:setLines({ { text = addon.L.ZONES_PICK, color = GRAY } })
        end
    end
    return true
end

function ZonesUI:createRoute()
    if combat() or self.view ~= "zones" or not self.selectedMap then return false end
    local plan = addon.RoutePlan.compute(self.selectedMap, ROUTE_KIND[self.kind])
    self.lastPlan = plan
    if not plan.route then
        addon.RoutePlan:clear()
        return self:refresh()
    end
    addon.RoutePlan:show(plan)
    if addon.RouteMap then addon.RouteMap:open(plan.mapID) end
    return self:refresh()
end

function ZonesUI:toggleRoute()
    if combat() or self.view ~= "zones" or not self.selectedMap then return false end
    if self:routeMatches() then
        self.lastPlan = nil
        addon.RoutePlan:clear()
        return self:refresh()
    end
    return self:createRoute()
end

function ZonesUI:build(page)
    if self.page == page and page._zonesBuilt then return self:refresh() end
    self.page, page._zonesBuilt = page, true
    self.widgets = { list = addon.Widgets.list(page, nil, 372), detail = addon.Widgets.detail(page),
        metrics = addon.Widgets.metrics(page, {}) }
    self.widgets.list:ClearAllPoints()
    self.widgets.list:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -108)
    self.widgets.list:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 20, 20)
    self.widgets.list:SetWidth(372)
    self.widgets.detail:ClearAllPoints()
    self.widgets.detail:SetPoint("TOPLEFT", page, "TOPLEFT", 424, -104)
    self.widgets.detail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -14, 16)
    self.widgets.detail.contentWidth = 298
    self.widgets.metrics:ClearAllPoints()
    self.widgets.metrics:SetPoint("TOPLEFT", page, "TOPLEFT", 76, -12)
    self.widgets.metrics.contentWidth = 668
    local list = self.widgets.list
    local background = addon.Widgets.panel(page, list.GetFrameLevel and list:GetFrameLevel() - 1)
    background:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -104)
    background:SetPoint("BOTTOMRIGHT", page, "BOTTOMLEFT", 418, 16)
    page.emptyText = background:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    page.emptyText:SetPoint("CENTER", background, "CENTER", 0, 0)
    if page.emptyText.SetWidth then page.emptyText:SetWidth(340) end
    page.emptyText:Hide()
    self.viewButton = addon.Widgets.selector(page, 150)
    self.viewButton:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -72)
    self.viewButton:SetScript("OnClick", function()
        if combat() then return end
        GoldPilotCharDB = GoldPilotCharDB or {}
        local index = GoldPilotCharDB.zonesView == "sessions" and 2 or 1
        GoldPilotCharDB.zonesView = VIEWS[index % #VIEWS + 1]
        self:refresh()
    end)
    self.kindButton = addon.Widgets.selector(page, 170)
    self.kindButton:SetPoint("TOPLEFT", page, "TOPLEFT", 176, -72)
    self.kindButton:SetScript("OnClick", function()
        if combat() then return end
        GoldPilotCharDB = GoldPilotCharDB or {}
        local current = GoldPilotCharDB.routeKind
        local index = current == "herb" and 2 or current == "ore" and 3 or 1
        GoldPilotCharDB.routeKind = KINDS[index % #KINDS + 1]
        self:refresh()
    end)
    self.routeButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    self.routeButton:SetSize(150, 24)
    self.routeButton:SetPoint("TOPLEFT", page, "TOPLEFT", 356, -72)
    self.routeButton:SetScript("OnClick", function()
        if combat() then return end
        self:toggleRoute()
    end)
    self.widgets.list.onSelect = function(row)
        if combat() then return end
        if self.view == "sessions" then
            self.selectedSession = row.entry and row.entry.session or nil
        else
            self.selectedMap = row.mapID
        end
        self:refresh()
    end
    return self:refresh()
end

addon.Main:registerTab("zones", function(page) ZonesUI:build(page) end, addon.L.TAB_ZONES)

addon.Modules:register("zones-ui", { onEnable = function()
    local delays = { GET_ITEM_INFO_RECEIVED = 0.1 }
    for _, event in ipairs({ "GET_ITEM_INFO_RECEIVED", "ZONE_CHANGED_NEW_AREA" }) do
        addon.Events:subscribe("zones-ui", event, function()
            if visible() and addon.Main.activeTab == "zones" then ZonesUI:refresh() end
        end, delays[event])
    end
end })

return ZonesUI
