local _, addon = ...

local ItemData = { cache = {}, requested = {}, auctionableCache = {} }
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

function ItemData.auctionable(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID < 1 or itemID ~= math.floor(itemID) then return nil end
    if ItemData.auctionableCache[itemID] ~= nil then return ItemData.auctionableCache[itemID] end
    local ok, name, _, _, _, _, _, _, _, _, _, _, _, _, bindType = addon.Compat.call("C_Item.GetItemInfo", itemID)
    if not ok or name == nil then
        ok, name, _, _, _, _, _, _, _, _, _, _, _, _, bindType = addon.Compat.call("GetItemInfo", itemID)
    end
    if not ok or name == nil then
        if not ItemData.requested[itemID] then
            ItemData.requested[itemID] = true
            addon.Compat.call("C_Item.RequestLoadItemDataByID", itemID)
        end
        return nil
    end
    bindType = tonumber(bindType)
    if not bindType then return nil end
    ItemData.auctionableCache[itemID] = bindType ~= 1 and bindType ~= 4
    return ItemData.auctionableCache[itemID]
end

function ItemData:received(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end
    for key in pairs(self.cache) do
        if addon.ItemKey.itemID(key) == itemID then self.cache[key] = nil end
    end
    self.auctionableCache[itemID] = nil
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
