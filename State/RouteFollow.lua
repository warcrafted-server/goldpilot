local _, addon = ...

local RouteFollow = { generation = 0, next = nil, visit = nil, records = {} }
addon.RouteFollow = RouteFollow

local INTERVAL = 2
local ARRIVE = 0.012
local LEAVE = 0.025
local MIN_VISIT = 3
local REPEAT = 300

local function combat()
    return InCombatLockdown and InCombatLockdown()
end

local function now()
    local ok, value = addon.Compat.call("time")
    return ok and tonumber(value) or nil
end

local function player(plan)
    local ok, point = addon.Compat.call("C_Map.GetPlayerMapPosition", plan.mapID, "player")
    if not ok or point == nil then return nil end
    local x, y
    local methodOK, method = pcall(function() return point.GetXY end)
    if methodOK and type(method) == "function" then
        local called, px, py = pcall(method, point)
        if called then x, y = tonumber(px), tonumber(py) end
    end
    if x == nil then
        local okX, px = pcall(function() return point.x end)
        local okY, py = pcall(function() return point.y end)
        if okX and okY then x, y = tonumber(px), tonumber(py) end
    end
    if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    local taxiOK, taxi = addon.Compat.call("UnitOnTaxi", "player")
    if taxiOK and taxi then return nil end
    local deadOK, dead = addon.Compat.call("UnitIsDeadOrGhost", "player")
    if deadOK and dead then return nil end
    return x, y
end

local function gap(ax, ay, bx, by, aspect)
    local dx, dy = ax - bx, (ay - by) / aspect
    return math.sqrt(dx * dx + dy * dy)
end

local function stopDistance(stop, x, y, aspect)
    local best = gap(x, y, stop.x, stop.y, aspect)
    for _, point in ipairs(stop.points or {}) do
        local px, py = tonumber(point.x), tonumber(point.y)
        if px and py then
            local distance = gap(x, y, px, py, aspect)
            if distance < best then best = distance end
        end
    end
    return best
end

local function arrival(stops, x, y, aspect)
    local index, distance
    for position, stop in ipairs(stops) do
        local value = stopDistance(stop, x, y, aspect)
        if value <= ARRIVE and (not distance or value < distance) then
            index, distance = position, value
        end
    end
    return index, distance
end

local function clearWaypoint(self)
    local uid = self.waypoint
    self.waypoint = nil
    if uid == nil then return end
    local tomtom = TomTom
    local remove = type(tomtom) == "table" and tomtom.RemoveWaypoint or nil
    if type(remove) ~= "function" then return end
    pcall(remove, tomtom, uid)
end

local function waypointsAllowed(self)
    if self.enabled ~= nil then return self.enabled end
    local settings = GoldPilotDB and GoldPilotDB.settings or nil
    return not (settings and settings.routeWaypoint == false)
end

local function applyWaypoint(self)
    local plan = self.plan
    if not plan or not plan.route or not self.next then return end
    if not waypointsAllowed(self) then
        self.waypointPending = false
        clearWaypoint(self)
        return
    end
    if combat() then
        self.waypointPending = true
        return
    end
    self.waypointPending = false
    local tomtom = TomTom
    local add = type(tomtom) == "table" and tomtom.AddWaypoint or nil
    if type(add) ~= "function" then return end
    local stop = plan.route.stops and plan.route.stops[self.next]
    if not stop then return end
    clearWaypoint(self)
    local title = string.format(addon.L.ROUTE_WAYPOINT, self.next)
    local ok, uid = pcall(add, tomtom, plan.mapID, stop.x, stop.y, {
        title = title, persistent = false, minimap = true, world = true, from = "GoldPilot" })
    if ok and uid ~= nil and uid ~= false then self.waypoint = uid end
end

local function refreshViews(self)
    if addon.RouteMap and addon.RouteMap.refresh then pcall(addon.RouteMap.refresh, addon.RouteMap) end
    if addon.ZonesUI and addon.ZonesUI.refresh then pcall(addon.ZonesUI.refresh, addon.ZonesUI) end
end

local function moved(self)
    applyWaypoint(self)
    refreshViews(self)
end

local schedule

local function tick(self)
    local plan = self.plan
    if not plan or not plan.route then return end
    local x, y = player(plan)
    if not x then
        self.visit = nil
        schedule(self)
        return
    end
    local at = now() or 0
    local aspect = self.aspect or 1
    local stops = plan.route.stops or {}
    local target, targetDistance = arrival(stops, x, y, aspect)
    if self.visit then
        local stop = stops[self.visit.index]
        if not stop then
            self.visit = nil
        else
            local current = stopDistance(stop, x, y, aspect)
            if current > LEAVE or (targetDistance and targetDistance < current) then
                self:finishVisit(at)
            end
        end
    end
    if not self.visit and target then
        self.visit = { index = target, start = at, hits = {} }
        local following = target % #stops + 1
        if following ~= self.next then
            self.next = following
            moved(self)
        end
    end
    if self.waypointPending then applyWaypoint(self) end
    schedule(self)
