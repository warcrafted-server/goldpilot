local _, addon = ...

local ItemData = { cache = {}, requested = {} }
addon.ItemData = ItemData

local function pack(...)
    return { n = select("#", ...), ... }
end

local function vendorPrice(key)
    if ItemData.cache[key] ~= nil then return ItemData.cache[key] end
    local itemID = addon.ItemKey.itemID(key)
    if not itemID then return nil end
    local lookup = itemID
    if type(key) == "string" and string.find(key, ":", 1, true) then
        lookup = GoldPilotDB and GoldPilotDB.links and GoldPilotDB.links[key] or itemID
    end
    local values = pack(addon.Compat.call("C_Item.GetItemInfo", lookup))
    if not values[1] then values = pack(addon.Compat.call("GetItemInfo", lookup)) end
    local price = values[1] and tonumber(values[12]) or nil
    if price ~= nil then
        ItemData.cache[key] = price
        return price
    end
    if not ItemData.requested[itemID] then
        ItemData.requested[itemID] = true
        addon.Compat.call("C_Item.RequestLoadItemDataByID", itemID)
    end
end

function ItemData:received(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end
    for key in pairs(self.cache) do
        if addon.ItemKey.itemID(key) == itemID then self.cache[key] = nil end
    end
    self.requested[itemID] = nil
end

addon.Valuation.registerVendor(vendorPrice)
addon.Modules:register("item-data", {
    onEnable = function()
        addon.Events:subscribe("item-data", "GET_ITEM_INFO_RECEIVED", function(itemID)
            ItemData:received(itemID)
        end)
    end,
})

return ItemData
