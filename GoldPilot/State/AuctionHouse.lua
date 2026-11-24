local _, addon = ...

addon.AuctionHouse = {}
local AuctionHouse = addon.AuctionHouse
local MAX_QUEUE, PROGRESS_EVERY = 1000, 10
local queue, current, done, finished, generation = {}, nil, 0, 0, 0
local retryScheduled = false
local MAX_LOADS, FRESH = 4, 15 * 60
local loads = {}
local sessionActive = false
local isOpen = false

local function now()
    local ok, value = addon.Compat.call("time")
    return ok and tonumber(value) or 0
end

local function houseKey()
    local _, faction = addon.Compat.call("UnitFactionGroup", "player")
    if type(faction) ~= "string" or faction == "" then faction = "unknown" end
    -- Las casas neutrales aún no se distinguen; queda pendiente investigarlo.
    return faction
end

AuctionHouse.houseKey = houseKey
function AuctionHouse:isOpen() return isOpen end

local function validItem(itemID)
    itemID = tonumber(itemID)
    return itemID and addon.DataItems and addon.DataItems[itemID] and itemID or nil
end

local function contains(itemID)
    if current == itemID then return true end
    for _, queued in ipairs(queue) do if queued == itemID then return true end end
    return false
end

local function sessionItemCount(last)
    local seen, count = {}, 0
    for _, itemID in ipairs(last.queued or {}) do
        if not seen[itemID] then seen[itemID], count = true, count + 1 end
    end
    for itemID in pairs(last.result or {}) do
        if not seen[itemID] then seen[itemID], count = true, count + 1 end
    end
    return count
end

