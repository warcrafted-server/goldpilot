local _, addon = ...

local RouteMap = { pending = false, lines = {}, dots = {}, labels = {} }
addon.RouteMap = RouteMap

local PIN_LEVEL = "PIN_FRAME_LEVEL_MAP_HIGHLIGHT"
local FALLBACK_LEVEL = 2200
local RETRY_DELAY = 0.2

local function combat()
    return InCombatLockdown and InCombatLockdown()
end

local function call(object, method, ...)
    if not object then return nil end
    local fn = object[method]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, object, ...)
    if not ok then return nil end
    return value
end

local function canvasScale()
    local value = tonumber(call(WorldMapFrame, "GetCanvasScale"))
    if value and value > 0 then return value end
    return 1
end

local function pinLevel()
    local manager = call(WorldMapFrame, "GetPinFrameLevelsManager")
    local value = tonumber(call(manager, "GetValidFrameLevel", PIN_LEVEL))
    if value and value > 0 then return value + 1 end
    return FALLBACK_LEVEL
end

local function mapRect(shown, planMap)
    if not shown or not planMap then return nil end
    if shown == planMap then return { 0, 1, 0, 1 } end
    local ok, minX, maxX, minY, maxY = addon.Compat.call("C_Map.GetMapRectOnMap", planMap, shown)
    if not ok then return nil end
    if type(minX) ~= "number" or type(maxX) ~= "number" or type(minY) ~= "number" or type(maxY) ~= "number" then
        return nil
    end
    if maxX - minX <= 0.02 or maxY - minY <= 0.02 then return nil end
    if minX < -0.01 or minY < -0.01 or maxX > 1.01 or maxY > 1.01 then return nil end
    return { minX, maxX, minY, maxY }
end

function RouteMap:available()
    if not WorldMapFrame then return false end
    return call(WorldMapFrame, "GetCanvas") ~= nil
end

function RouteMap:ensure()
    if self.frame then return self.frame end
    if not self:available() then return nil end
    local canvas = call(WorldMapFrame, "GetCanvas")
    if not canvas then return nil end
    local ok, frame = pcall(CreateFrame, "Frame", nil, canvas)
    if not ok or not frame then return nil end
    if frame.SetAllPoints then pcall(frame.SetAllPoints, frame, canvas) end
    if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
    local strata = call(canvas, "GetFrameStrata")
    if strata and frame.SetFrameStrata then pcall(frame.SetFrameStrata, frame, strata) end
    self.frame, self.canvas = frame, canvas
    return frame
end

function RouteMap:applyLevel()
    if not self.frame then return nil end
    local level = pinLevel()
    if self.frame.SetFrameLevel then pcall(self.frame.SetFrameLevel, self.frame, level) end
    self.level = level
    return level
end

local function canvasSize(self)
    local width = tonumber(call(self.canvas, "GetWidth")) or tonumber(call(self.frame, "GetWidth")) or 0
    local height = tonumber(call(self.canvas, "GetHeight")) or tonumber(call(self.frame, "GetHeight")) or 0
    return width, height
end

function RouteMap:scheduleRefresh(delay)
    if self.retryScheduled then return false end
    if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then return false end
    self.retryScheduled = true
    local ok = pcall(C_Timer.After, tonumber(delay) or RETRY_DELAY, function()
        RouteMap.retryScheduled = false
        RouteMap:refresh()
    end)
    if not ok then self.retryScheduled = false end
    return ok
end

function RouteMap:retryLater()
    if self.retried then return false end
    self.retried = true
    if self.retryScheduled then return false end
    if not self:scheduleRefresh(RETRY_DELAY) then
        self.retried = false
        return false
    end
    return true
end

function RouteMap:installHooks()
    if self.hooked or not WorldMapFrame then return end
    self.hooked = true
    local function hook(method)
        if type(WorldMapFrame[method]) ~= "function" or type(hooksecurefunc) ~= "function" then return end
        pcall(hooksecurefunc, WorldMapFrame, method, function() self:refresh() end)
    end
    hook("OnMapChanged")
    hook("OnCanvasScaleChanged")
    if WorldMapFrame.HookScript then
        pcall(WorldMapFrame.HookScript, WorldMapFrame, "OnShow", function() self:refresh() end)
    end
