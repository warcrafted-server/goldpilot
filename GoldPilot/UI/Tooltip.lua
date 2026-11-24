local _, addon = ...

local Tooltip = {}
addon.Tooltip = Tooltip

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function itemIDFromTooltip(tooltip, data)
    local id = data and (data.id or data.itemID)
    if tonumber(id) then return tonumber(id) end
    if tooltip and tooltip.GetItem then
        local _, link = tooltip:GetItem()
        local ok, itemID = addon.Compat.call("GetItemInfoInstant", link)
        if ok then return tonumber(itemID) end
    end
end

function Tooltip:add(tooltip, data)
    if inCombat() then return end
    local itemID = itemIDFromTooltip(tooltip, data)
    if not itemID then return end
    local nowOk, now = addon.Compat.call("time")
    if not nowOk or not tonumber(now) then return end
    local houseKey = addon.AuctionHouse.houseKey()
    local db = GoldPilotDB or {}
    local observation = addon.DataItems and addon.DataItems[itemID] and addon.Prices.get(db, houseKey, itemID)
    if addon.AuctionHouse:isOpen() and (not observation or tonumber(now) - (tonumber(observation.t) or 0) >= 600) then
        addon.AuctionHouse:enqueue(itemID, true)
    end
    if not (addon.DataItems and addon.DataItems[itemID]) then return end
    local value = addon.Valuation.value(db, houseKey, itemID, now)
    local vendor = value.vendor and value.vendor.price
    local ref = value.ref
    local stale = not ref and value.why and value.why.reason == "stale" and value.why.best
    local shownAuction = ref or stale
    local auctionPrice = shownAuction and shownAuction.price or (observation and observation.p50)
    local cut = db.houses and db.houses[houseKey] and db.houses[houseKey].cut
    local recommendation = addon.Advisor.recommend(vendor, ref and ref.price, cut)

    tooltip:AddLine(string.format(addon.L.TOOLTIP_VENDOR, vendor and addon.Theme.money(vendor) or addon.L.TOOLTIP_NO_VENDOR, addon.Theme.badge("GAME")))
    if shownAuction then
        local age = addon.Theme.age(now - shownAuction.t)
        if stale then age = "|cff999999" .. age .. " - " .. addon.L.TOOLTIP_STALE .. "|r" end
        local action = recommendation.action == "auction" and addon.L.TOOLTIP_AUCTION or addon.L.TOOLTIP_SELLER
        local priceText = addon.Theme.money(auctionPrice)
        local badge = addon.Theme.badge(shownAuction.class or "OBS")
        if stale then priceText, badge = "|cff999999" .. priceText .. "|r", "|cff999999[OBS]|r" end
        tooltip:AddLine(string.format(addon.L.TOOLTIP_AUCTION_LINE, priceText, badge, age, action))
    else
        tooltip:AddLine(addon.L.TOOLTIP_NO_AUCTION)
    end

    if IsShiftKeyDown and IsShiftKeyDown() then
        if observation then
            tooltip:AddLine(string.format(addon.L.TOOLTIP_DETAILS, addon.Theme.money(observation.min), observation.qty))
        else
            tooltip:AddLine(addon.L.TOOLTIP_DETAILS_NONE)
        end
        if recommendation.cutAssumed then tooltip:AddLine(addon.L.TOOLTIP_CUT_ASSUMED) end
    end
end

addon.Modules:register("tooltip", {
    onEnable = function()
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data) Tooltip:add(tooltip, data) end)
        elseif GameTooltip and GameTooltip.HookScript then
            GameTooltip:HookScript("OnTooltipSetItem", function(tooltip) Tooltip:add(tooltip) end)
        end
    end,
})