function AuctionHouse:enqueue(itemID, front)
    itemID = tonumber(itemID)
    local valid = validItem(itemID)
    if not valid then
        local last = GoldPilotDB and GoldPilotDB.ahLast
        if front and last and itemID and not last.result[itemID] and sessionItemCount(last) < MAX_QUEUE then last.result[itemID] = "nodata" end
        return false
    end
    itemID = valid
    local last = GoldPilotDB and GoldPilotDB.ahLast
    if contains(itemID) or (last and last.result[itemID]) then return false end
    sessionActive = true
    if last and sessionItemCount(last) >= MAX_QUEUE then return false end
    if last then table.insert(last.queued, front and (current and 2 or 1) or (#last.queued + 1), itemID) end
    if front then table.insert(queue, 1, itemID) else queue[#queue + 1] = itemID end
    self:_pump()
    return true
end

-- Usado por el escaneo completo: registra los anuncios de un objeto y lo saca de la cola.
function AuctionHouse:recordListings(itemID, listings)
    local summary = addon.Prices.summarize(listings, addon.Prices.defaults.share)
    if not summary then return false end
    GoldPilotDB = GoldPilotDB or {}
    addon.Prices.record(GoldPilotDB, houseKey(), itemID, summary, now())
    return true
end

-- Tras un escaneo completo, lo que sigue en cola y no apareció no tiene anuncios.
function AuctionHouse:resolveQueue(seen)
    local last = GoldPilotDB and GoldPilotDB.ahLast
    for _, itemID in ipairs(queue) do
        if last then last.result[itemID] = seen[itemID] and "ok" or "empty" end
        finished = finished + 1
    end
    queue = {}
    sessionActive = false
end

function AuctionHouse:status()
    return { pending = #queue, current = current, done = done, finished = finished,
        total = finished + #queue + (current and 1 or 0) }
end

local function finishCurrent(result)
    if current and GoldPilotDB and GoldPilotDB.ahLast then GoldPilotDB.ahLast.result[current] = result or "timeout" end
    current = nil
    finished = finished + 1
    generation = generation + 1
    if #queue > 0 and finished % PROGRESS_EVERY == 0 then
        addon.Log:info(string.format(addon.L.AH_PROGRESS, finished, finished + #queue))
    end
    AuctionHouse:_pump()
end

local function itemKey(itemID)
    local ok, key = addon.Compat.call("C_AuctionHouse.MakeItemKey", itemID)
    if ok then return key end
end

-- Lee los resultados de búsqueda que el cliente tiene de un objeto y los registra.
local function readResults(itemID, key, commodity)
    local listings = {}
    local variants = {}
    local gear = addon.ItemKey.isGear(itemID) and not commodity
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
                    local listing = { price = tonumber(info.buyoutAmount), qty = tonumber(info.quantity) or 1 }
                    if gear then
                        local variant = addon.ItemKey.fromLink(info.itemLink, true)
                        if variant then
                            variants[variant] = variants[variant] or {}
                            variants[variant][#variants[variant] + 1] = listing
                        end
                    else
                        listings[#listings + 1] = listing
                    end
                end
            end
        end
    end
    if gear then
        local registered, firstSummary = false, nil
        for variant, entries in pairs(variants) do
            local summary = addon.Prices.summarize(entries, addon.Prices.defaults.share)
            if summary then
                GoldPilotDB = GoldPilotDB or {}
                addon.Prices.record(GoldPilotDB, houseKey(), variant, summary, now())
                firstSummary, registered = firstSummary or summary, true
            end
        end
        return registered and firstSummary or nil
    end
    local summary = addon.Prices.summarize(listings, addon.Prices.defaults.share)
    if summary then
        GoldPilotDB = GoldPilotDB or {}
        addon.Prices.record(GoldPilotDB, houseKey(), itemID, summary, now())
    end
    return summary
end

local function query(itemID, key, commodity)
    local summary = readResults(itemID, key, commodity)
    done = done + 1
    finishCurrent(summary and "ok" or "empty")
end

-- Resultado de una búsqueda ajena a la cola (del jugador u otro addon): se aprovecha y se saca de la cola.
local function observeOther(itemID, key, commodity)
    local valid = tonumber(itemID)
    if not valid or valid <= 0 then return end
    local summary = readResults(valid, key or itemKey(valid), commodity)
    if not summary then return end
    for index, queued in ipairs(queue) do
        if queued == valid then
            table.remove(queue, index)
            local last = GoldPilotDB.ahLast
            if last then last.result[valid] = "ok" end
            finished = finished + 1
            break
        end
    end
end

local function onCommodityResults(itemID)
    itemID = tonumber(itemID)
    if not itemID then return end
    if current and itemID == current then query(current, itemKey(current), true)
    else observeOther(itemID, nil, true) end
end

local function onItemResults(key)
    local itemID = type(key) == "table" and tonumber(key.itemID) or tonumber(key)
    if current and (itemID == nil or itemID == current) then query(current, itemKey(current), false)
    elseif itemID then observeOther(itemID, type(key) == "table" and key or nil, false) end
end

function AuctionHouse:_pump()
    if self.scanning then return end
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
    if not key then finishCurrent("senderror"); return end
    -- El cliente ignora la búsqueda de un objeto cuyos datos no tiene cargados (típico de otros personajes):
    -- se piden, el objeto pasa al final y se reintenta.
    if addon.Compat.has("C_AuctionHouse.GetItemKeyInfo") then
        local infoOk, info = addon.Compat.call("C_AuctionHouse.GetItemKeyInfo", key)
        if infoOk and not info then
            loads[itemID] = (loads[itemID] or 0) + 1
            if loads[itemID] > MAX_LOADS then finishCurrent("noinfo"); return end
            addon.Compat.call("C_Item.RequestLoadItemDataByID", itemID)
            current = nil
            queue[#queue + 1] = itemID
            if not retryScheduled then
                retryScheduled = true
                addon.Compat.call("C_Timer.After", 0.3, function() retryScheduled = false; AuctionHouse:_pump() end)
            end
            return
        end
    end
    local sendOk = addon.Compat.call("C_AuctionHouse.SendSearchQuery", key, {}, false)
    if not sendOk then finishCurrent("senderror"); return end
    generation = generation + 1
    local ticket = generation
    addon.Compat.call("C_Timer.After", 8, function()
        if current == itemID and generation == ticket then finishCurrent("timeout") end
    end)
end

local function buildQueue()
    queue, current, done, finished = {}, nil, 0, 0
    sessionActive = true
    local seen = {}
    local function append(items, sortByCount)
        local list = {}
        for itemID, count in pairs(items or {}) do
            local valid = validItem(itemID)
            if valid and not seen[valid] then list[#list + 1] = { id = valid, count = tonumber(count) or 0 } end
        end
        table.sort(list, function(a, b)
            if sortByCount and a.count ~= b.count then return a.count > b.count end
            return a.id < b.id
        end)
        for _, entry in ipairs(list) do
            queue[#queue + 1], seen[entry.id] = entry.id, true
        end
    end
    local watch = {}
    for itemID in pairs(GoldPilotDB.watch or {}) do
        local valid = validItem(itemID)
        if valid then watch[#watch + 1] = valid end
    end
    table.sort(watch)
    for _, itemID in ipairs(watch) do
        if not seen[itemID] then queue[#queue + 1] = itemID; seen[itemID] = true end
    end
    append(addon.Bags:scan(), true)
    local chars = GoldPilotDB.chars or {}
    local currentName = select(2, addon.Compat.call("UnitName", "player"))
    local own = chars[currentName or "unknown"] or {}
    append(own.bank, true)
    append(addon.Bags:scanEquipped(), false)
    local others, otherItems = {}, {}
    for name, char in pairs(chars) do
        if name ~= currentName and type(char) == "table" then others[#others + 1] = { name = name, char = char } end
    end
    table.sort(others, function(a, b)
        local sa, sb = tonumber(a.char.seen) or 0, tonumber(b.char.seen) or 0
        if sa == sb then return a.name < b.name end
        return sa > sb
    end)
    for _, entry in ipairs(others) do
        for _, inventory in ipairs({ entry.char.bags or {}, entry.char.bank or {}, entry.char.equipped or {} }) do
            for itemID, count in pairs(inventory) do
                local id = tonumber(itemID)
                if id then otherItems[id] = (otherItems[id] or 0) + (tonumber(count) or 0) end
            end
        end
    end
    append(otherItems, true)
    -- Lo leído hace poco (por un escaneo o una búsqueda) no se vuelve a pedir.
    local limit = now() - FRESH
    for index = #queue, 1, -1 do
        local itemID = queue[index]
        local scan = GoldPilotDB.scan
        if addon.ItemKey.isGear(itemID) and scan and tonumber(scan.t) and tonumber(scan.t) > limit and tonumber(scan.items) then
            table.remove(queue, index)
        else
            local price = addon.Prices.get(GoldPilotDB, houseKey(), itemID)
            if price and (tonumber(price.t) or 0) > limit then table.remove(queue, index) end
        end
    end
    while #queue > MAX_QUEUE do table.remove(queue) end
    loads = {}
    sessionActive = #queue > 0
    for _, itemID in ipairs(queue) do addon.Compat.call("C_Item.RequestLoadItemDataByID", itemID) end
    local last = GoldPilotDB.ahLast
    for _, itemID in ipairs(queue) do last.queued[#last.queued + 1] = itemID end
end

local function opened()
    isOpen = true
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.houses = GoldPilotDB.houses or {}
    local key = houseKey()
    GoldPilotDB.ahLast = { t = now(), houseKey = key, queued = {}, result = {} }
    local _, cut = addon.Compat.call("C_AuctionHouse.GetAuctionHouseCut")
    GoldPilotDB.houses[key] = { lastSeen = now(), cut = tonumber(cut) }
    buildQueue()
    if addon.FullScan then addon.FullScan:maybeStart() end
    AuctionHouse:_pump()
end

local function closed()
    isOpen = false
    AuctionHouse.scanning = false
    queue, current, done, finished = {}, nil, 0, 0
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