end

local function lineAt(self, index)
    local line = self.lines[index]
    if line then return line end
    local ok, created = pcall(self.frame.CreateLine, self.frame, nil, "ARTWORK")
    if not ok then self.lastError = tostring(created) end
    if not ok or not created then return nil end
    self.lines[index] = created
    return created
end

local function dotAt(self, index)
    local dot = self.dots[index]
    if dot then return dot end
    local ok, created = pcall(self.frame.CreateTexture, self.frame, nil, "ARTWORK")
    if not ok then self.lastError = tostring(created) end
    if not ok or not created then return nil end
    self.dots[index] = created
    return created
end

local function paintDot(dot, marker)
    local texture = marker and "Interface/COMMON/Indicator-Green" or "Interface/COMMON/Indicator-Yellow"
    if dot.SetTexture then
        if pcall(dot.SetTexture, dot, texture) then return end
    end
    if dot.SetColorTexture then
        if marker then
            pcall(dot.SetColorTexture, dot, 0.3, 0.95, 0.4, 1)
        else
            pcall(dot.SetColorTexture, dot, 1, 0.82, 0.2, 0.9)
        end
    end
end

local function labelAt(self, index)
    local label = self.labels[index]
    if label then return label end
    local ok, created = pcall(self.frame.CreateFontString, self.frame, nil, "OVERLAY", "GameFontNormal")
    if not ok then self.lastError = tostring(created) end
    if not ok or not created then return nil end
    self.labels[index] = created
    return created
end

function RouteMap:hideAll()
    for _, line in ipairs(self.lines) do if line.Hide then line:Hide() end end
    for _, dot in ipairs(self.dots) do if dot.Hide then dot:Hide() end end
    for _, label in ipairs(self.labels) do if label.Hide then label:Hide() end end
    if self.frame and self.frame.Hide then self.frame:Hide() end
end

function RouteMap:draw(plan, rect, width, height)
    local frame = self.frame
    local multiplier = canvasScale()
    local minX, maxX, minY, maxY = rect[1], rect[2], rect[3], rect[4]
    local spanX, spanY = maxX - minX, maxY - minY
    -- Con mapas unidos, el anfitrión puede dejar la ruta en una franja estrecha:
    -- sin números y con puntos más pequeños sigue siendo legible.
    local labels = spanX >= 0.25
    local size, nextSize = labels and 14 or 8, labels and 20 or 12
    local stops = plan.route.stops or {}
    local count = #stops
    local follow = addon.RouteFollow
    local nextIndex = follow and follow.plan == plan and tonumber(follow.next) or nil
    for index = 1, count do
        local from, pointTo = stops[index], stops[index % count + 1]
        local fromX, fromY = minX + from.x * spanX, minY + from.y * spanY
        local toX, toY = minX + pointTo.x * spanX, minY + pointTo.y * spanY
        local line = lineAt(self, index)
        if not line then break end
        if line.SetColorTexture then pcall(line.SetColorTexture, line, 1, 0.82, 0.2, 0.85) end
        if line.SetThickness then pcall(line.SetThickness, line, 3 / multiplier) end
        if line.SetStartPoint then
            local ok, err = pcall(line.SetStartPoint, line, "TOPLEFT", frame, fromX * width, -fromY * height)
            if not ok then self.lastError = tostring(err) end
        end
        if line.SetEndPoint then
            local ok, err = pcall(line.SetEndPoint, line, "TOPLEFT", frame, toX * width, -toY * height)
            if not ok then self.lastError = tostring(err) end
        end
        if line.Show then line:Show() end

        local dot = dotAt(self, index)
        if dot then
            local marker = index == nextIndex
            paintDot(dot, marker)
            local sizeValue = marker and nextSize or size
            if dot.SetSize then pcall(dot.SetSize, dot, sizeValue / multiplier, sizeValue / multiplier) end
            if dot.SetPoint then pcall(dot.SetPoint, dot, "CENTER", frame, "TOPLEFT", fromX * width, -fromY * height) end
            if dot.Show then dot:Show() end
            if labels then
                local label = labelAt(self, index)
                if label then
                    if label.SetFont then pcall(label.SetFont, label, "Fonts/FRIZQT__.TTF", 11 / multiplier, "") end
                    if label.ClearAllPoints then pcall(label.ClearAllPoints, label) end
                    if label.SetPoint then pcall(label.SetPoint, label, "BOTTOM", dot, "TOP", 0, 1) end
                    if label.SetText then label:SetText(tostring(index)) end
                    if label.Show then label:Show() end
                end
            elseif self.labels[index] and self.labels[index].Hide then
                self.labels[index]:Hide()
            end
        end
    end
    for index = count + 1, #self.lines do if self.lines[index].Hide then self.lines[index]:Hide() end end
    for index = count + 1, #self.dots do if self.dots[index].Hide then self.dots[index]:Hide() end end
    for index = count + 1, #self.labels do if self.labels[index].Hide then self.labels[index]:Hide() end end
    return true
