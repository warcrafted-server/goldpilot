local _, addon = ...

addon.Bags = {}

local function characterBagIDs()
    local maxBag = tonumber(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or 5
    local ids = {}
    for bag = 0, maxBag do ids[#ids + 1] = bag end
    return ids
end

local function scanContainers(ids)
    local items, bound = {}, {}
    if not addon.Compat.has("C_Container.GetContainerNumSlots") then return items, bound end
    for _, bag in ipairs(ids) do
        local slotsOk, slots = addon.Compat.call("C_Container.GetContainerNumSlots", bag)
        if slotsOk and tonumber(slots) then
            for slot = 1, tonumber(slots) do
                local infoOk, info = addon.Compat.call("C_Container.GetContainerItemInfo", bag, slot)
                if infoOk and type(info) == "table" and tonumber(info.itemID) then
                    local itemID = tonumber(info.itemID)
                    local key = info.hyperlink and addon.ItemKey.fromLink(info.hyperlink, addon.ItemKey.isGear(itemID)) or nil
                    key = key or itemID
                    local count = tonumber(info.stackCount) or 1
                    items[key] = (items[key] or 0) + count
                    if info.isBound then bound[key] = (bound[key] or 0) + count end
                    if type(key) == "string" and string.find(key, ":", 1, true) then
                        GoldPilotDB = GoldPilotDB or {}
                        GoldPilotDB.links = GoldPilotDB.links or {}
                        GoldPilotDB.links[key] = string.match(info.hyperlink, "(item:[^|%s]+)")
                    end
                end
            end
        end
    end
    return items, bound
end

function addon.Bags:scan()
    return scanContainers(characterBagIDs())
end

function addon.Bags:scanEquipped()
    local items = {}
    if not addon.Compat.has("GetInventoryItemID") then return items end
    for slot = 1, 19 do
        local ok, itemID = addon.Compat.call("GetInventoryItemID", "player", slot)
        if ok and tonumber(itemID) then items[tonumber(itemID)] = (items[tonumber(itemID)] or 0) + 1 end
    end
    return items
end

local function characterKey()
    local _, name = addon.Compat.call("UnitName", "player")
    if type(name) ~= "string" or name == "" then name = "unknown" end
    return name
end

local function save()
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.chars = GoldPilotDB.chars or {}
    local _, money = addon.Compat.call("GetMoney")
    local ok, seen = addon.Compat.call("time")
    local key = characterKey()
    local previous = GoldPilotDB.chars[key] or {}
    local bags, bound = addon.Bags:scan()
    GoldPilotDB.chars[key] = {
        money = tonumber(money) or 0,
        bags = bags,
        bound = bound,
        equipped = addon.Bags:scanEquipped(),
        bank = previous.bank,
        bankBound = previous.bankBound,
        bankSeen = previous.bankSeen,
        seen = ok and tonumber(seen) or 0,
    }
end

local function scanBank()
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.chars = GoldPilotDB.chars or {}
    local key = characterKey()
    local container = addon.Compat.has("C_Container.GetContainerNumSlots")
    if not container then return end
    local equipped = tonumber(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or 5
    local ids = { tonumber(BANK_CONTAINER) or -1 }
    for bag = equipped + 1, equipped + (tonumber(NUM_BANKBAGSLOTS) or 7) do
        ids[#ids + 1] = bag
    end
    local reagentBank = Enum and Enum.BagIndex and tonumber(Enum.BagIndex.Reagentbank) or -3
    ids[#ids + 1] = reagentBank
    local items, bound = scanContainers(ids)
    local char = GoldPilotDB.chars[key] or {}
    local ok, seen = addon.Compat.call("time")
    char.bank, char.bankBound, char.bankSeen = items, bound, ok and tonumber(seen) or 0
    GoldPilotDB.chars[key] = char
end

addon.Modules:register("bags", {
    requires = { "C_Container.GetContainerNumSlots" },
    onEnable = function()
        save()
        addon.Events:subscribe("bags", "BAG_UPDATE_DELAYED", save, 0.5)
        addon.Events:subscribe("bags", "BANKFRAME_OPENED", scanBank, 0.5)
        addon.Events:subscribe("bags", "PLAYER_EQUIPMENT_CHANGED", save, 0.5)
    end,
})