end

schedule = function(self)
    if self.timerGeneration or not self.plan then return end
    local generation = self.generation
    self.timerGeneration = generation
    local ok = addon.Compat.call("C_Timer.After", INTERVAL, function()
        if self.timerGeneration ~= generation then return end
        self.timerGeneration = nil
        if self.generation ~= generation then
            if self.plan then schedule(self) end
            return
        end
        if not self.plan then return end
        tick(self)
    end)
    if not ok then self.timerGeneration = nil end
end

function RouteFollow:nearest(x, y)
    local plan = self.plan
    local stops = plan and plan.route and plan.route.stops or {}
    if not x or not y or #stops == 0 then return 1 end
    local best, bestDistance
    for index, stop in ipairs(stops) do
        local value = stopDistance(stop, x, y, self.aspect or 1)
        if not bestDistance or value < bestDistance then best, bestDistance = index, value end
    end
    return best or 1
end

function RouteFollow:start(plan)
    self.plan = plan
    self.visit = nil
    self.records = {}
    self.generation = (self.generation or 0) + 1
    self.waypointPending = false
    self.aspect = 1
    if plan and plan.mapID then
        local aspect = addon.RoutePlan.aspect(plan.mapID)
        if aspect and aspect > 0 then self.aspect = aspect end
    end
    local x, y
    if plan then x, y = player(plan) end
    self.next = self:nearest(x, y)
    moved(self)
    schedule(self)
    return self.next
end

function RouteFollow:stop()
    self.plan = nil
    self.visit = nil
    self.next = nil
    self.records = {}
    self.generation = (self.generation or 0) + 1
    self.waypointPending = false
    clearWaypoint(self)
    return true
end

function RouteFollow:finishVisit(at)
    local visit = self.visit
    self.visit = nil
    if not visit then return end
    local plan = self.plan
    local stop = plan and plan.route and plan.route.stops[visit.index]
    if not stop then return end
    local duration = at - (tonumber(visit.start) or at)
    if duration < MIN_VISIT then return end
    local last = self.records[visit.index]
    if last and at - last < REPEAT then return end
    self.records[visit.index] = at
    local cell = addon.Visits.cell(plan.kind, stop.x, stop.y)
    local cells, hits = {}, {}
    for _, point in ipairs(stop.points or {}) do
        local key = addon.Visits.cell(plan.kind, point.x, point.y)
        if key then
            cells[key] = true
            if visit.hits[key] then hits[key] = true end
        end
    end
    if next(cells) == nil and cell then cells[cell] = true end
    if next(cells) == nil then return end
    GoldPilotDB = GoldPilotDB or {}
    addon.Visits.record(GoldPilotDB, plan.mapID, cells, hits, at)
end

function RouteFollow:onNode(map, x, y, objectID, items)
    local plan = self.plan
    if not plan or not plan.route then return false end
    if not plan.mapID or tonumber(map) ~= tonumber(plan.mapID) then return false end
    local kind = addon.RoutePlan.kindOf(objectID, items)
    if not kind then return false end
    if plan.kind and kind ~= plan.kind then return false end
    local visit = self.visit
    local stop = visit and plan.route.stops and plan.route.stops[visit.index] or nil
    if not stop then return false end
    local lx, ly = tonumber(x), tonumber(y)
    if not lx or not ly or lx < 0 or lx > 1 or ly < 0 or ly > 1 then return false end
    local best, bestDistance
    for _, point in ipairs(stop.points or {}) do
        local px, py = tonumber(point.x), tonumber(point.y)
        if px and py then
            local distance = gap(lx, ly, px, py, self.aspect or 1)
            if not bestDistance or distance < bestDistance then best, bestDistance = point, distance end
        end
    end
    if not best or bestDistance > LEAVE then return false end
    local cell = addon.Visits.cell(plan.kind, best.x, best.y)
    if not cell then return false end
    visit.hits[cell] = true
    return true
end

function RouteFollow:setWaypoint(enabled)
    self.enabled = enabled ~= false
    if not self.enabled then
        self.waypointPending = false
        clearWaypoint(self)
    elseif self.plan then
        self.waypointPending = true
        applyWaypoint(self)
    end
    return self.enabled
end

if addon.Loot then
    addon.Loot.onNode = function(map, x, y, objectID, items, current)
        return RouteFollow:onNode(map, x, y, objectID, items, current)
    end
end

return RouteFollow
