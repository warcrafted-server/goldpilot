local _, addon = ...

local RoutePlan = {}
addon.RoutePlan = RoutePlan

local function now()
    local ok, value = addon.Compat.call("time")
    return ok and tonumber(value) or 0
end

local function classify(key)
    local itemID = addon.ItemKey.itemID(key)
    if not itemID then return nil end
    local ok, _, _, _, _, _, classID, subclassID = addon.Compat.call("C_Item.GetItemInfoInstant", itemID)
    if not ok then
        ok, _, _, _, _, _, classID, subclassID = addon.Compat.call("GetItemInfoInstant", itemID)
    end
    if not ok then return nil end
    classID, subclassID = tonumber(classID), tonumber(subclassID)
    if classID ~= 7 then return nil end
    if subclassID == 9 then return "herb" end
    if subclassID == 7 then return "ore" end
    return nil
end

function RoutePlan.currentMap()
    local ok, value = addon.Compat.call("C_Map.GetBestMapForUnit", "player")
    value = ok and tonumber(value) or nil
    if value and value > 0 and value == math.floor(value) then return value end
    return nil
end

function RoutePlan.mapName(id)
    id = tonumber(id) or 0
    local ok, info = addon.Compat.call("C_Map.GetMapInfo", id)
    if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info.name end
    return "#" .. tostring(id)
end

function RoutePlan.aspect(id)
    id = tonumber(id)
    if id then
        local ok, width, height = addon.Compat.call("C_Map.GetMapWorldSize", id)
        width, height = ok and tonumber(width) or nil, ok and tonumber(height) or nil
        if width and height and width > 0 and height > 0 then return width / height, width end
    end
    return addon.Routes.defaults.aspect, nil
end

function RoutePlan.compute(mapID, kind)
    local db = GoldPilotDB or {}
    local at = now()
    local houseKey = addon.AuctionHouse and addon.AuctionHouse.houseKey and addon.AuctionHouse.houseKey() or nil
    local auctionable = addon.ItemData and addon.ItemData.auctionable or nil
    local aspect, width = RoutePlan.aspect(mapID)
    local skills = addon.Professions.skills()
    local points, stats = addon.Routes.points(db, mapID, {
        spots = addon.DataNodeSpots,
        unit = function(key)
            local value = addon.Sessions.unit(db, houseKey, key, at, auctionable)
            return value
        end,
        kind = kind,
        skills = skills,
        classify = classify,
        aspect = aspect,
    })
    local route = addon.Routes.build(points, { aspect = aspect })
    local yards
    if route and route.length and width then yards = math.floor(route.length * width + 0.5) end
    return { mapID = mapID, kind = kind, route = route, stats = stats, skills = skills, yards = yards, at = at }
end

function RoutePlan:show(plan)
    self.active = plan
    if addon.RouteMap and addon.RouteMap.refresh then addon.RouteMap:refresh() end
    return plan
end

function RoutePlan:clear()
    self.active = nil
    if addon.RouteMap and addon.RouteMap.refresh then addon.RouteMap:refresh() end
    return true
end

return RoutePlan