end

function RouteMap:refresh()
    local plan = addon.RoutePlan and addon.RoutePlan.active
    local shown = tonumber(call(WorldMapFrame, "GetMapID"))
    if combat() then
        self.pending = true
        if self.frame and (not plan or not plan.route or not plan.mapID or not mapRect(shown, plan.mapID)) then
            if self.frame.Hide then self.frame:Hide() end
        end
        return false
    end
    self.pending = false
    if shown ~= self.shownMap then
        self.shownMap = shown
        self.retried = false
    end
    if not plan or not plan.route or not plan.mapID then
        self:hideAll()
        return false
    end
    self:installHooks()
    if not self:ensure() then
        self:hideAll()
        return false
    end
    self:applyLevel()
    local rect = mapRect(shown, plan.mapID)
    if not rect then
        self:hideAll()
        return false
    end
    local width, height = canvasSize(self)
    if not width or not height or width <= 1 or height <= 1 then
        self:hideAll()
        self:retryLater()
        return false
    end
    self.retried = false
    self:draw(plan, rect, width, height)
    if self.frame.Show then self.frame:Show() end
    return true
end

function RouteMap:status()
    local plan = addon.RoutePlan and addon.RoutePlan.active
    local shown = tonumber(call(WorldMapFrame, "GetMapID"))
    local width, height = 0, 0
    if self.frame then width, height = canvasSize(self) end
    local rect = plan and plan.mapID and mapRect(shown, plan.mapID) or nil
    return {
        available = self:available(),
        frame = self.frame ~= nil,
        shown = self.frame ~= nil and call(self.frame, "IsShown") == true or false,
        level = self.level,
        mapID = shown,
        planMap = plan and plan.mapID or nil,
        stops = plan and plan.route and plan.route.stops and #plan.route.stops or 0,
        width = width,
        height = height,
        scale = canvasScale(),
        combat = combat() == true,
        rect = rect,
    }
end

function RouteMap:open(mapID)
    if combat() then return false end
    mapID = tonumber(mapID)
    local opened = false
    if addon.Compat.has("OpenWorldMap") then
        opened = addon.Compat.call("OpenWorldMap", mapID) == true
    end
    if not opened then
        if not WorldMapFrame then return false end
        if addon.Compat.has("ShowUIPanel") then addon.Compat.call("ShowUIPanel", WorldMapFrame) end
        if mapID then
            local setMap = WorldMapFrame.SetMapID
            if type(setMap) == "function" then pcall(setMap, WorldMapFrame, mapID) end
        end
    end
    self:refresh()
    self:scheduleRefresh(RETRY_DELAY)
    return true
end

addon.Events:subscribe("route-map", "PLAYER_REGEN_ENABLED", function()
    if RouteMap.pending then RouteMap:refresh() end
end)

return RouteMap
