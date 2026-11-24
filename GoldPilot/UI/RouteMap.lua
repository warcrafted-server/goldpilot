local _, addon = ...

local RouteMap = { pending = false, lines = {}, dots = {}, labels = {} }
addon.RouteMap = RouteMap

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
    local level = tonumber(call(canvas, "GetFrameLevel"))
    if level and frame.SetFrameLevel then pcall(frame.SetFrameLevel, frame, level + 500) end
    self.frame, self.canvas = frame, canvas
    return frame
end

local function canvasSize(self)
    local width = tonumber(call(self.canvas, "GetWidth")) or tonumber(call(self.frame, "GetWidth")) or 1
    local height = tonumber(call(self.canvas, "GetHeight")) or tonumber(call(self.frame, "GetHeight")) or 1
    return width, height
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
    if not ok or not created then return nil end
    self.lines[index] = created
    return created
end

local function dotAt(self, index)
    local dot = self.dots[index]
    if dot then return dot end
    local ok, created = pcall(self.frame.CreateTexture, self.frame, nil, "ARTWORK")
    if not ok or not created then return nil end
    if created.SetTexture and pcall(created.SetTexture, created, "Interface/COMMON/Indicator-Yellow") then
        -- La textura del indicador ya es amarilla y visible.
    elseif created.SetColorTexture then
        pcall(created.SetColorTexture, created, 1, 0.82, 0.2, 0.9)
    end
    self.dots[index] = created
    return created
end

local function labelAt(self, index)
    local label = self.labels[index]
    if label then return label end
    local ok, created = pcall(self.frame.CreateFontString, self.frame, nil, "OVERLAY", "GameFontNormal")
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

function RouteMap:draw(plan)
    local frame = self.frame
    local multiplier = canvasScale()
    local width, height = canvasSize(self)
    local stops = plan.route.stops or {}
    local count = #stops
    for index = 1, count do
        local from, pointTo = stops[index], stops[index % count + 1]
        local line = lineAt(self, index)
        if not line then break end
        if line.SetColorTexture then pcall(line.SetColorTexture, line, 1, 0.82, 0.2, 0.85) end
        if line.SetThickness then pcall(line.SetThickness, line, 3 / multiplier) end
        if line.SetStartPoint then
            pcall(line.SetStartPoint, line, "TOPLEFT", frame, from.x * width, -from.y * height)
        end
        if line.SetEndPoint then
            pcall(line.SetEndPoint, line, "TOPLEFT", frame, pointTo.x * width, -pointTo.y * height)
        end
        if line.Show then line:Show() end

        local dot = dotAt(self, index)
        if dot then
            if dot.SetSize then pcall(dot.SetSize, dot, 14 / multiplier, 14 / multiplier) end
            if dot.SetPoint then pcall(dot.SetPoint, dot, "CENTER", frame, "TOPLEFT", from.x * width, -from.y * height) end
            if dot.Show then dot:Show() end
            local label = labelAt(self, index)
            if label then
                if label.SetFont then pcall(label.SetFont, label, "Fonts/FRIZQT__.TTF", 11 / multiplier, "") end
                if label.ClearAllPoints then pcall(label.ClearAllPoints, label) end
                if label.SetPoint then pcall(label.SetPoint, label, "BOTTOM", dot, "TOP", 0, 1) end
                if label.SetText then label:SetText(tostring(index)) end
                if label.Show then label:Show() end
            end
        end
    end
    for index = count + 1, #self.lines do if self.lines[index].Hide then self.lines[index]:Hide() end end
    for index = count + 1, #self.dots do if self.dots[index].Hide then self.dots[index]:Hide() end end
    for index = count + 1, #self.labels do if self.labels[index].Hide then self.labels[index]:Hide() end end
    return true
end

function RouteMap:matches(plan)
    local id = tonumber(call(WorldMapFrame, "GetMapID"))
    return id ~= nil and id == plan.mapID
end

function RouteMap:refresh()
    if combat() then
        self.pending = true
        local plan = addon.RoutePlan and addon.RoutePlan.active
        if self.frame and (not plan or not plan.route or not plan.mapID or not self:matches(plan)) then
            if self.frame.Hide then self.frame:Hide() end
        end
        return false
    end
    self.pending = false
    local plan = addon.RoutePlan and addon.RoutePlan.active
    if not plan or not plan.route or not plan.mapID then
        self:hideAll()
        return false
    end
    self:installHooks()
    if not self:ensure() then
        self:hideAll()
        return false
    end
    if not self:matches(plan) then
        self:hideAll()
        return false
    end
    self:draw(plan)
    if self.frame.Show then self.frame:Show() end
    return true
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
    return true
end

addon.Events:subscribe("route-map", "PLAYER_REGEN_ENABLED", function()
    if RouteMap.pending then RouteMap:refresh() end
end)

return RouteMap
