local _, addon = ...

local Nodes = {}
addon.Nodes = Nodes

Nodes.maxSpots = 150
Nodes.radius = 40

local function integer(value)
    value = tonumber(value)
    if value and value > 0 and value == math.floor(value) then return value end
    return nil
end

local function coordinate(value)
    value = tonumber(value)
    if not value or value < 0 or value > 1 then return nil end
    return math.floor(value * 10000 + 0.5)
end

local function removeOldest(spots)
    local oldest = 1
    for index = 2, #spots do
        if (tonumber(spots[index].t) or 0) < (tonumber(spots[oldest].t) or 0) then oldest = index end
    end
    table.remove(spots, oldest)
end

function Nodes.record(db, map, object, x, y, now)
    map, object = integer(map), integer(object)
    if not map or not object then return false end
    now = tonumber(now) or 0
    db.nodes = db.nodes or {}
    db.nodes[map] = db.nodes[map] or {}
    local node = db.nodes[map][object]
    if not node then
        node = { n = 0, first = now, last = now, spots = {} }
        db.nodes[map][object] = node
    end
    node.n = (tonumber(node.n) or 0) + 1
    node.first = node.first or now
    node.last = math.max(tonumber(node.last) or now, now)
    node.spots = node.spots or {}
    local px, py = coordinate(x), coordinate(y)
    if px and py and (px ~= 0 or py ~= 0) then
        local nearest, distance
        for _, spot in ipairs(node.spots) do
            local dx, dy = (tonumber(spot.x) or 0) - px, (tonumber(spot.y) or 0) - py
            local current = math.sqrt(dx * dx + dy * dy)
            if not distance or current < distance then nearest, distance = spot, current end
        end
        if nearest and distance <= Nodes.radius then
            local count = (tonumber(nearest.n) or 0) + 1
            nearest.x = math.floor(((tonumber(nearest.x) or 0) * (count - 1) + px) / count + 0.5)
            nearest.y = math.floor(((tonumber(nearest.y) or 0) * (count - 1) + py) / count + 0.5)
            nearest.n, nearest.t = count, now
        else
            node.spots[#node.spots + 1] = { x = px, y = py, n = 1, t = now }
            if #node.spots > Nodes.maxSpots then removeOldest(node.spots) end
        end
    end
    return true
end
