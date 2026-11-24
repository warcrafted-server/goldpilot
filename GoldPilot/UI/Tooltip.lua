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

local function linkFromTooltip(tooltip, data)
    if data and type(data.hyperlink) == "string" then return data.hyperlink end
    if tooltip and tooltip.GetItem then
        local _, link = tooltip:GetItem()
        if type(link) == "string" then return link end
    end
    if TooltipUtil and TooltipUtil.GetDisplayedItem and tooltip then
        local ok, _, link = pcall(TooltipUtil.GetDisplayedItem, tooltip)
        if ok and type(link) == "string" then return link end
    end
end

local function fieldSettings()
    local saved = GoldPilotDB and GoldPilotDB.settings and GoldPilotDB.settings.tooltipFields or {}
    return { vendor = saved.vendor ~= false, last = saved.last ~= false,
        median = saved.median ~= false, advice = saved.advice ~= false }
end

function Tooltip:add(tooltip, data)
    if inCombat() then return end
    local settings = GoldPilotDB and GoldPilotDB.settings
    if settings and settings.tooltip == false then return end
    local link = linkFromTooltip(tooltip, data)
    local itemID = itemIDFromTooltip(tooltip, data)
    if not itemID and link then itemID = addon.ItemKey.itemID(addon.ItemKey.fromLink(link, false)) end
    if not itemID then return end
    local key = link and addon.ItemKey.fromLink(link, addon.ItemKey.isGear(itemID)) or nil
    if addon.ItemKey.itemID(key) ~= itemID then key = itemID end
    local nowOk, now = addon.Compat.call("time")
    if not nowOk or not tonumber(now) then return end
    local houseKey = addon.AuctionHouse.houseKey()
    local db = GoldPilotDB or {}
    local known = addon.DataItems and addon.DataItems[itemID]
    local observation = addon.Prices.get(db, houseKey, key)
    if addon.AuctionHouse:isOpen() and (not observation or tonumber(now) - (tonumber(observation.t) or 0) >= 600) then
        addon.AuctionHouse:enqueue(itemID, true)
    end
    if not known and not observation then return end
    local value = addon.Valuation.value(db, houseKey, key, now)
    local vendor = value.vendor and value.vendor.price
    local ref = value.ref
    local stale = not ref and value.why and value.why.reason == "stale" and value.why.best
    local shown = ref or stale
    local cut = db.houses and db.houses[houseKey] and db.houses[houseKey].cut
    local recommendation = addon.Advisor.recommend(vendor, ref and ref.price, cut)
    local fields = fieldSettings()
    local L = addon.L
    local dim = "|cff8a8a8a"

    local rows = {}
    local function row(label, text) rows[#rows + 1] = { label, text } end
    local function dimmed(text) return dim .. text .. "|r" end
    local function money(copper, isStale) return isStale and dimmed(addon.Theme.money(copper)) or addon.Theme.money(copper) end

    if fields.vendor then
        row(L.TOOLTIP_ROW_VENDOR, vendor and addon.Theme.money(vendor) or dimmed(L.TOOLTIP_NO_VENDOR))
    end
    if observation then
        local isStale = not ref
        if fields.last then row(L.TOOLTIP_ROW_LAST, money(observation.min, isStale)) end
        if fields.median then row(L.TOOLTIP_ROW_MEDIAN, money(shown and shown.price or observation.p50, isStale)) end
        if fields.advice and ref and recommendation.action then
            local action = recommendation.action == "auction" and L.TOOLTIP_AUCTION or L.TOOLTIP_SELLER
            local color = recommendation.action == "auction" and "|cff59e666" or "|cffffcc40"
            row(L.TOOLTIP_ROW_ADVICE, color .. action .. "|r")
        end
    elseif fields.last or fields.median then
        row(L.TOOLTIP_ROW_AUCTION, dimmed(L.TOOLTIP_NO_AUCTION))
    end

    local expanded = IsShiftKeyDown and IsShiftKeyDown()
    if expanded and observation then
        row(L.TOOLTIP_ROW_FORSALE, string.format(L.TOOLTIP_UNITS, observation.qty))
        local trend = addon.Prices.trend(db, houseKey, key, tonumber(now))
        if trend then
            local text
            if trend.percent > 2 then text = string.format(L.TOOLTIP_TREND_UP, trend.percent, trend.days)
            elseif trend.percent < -2 then text = string.format(L.TOOLTIP_TREND_DOWN, -trend.percent, trend.days)
            else text = string.format(L.TOOLTIP_TREND_FLAT, trend.days) end
            row(L.TOOLTIP_ROW_TREND, text)
        end
        if recommendation.cutAssumed then row(L.TOOLTIP_ROW_CUT, dimmed(L.TOOLTIP_CUT_ASSUMED)) end
    elseif expanded and not observation then
        row(L.TOOLTIP_ROW_FORSALE, dimmed(L.TOOLTIP_DETAILS_NONE))
    end
    if #rows == 0 then return end

    local info = ""
    if observation then
        local age = addon.Theme.age(math.max(0, tonumber(now) - observation.t))
        info = dimmed(age .. (stale and (" - " .. L.TOOLTIP_STALE) or "")) .. " " .. addon.Theme.badge(observation.src or "OBS")
    end
    if tooltip.AddDoubleLine then
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine(L.TOOLTIP_HEADER, info, 1, 0.82, 0.2, 1, 1, 1)
        for _, entry in ipairs(rows) do
            tooltip:AddDoubleLine(entry[1], entry[2], 0.78, 0.72, 0.55, 1, 1, 1)
        end
    else
        tooltip:AddLine(L.TOOLTIP_HEADER .. (info ~= "" and (" " .. info) or ""))
        for _, entry in ipairs(rows) do tooltip:AddLine(entry[1] .. ": " .. entry[2]) end
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
