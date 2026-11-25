local _, addon = ...

local Visits = {}
addon.Visits = Visits

Visits.bucket = 0.02
Visits.cap = 20
Visits.expire = 60 * 86400

local function mapKey(value)
    value = tonumber(value)
    if value and value > 0 and value == math.floor(value) then return value end
    return nil
end

local function kindKey(kind)
    if kind == "herb" or kind == "ore" then return kind end
    return "all"
end

local function coordinate(value)
    value = tonumber(value)
    if not value or value < 0 or value > 1 then return nil end
    return math.floor(value / Visits.bucket)
end

function Visits.cell(kind, x, y)
    local cx, cy = coordinate(x), coordinate(y)
    if not cx or not cy then return nil end
    return kindKey(kind) .. ":" .. cx .. ":" .. cy
end

function Visits.record(db, mapID, cells, hits, now)
    mapID = mapKey(mapID)
    if not mapID or type(db) ~= "table" or type(cells) ~= "table" then return false end
    now = tonumber(now) or 0
    db.routeVisits = db.routeVisits or {}
    local map = db.routeVisits[mapID]
    if type(map) ~= "table" then
        map = {}
        db.routeVisits[mapID] = map
    end
    for cell in pairs(cells) do
        local entry = map[cell]
        if type(entry) ~= "table" then
            entry = { v = 0, h = 0, t = now }
            map[cell] = entry
        end
        entry.v = (tonumber(entry.v) or 0) + 1
        if type(hits) == "table" and hits[cell] then entry.h = (tonumber(entry.h) or 0) + 1 end
        if entry.h > entry.v then entry.h = entry.v end
        entry.t = now
        if entry.v >= Visits.cap then
            entry.v = math.floor(entry.v / 2)
            entry.h = math.floor(entry.h / 2)
        end
    end
    return true
end

function Visits.factor(db, mapID, kind, x, y)
    local cell = Visits.cell(kind, x, y)
    mapID = mapKey(mapID)
    local map = cell and mapID and type(db) == "table" and type(db.routeVisits) == "table"
        and db.routeVisits[mapID] or nil
    local entry = type(map) == "table" and map[cell] or nil
    if not entry then return 1 end
    local visits = tonumber(entry.v) or 0
    local hits = tonumber(entry.h) or 0
    return (hits + 2) / (visits + 2)
end

function Visits.totals(db, mapID, kind)
    mapID = mapKey(mapID)
    local map = mapID and type(db) == "table" and type(db.routeVisits) == "table"
        and db.routeVisits[mapID] or nil
    if type(map) ~= "table" then return 0, 0 end
    local prefix = kindKey(kind) .. ":"
    local visits, hits = 0, 0
    for cell, entry in pairs(map) do
        if type(cell) == "string" and string.sub(cell, 1, #prefix) == prefix
            and type(entry) == "table" then
            visits = visits + (tonumber(entry.v) or 0)
            hits = hits + (tonumber(entry.h) or 0)
        end
    end
    return visits, hits
end

function Visits.prune(db, now)
    if type(db) ~= "table" or type(db.routeVisits) ~= "table" then return false end
    now = tonumber(now) or 0
    for mapID, map in pairs(db.routeVisits) do
        if type(map) ~= "table" then
            db.routeVisits[mapID] = nil
        else
            for cell, entry in pairs(map) do
                local stamp = type(entry) == "table" and tonumber(entry.t) or nil
                if not stamp or now - stamp > Visits.expire then map[cell] = nil end
            end
            if next(map) == nil then db.routeVisits[mapID] = nil end
        end
    end
    if next(db.routeVisits) == nil then db.routeVisits = nil end
    return true
end
