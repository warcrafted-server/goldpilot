local _, addon = ...

addon.AuctionHouse = {}
local AuctionHouse = addon.AuctionHouse
local queue, current, done, generation = {}, nil, 0, 0
local retryScheduled = false
local sessionActive = false

local function now()
    local ok, value = pcall(time)
    return ok and tonumber(value) or 0
end

local function houseKey()
    local _, faction = addon.Compat.call("UnitFactionGroup", "player")
    local _, realm = addon.Compat.call("GetRealmName")
    if type(faction) ~= "string" or faction == "" then faction = "unknown" end
    if type(realm) ~= "string" or realm == "" then realm = "unknown" end
    return faction .. "-" .. realm
end

AuctionHouse.houseKey = houseKey

local function validItem(itemID)
    itemID = tonumber(itemID)
    return itemID and addon.DataItems and addon.DataItems[itemID] and itemID or nil
end

local function contains(itemID)
    if current == itemID then return true end
    for _, queued in ipairs(queue) do if queued == itemID then return true end end
    return false
end

function AuctionHouse:enqueue(itemID, front)
    itemID = validItem(itemID)
    if not itemID or contains(itemID) then return false end
    sessionActive = true
    if front then table.insert(queue, 1, itemID) else queue[#queue + 1] = itemID end
    self:_pump()
    return true
end

function AuctionHouse:status()
    return { pending = #queue, current = current, done = done }
end

local function finishCurrent()
    current = nil
    generation = generation + 1
    AuctionHouse:_pump()
end

local function itemKey(itemID)
    local ok, key = addon.Compat.call("C_AuctionHouse.MakeItemKey", itemID)
    if ok then return key end
end

local function query(itemID, key, commodity)
    local listings = {}
    local ok, count = false, nil
    if commodity then ok, count = addon.Compat.call("C_AuctionHouse.GetNumCommoditySearchResults", itemID) end
    if ok and tonumber(count) then
        for i = 1, tonumber(count) do
            local infoOk, info = addon.Compat.call("C_AuctionHouse.GetCommoditySearchResultInfo", itemID, i)
            if infoOk and type(info) == "table" and tonumber(info.unitPrice) and tonumber(info.quantity) then
                listings[#listings + 1] = { price = tonumber(info.unitPrice), qty = tonumber(info.quantity) }
            end
        end
    else
        local itemsOk, itemsCount = addon.Compat.call("C_AuctionHouse.GetNumItemSearchResults", key)
        if itemsOk and tonumber(itemsCount) then
            for i = 1, tonumber(itemsCount) do
                local infoOk, info = addon.Compat.call("C_AuctionHouse.GetItemSearchResultInfo", key, i)
                if infoOk and type(info) == "table" and tonumber(info.buyoutAmount) then
                    listings[#listings + 1] = { price = tonumber(info.buyoutAmount), qty = tonumber(info.quantity) or 1 }
                end
            end
        end
    end
    local summary = addon.Prices.summarize(listings, addon.Prices.defaults.share)
    if summary then addon.Prices.record(GoldPilotDB, houseKey(), itemID, summary, now()) end
    done = done + 1
    finishCurrent()
end

local function onCommodityResults(itemID)
    if current and tonumber(itemID) == current then query(current, itemKey(current), true) end
end

local function onItemResults(itemID)
    if current then query(current, itemKey(current), false) end
end

function AuctionHouse:_pump()
    if current or #queue == 0 then
        if not current and #queue == 0 and sessionActive then
            addon.Log:info(string.format(addon.L.AH_DONE, done))
            sessionActive = false
        end
        return
    end
    local throttleOk, ready = addon.Compat.call("C_AuctionHouse.IsThrottledMessageSystemReady")
    if throttleOk and ready == false then
        if not retryScheduled then
            retryScheduled = true
            addon.Compat.call("C_Timer.After", 1, function() retryScheduled = false; AuctionHouse:_pump() end)
        end
        return
    end
    current = table.remove(queue, 1)
    local itemID = current
    local key = itemKey(itemID)
    if not key then finishCurrent(); return end
    local sendOk = addon.Compat.call("C_AuctionHouse.SendSearchQuery", key, {}, false)
    if not sendOk then finishCurrent(); return end
    generation = generation + 1
    local ticket = generation
    addon.Compat.call("C_Timer.After", 8, function()
        if current == itemID and generation == ticket then finishCurrent() end
    end)
end

local function buildQueue()
    queue, current, done = {}, nil, 0
    sessionActive = true
    local seen = {}
    local watch = {}
    for itemID in pairs(GoldPilotDB.watch or {}) do
        local valid = validItem(itemID)
        if valid then watch[#watch + 1] = valid end
    end
    table.sort(watch)
    for _, itemID in ipairs(watch) do
        if not seen[itemID] then queue[#queue + 1] = itemID; seen[itemID] = true end
    end
    local bags = addon.Bags:scan()
    local bagItems = {}
    for itemID, count in pairs(bags) do
        local valid = validItem(itemID)
        if valid and not seen[valid] then bagItems[#bagItems + 1] = { id = valid, count = tonumber(count) or 0 } end
    end
    table.sort(bagItems, function(a, b) if a.count == b.count then return a.id < b.id end return a.count > b.count end)
    for _, entry in ipairs(bagItems) do
        queue[#queue + 1] = entry.id
        seen[entry.id] = true
    end
end

local function opened()
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.houses = GoldPilotDB.houses or {}
    local key = houseKey()
    local _, cut = addon.Compat.call("C_AuctionHouse.GetAuctionHouseCut")
    GoldPilotDB.houses[key] = { lastSeen = now(), cut = tonumber(cut) }
    buildQueue()
    AuctionHouse:_pump()
end

local function closed()
    queue, current, done = {}, nil, 0
    sessionActive = false
    generation = generation + 1
end

addon.Modules:register("auctionhouse", {
    requires = { "C_AuctionHouse.SendSearchQuery" },
    onEnable = function()
        addon.Events:subscribe("auctionhouse", "AUCTION_HOUSE_SHOW", opened)
        addon.Events:subscribe("auctionhouse", "AUCTION_HOUSE_CLOSED", closed)
        addon.Events:subscribe("auctionhouse", "COMMODITY_SEARCH_RESULTS_UPDATED", onCommodityResults)
        addon.Events:subscribe("auctionhouse", "ITEM_SEARCH_RESULTS_UPDATED", onItemResults)
        addon.Events:subscribe("auctionhouse", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY", function() AuctionHouse:_pump() end)
    end,
})
