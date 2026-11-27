local _, addon = ...

local open = false
local lastSlot, lastAt
local hooked = false
local buybackHooked = false

local function character()
    local ok, name = addon.Compat.call("UnitName", "player")
    return ok and type(name) == "string" and name ~= "" and name or "unknown"
end

local function itemName(itemID, link)
    local name = type(link) == "string" and string.match(link, "%[([^%]]+)%]") or nil
    if name then return name end
    local ok, found = addon.Compat.call("C_Item.GetItemNameByID", itemID)
    if ok and type(found) == "string" and found ~= "" then return found end
    ok, found = addon.Compat.call("GetItemInfo", itemID)
    return ok and type(found) == "string" and found ~= "" and found or nil
end

local function usedItem(bag, slot)
    if not open or addon.safeMode then return end
    local nowOk, now = addon.Compat.call("time")
    now = nowOk and tonumber(now) or 0
    local key = tostring(bag) .. ":" .. tostring(slot)
    if lastSlot == key and now - (lastAt or 0) < 1 then return end
    lastSlot, lastAt = key, now
    local ok, info = addon.Compat.call("C_Container.GetContainerItemInfo", bag, slot)
    -- No se mira isLocked: el cliente bloquea el hueco en cuanto se vende, antes de este gancho.
    if not ok or type(info) ~= "table" or not tonumber(info.itemID) then return end
    local itemID = tonumber(info.itemID)
    local vendor = addon.Valuation.vendor(itemID)
    if not vendor or (tonumber(vendor.price) or 0) <= 0 then return end
    local name = itemName(itemID, info.hyperlink)
    if not name then return end
    local qty = tonumber(info.stackCount) or 1
    GoldPilotDB = GoldPilotDB or {}
    addon.Ledger.vendorSale(GoldPilotDB, character(), now, itemID, name, qty, vendor.price)
end

local function boughtBack(index)
    if addon.safeMode then return end
    local ok, name, _, _, qty = addon.Compat.call("GetBuybackItemInfo", index)
    if not ok or type(name) ~= "string" or name == "" then return end
    GoldPilotDB = GoldPilotDB or {}
    addon.Ledger.vendorUndo(GoldPilotDB, character(), name, tonumber(qty) or 1)
end

addon.Modules:register("merchant", {
    onEnable = function()
        addon.Events:subscribe("merchant", "MERCHANT_SHOW", function() open = true end)
        addon.Events:subscribe("merchant", "MERCHANT_CLOSED", function() open = false end)
        if not hooked and type(hooksecurefunc) == "function" and addon.Compat.has("C_Container.UseContainerItem") then
            hooked = pcall(hooksecurefunc, C_Container, "UseContainerItem", usedItem)
        end
        if not buybackHooked and type(hooksecurefunc) == "function" and addon.Compat.has("BuybackItem") then
            buybackHooked = pcall(hooksecurefunc, "BuybackItem", boughtBack)
        end
    end,
})
