local _, addon = ...

addon.Bags = {}

function addon.Bags:scan()
    local items = {}
    if not addon.Compat.has("C_Container.GetContainerNumSlots") then return items end
    local maxBag = tonumber(NUM_BAG_SLOTS) or 4
    for bag = 0, maxBag do
        local slotsOk, slots = addon.Compat.call("C_Container.GetContainerNumSlots", bag)
        if slotsOk and tonumber(slots) then
            for slot = 1, tonumber(slots) do
                local infoOk, info = addon.Compat.call("C_Container.GetContainerItemInfo", bag, slot)
                if infoOk and type(info) == "table" and tonumber(info.itemID) then
                    local count = tonumber(info.stackCount) or 1
                    items[tonumber(info.itemID)] = (items[tonumber(info.itemID)] or 0) + count
                end
            end
        end
    end
    return items
end

local function characterKey()
    local _, name = addon.Compat.call("UnitName", "player")
    local _, realm = addon.Compat.call("GetRealmName")
    if type(name) ~= "string" or name == "" then name = "unknown" end
    if type(realm) ~= "string" or realm == "" then realm = "unknown" end
    return name .. "-" .. realm
end

local function save()
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.chars = GoldPilotDB.chars or {}
    local _, money = addon.Compat.call("GetMoney")
    local ok, seen = pcall(time)
    GoldPilotDB.chars[characterKey()] = {
        money = tonumber(money) or 0,
        bags = addon.Bags:scan(),
        seen = ok and tonumber(seen) or 0,
    }
end

addon.Modules:register("bags", {
    requires = { "C_Container.GetContainerNumSlots" },
    onEnable = function()
        save()
        addon.Events:subscribe("bags", "PLAYER_LOGIN", save)
        addon.Events:subscribe("bags", "BAG_UPDATE_DELAYED", save, 0.5)
    end,
})
