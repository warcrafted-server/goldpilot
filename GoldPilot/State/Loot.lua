local _, addon = ...

local Loot = {}
addon.Loot = Loot

local seen, order = {}, {}
local timer = false

local function now()
    local ok, value = addon.Compat.call("time")
    return ok and tonumber(value) or nil
end

local function guidParts(guid)
    if type(guid) ~= "string" then return nil end
    local kind = string.match(guid, "^([^-]+)")
    if kind ~= "GameObject" and kind ~= "Creature" then return nil end
    local index, id = 0, nil
    for part in string.gmatch(guid, "[^-]+") do
        index = index + 1
        if index == 6 then
            id = tonumber(part)
            break
        end
    end
    if not id or id <= 0 or id ~= math.floor(id) then return nil end
    return kind, id
end

local function position()
    local mapOk, map = addon.Compat.call("C_Map.GetBestMapForUnit", "player")
    map = mapOk and tonumber(map) or nil
    if not map then return nil end
    local pointOk, point = addon.Compat.call("C_Map.GetPlayerMapPosition", map, "player")
    if not pointOk or point == nil then return map end
    local x, y
    local ok, method = pcall(function() return point.GetXY end)
    if ok and type(method) == "function" then
        local called, px, py = pcall(method, point)
        if called then x, y = tonumber(px), tonumber(py) end
    end
    if x == nil then
        local okX, px = pcall(function() return point.x end)
        local okY, py = pcall(function() return point.y end)
        if okX and okY then x, y = tonumber(px), tonumber(py) end
    end
    return map, x, y
end

function Loot:finish(current)
    current = tonumber(current) or now() or 0
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotCharDB = GoldPilotCharDB or {}
    local session = GoldPilotCharDB.session
    local saved = addon.Sessions.close(GoldPilotDB, session, current)
    GoldPilotCharDB.session = nil
    if session and type(Loot.onFinish) == "function" then pcall(Loot.onFinish, session, saved) end
    return saved
end

function Loot:check()
    if addon.safeMode then return end
    local session = GoldPilotCharDB and GoldPilotCharDB.session
    if not session then return end
    local current = now()
    if current and addon.Sessions.expired(session, current) then Loot:finish(current) end
end

local function tick()
    timer = false
    Loot:check()
    if GoldPilotCharDB and GoldPilotCharDB.session then
        timer = true
        addon.Compat.call("C_Timer.After", 60, tick)
    end
end

local function schedule()
    if timer then return end
    timer = true
    addon.Compat.call("C_Timer.After", 60, tick)
end

local function readLoot()
    if addon.safeMode then return end
    local countOk, count = addon.Compat.call("GetNumLootItems")
    if not countOk then return end
    count = math.max(0, math.floor(tonumber(count) or 0))
    if count == 0 then return end
    local current = now()
    if not current then return end
    local nameOk, character = addon.Compat.call("UnitName", "player")
    if not nameOk or type(character) ~= "string" or character == "" then character = "unknown" end
    local fishingOk, fishing = addon.Compat.call("IsFishingLoot")
    fishing = fishingOk and fishing == true

    local found, sequence = {}, {}
    for slot = 1, count do
        local linkOk, link = addon.Compat.call("GetLootSlotLink", slot)
        local hasLink = linkOk and type(link) == "string" and link ~= ""
        local key
        if hasLink then
            local itemID = tonumber(string.match(link, "item:(%d+)"))
            key = addon.ItemKey.fromLink(link, addon.ItemKey.isGear(itemID))
        end
        local values = { addon.Compat.call("GetLootSourceInfo", slot) }
        if values[1] then
            for index = 2, #values, 2 do
                local guid, amount = values[index], tonumber(values[index + 1]) or 0
                local kind, objectID = guidParts(guid)
                if kind and objectID and amount > 0 and (not hasLink or key) then
                    local entry = found[guid]
                    if not entry then
                        entry = { kind = kind, objectID = objectID, coin = 0, items = {} }
                        found[guid] = entry
                        sequence[#sequence + 1] = guid
                    end
                    if key then
                        entry.items[key] = (entry.items[key] or 0) + amount
                    else
                        entry.coin = entry.coin + amount
                    end
                end
            end
        end
    end

    local coin, items, nodes = 0, {}, {}
    for _, guid in ipairs(sequence) do
        local entry = found[guid]
        local memory = seen[guid]
        local fresh = memory == nil
        if fresh then
            memory = {}
            seen[guid] = memory
            order[#order + 1] = guid
            if #order > 500 then seen[table.remove(order, 1)] = nil end
        end
        local gained = {}
        for itemKey, amount in pairs(entry.items) do
            local previous = tonumber(memory[itemKey]) or 0
            if amount > previous then
                memory[itemKey] = amount
                items[itemKey] = (items[itemKey] or 0) + amount - previous
                gained[itemKey] = amount - previous
            end
        end
        local previous = tonumber(memory.coin) or 0
        if entry.coin > previous then
            memory.coin = entry.coin
            coin = coin + entry.coin - previous
        end
        if fresh and entry.kind == "GameObject" and not fishing then
            nodes[#nodes + 1] = { objectID = entry.objectID, items = gained }
        end
    end
    if next(items) == nil and coin == 0 then return end

    local map, x, y = position()
    for _, node in ipairs(nodes) do
        GoldPilotDB = GoldPilotDB or {}
        addon.Nodes.record(GoldPilotDB, map, node.objectID, x, y, current, node.items)
    end
    GoldPilotCharDB = GoldPilotCharDB or {}
    if GoldPilotCharDB.session and addon.Sessions.expired(GoldPilotCharDB.session, current) then
        Loot:finish(current)
    end
    GoldPilotCharDB.session = addon.Sessions.add(GoldPilotCharDB.session, {
        char = character, mapID = map, coin = coin, items = items, node = #nodes > 0,
    }, current)
    schedule()
    if type(Loot.onLoot) == "function" then pcall(Loot.onLoot, GoldPilotCharDB.session) end
end

addon.Modules:register("loot", {
    onEnable = function()
        addon.Events:subscribe("loot", "LOOT_READY", readLoot)
        Loot:check()
        if GoldPilotCharDB and GoldPilotCharDB.session then schedule() end
    end,
})
