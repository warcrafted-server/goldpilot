local _, addon = ...

local ItemKey = {}
addon.ItemKey = ItemKey

local function fields(value)
    local result, start = {}, 1
    while true do
        local colon = string.find(value, ":", start, true)
        if not colon then
            result[#result + 1] = string.sub(value, start)
            break
        end
        result[#result + 1] = string.sub(value, start, colon - 1)
        start = colon + 1
    end
    return result
end

function ItemKey.fromLink(link, isGear)
    if type(link) ~= "string" then return nil end
    local item = string.match(link, "(item:[^|%s]+)")
    if not item then return nil end
    local values = fields(string.sub(item, 6))
    local itemID = tonumber(values[1])
    if not itemID or itemID < 1 or itemID ~= math.floor(itemID) then return nil end
    local count = tonumber(values[13])
    if isGear and count and count > 0 then
        local bonuses = {}
        for index = 1, math.floor(count) do
            local bonus = tonumber(values[13 + index])
            if not bonus then return nil end
            bonuses[#bonuses + 1] = bonus
        end
        table.sort(bonuses)
        for index, bonus in ipairs(bonuses) do bonuses[index] = tostring(bonus) end
        return tostring(itemID) .. ":" .. table.concat(bonuses, "-")
    end
    return itemID
end

function ItemKey.itemID(key)
    if type(key) == "number" then return key end
    if type(key) ~= "string" then return nil end
    local id = tonumber(string.match(key, "^(%d+):")) or tonumber(key)
    if id and id > 0 and id == math.floor(id) then return id end
    return nil
end
