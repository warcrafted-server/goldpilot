local _, addon = ...

-- Escaneo completo de la casa de subastas con C_AuctionHouse.ReplicateItems, como hace Auctionator.
-- El servidor lo limita a uno cada 15 min; si no responde se vuelve a la cola. El evento de resultados puede
-- llegar varias veces (solo vale la primera) y el trabajo se reparte en trozos para no congelar el juego.
local FullScan = { inProgress = false }
addon.FullScan = FullScan

local COOLDOWN, TIMEOUT, SLICE_MS, SLICE_ITEMS = 15 * 60, 120, 6, 200
-- El cliente carga los objetos poco a poco: se insiste mientras sigan llegando enlaces.
local MAX_ROUNDS, MAX_STALLED, ROUND_DELAY = 15, 3, 2
local ticket = 0
local PET_CAGE = 82800 -- todas las mascotas comparten este identificador: un precio medio no significa nada

local function now()
    local ok, value = addon.Compat.call("time")
    return ok and tonumber(value) or 0
end

local function enabledByUser()
    local settings = GoldPilotDB and GoldPilotDB.settings
    return not (settings and settings.fullScan == false)
end

-- Sin reloj de alta resolución (pruebas) se procesa un número fijo de elementos por trozo.
local function clock()
    if debugprofilestop then return debugprofilestop() end
end

function FullScan:secondsLeft()
    local last = GoldPilotDB and GoldPilotDB.scan and tonumber(GoldPilotDB.scan.t)
    if not last then return 0 end
    return math.max(0, COOLDOWN - (now() - last))
end

local function finish(ok, message)
    FullScan.inProgress, FullScan.receiving = false, false
    ticket = ticket + 1
    addon.AuctionHouse.scanning = false
    addon.Log:info(message)
    addon.AuctionHouse:_pump()
    return ok
end

-- Ejecuta step(i) para i = 1..total repartido en fotogramas y llama a done() al terminar.
local function sliced(total, step, done, mine)
    local index = 1
    local function run()
        if mine ~= ticket then return end
        local started = clock()
        local limit = index + SLICE_ITEMS - 1
        while index <= total do
            step(index)
            index = index + 1
            if started then
                if clock() - started > SLICE_MS then break end
            elseif index > limit then break end
        end
        if index <= total then addon.Compat.call("C_Timer.After", 0, run) else done() end
    end
    run()
end

local function process(count)
    local mine = ticket
    local getInfo = C_AuctionHouse.GetReplicateItemInfo
    local getLink = C_AuctionHouse.GetReplicateItemLink
    local listings, order, seen, pending, requested, registered = {}, {}, {}, {}, {}, {}

    local function add(itemID, key, price, quantity)
        local entries = listings[key]
        if not entries then
            entries = {}
            listings[key], order[#order + 1] = entries, key
        end
        entries[#entries + 1] = { price = price / quantity, qty = quantity }
        seen[itemID] = true
    end

    local function read(position)
        local ok, _, _, quantity, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = pcall(getInfo, position - 1)
        quantity, buyout, itemID = tonumber(quantity), tonumber(buyout), tonumber(itemID)
        if not (ok and itemID and itemID ~= PET_CAGE and quantity and quantity > 0 and buyout and buyout > 0) then return end
        if addon.ItemKey.isGear(itemID) then
            local linkOK, link = false, nil
            if type(getLink) == "function" then linkOK, link = pcall(getLink, position - 1) end
            local key = linkOK and addon.ItemKey.fromLink(link, true)
            if key then add(itemID, key, buyout, quantity)
            else
                pending[#pending + 1] = { position = position, itemID = itemID, price = buyout, qty = quantity }
                if not requested[itemID] then
                    requested[itemID] = true
                    addon.Compat.call("C_Item.RequestLoadItemDataByID", itemID)
                end
            end
        else
            add(itemID, itemID, buyout, quantity)
        end
    end

    local function record(position)
        local key = order[position]
        if addon.AuctionHouse:recordListings(key, listings[key]) then registered[key] = true end
        listings[key] = nil
    end

    local function complete()
        addon.AuctionHouse:resolveQueue(seen)
        local items, keys = 0, 0
        for _ in pairs(seen) do items = items + 1 end
        for _ in pairs(registered) do keys = keys + 1 end
        local previous = GoldPilotDB.scan or {}
        GoldPilotDB.scan = { t = previous.t or now(), items = items, keys = keys, ads = count,
            noLink = #pending }
        finish(true, string.format(addon.L.SCAN_DONE, items))
    end

    local function recordAndFinish()
        sliced(#order, record, complete, mine)
    end

    local function retry(round, stalled)
        if mine ~= ticket then return end
        local unresolved, before, asked = {}, #pending, {}
        sliced(#pending, function(index)
            local ad = pending[index]
            local linkOK, link = false, nil
            if type(getLink) == "function" then linkOK, link = pcall(getLink, ad.position - 1) end
            local key = linkOK and addon.ItemKey.fromLink(link, true)
            if key then add(ad.itemID, key, ad.price, ad.qty)
            else
                unresolved[#unresolved + 1] = ad
                if not asked[ad.itemID] then
                    asked[ad.itemID] = true
                    addon.Compat.call("C_Item.RequestLoadItemDataByID", ad.itemID)
                end
            end
        end, function()
            pending = unresolved
            stalled = #pending < before and 0 or stalled + 1
            if #pending == 0 or round >= MAX_ROUNDS or stalled >= MAX_STALLED then recordAndFinish()
            else addon.Compat.call("C_Timer.After", ROUND_DELAY, function() retry(round + 1, stalled) end) end
        end, mine)
    end

    sliced(count, read, function()
        if #pending == 0 then recordAndFinish()
        else addon.Compat.call("C_Timer.After", 1, function() retry(1, 0) end) end
    end, mine)
end

local function onReplicate()
    if not FullScan.inProgress or FullScan.receiving then return end
    FullScan.receiving = true
    local ok, count = addon.Compat.call("C_AuctionHouse.GetNumReplicateItems")
    count = ok and tonumber(count) or 0
    if count <= 0 then
        finish(false, addon.L.SCAN_EMPTY)
        return
    end
    process(count)
end

-- manual = true ignora la preferencia del jugador, pero no el límite de tiempo del servidor.
function FullScan:start(manual)
    if self.inProgress or not addon.AuctionHouse:isOpen() then return false, "closed" end
    if not addon.Compat.has("C_AuctionHouse.ReplicateItems") then return false, "unsupported" end
    if not manual and not enabledByUser() then return false, "disabled" end
    local left = self:secondsLeft()
    if left > 0 then return false, "cooldown", left end
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.scan = { t = now() }
    self.inProgress, self.receiving = true, false
    addon.AuctionHouse.scanning = true
    ticket = ticket + 1
    local mine = ticket
    local ok = addon.Compat.call("C_AuctionHouse.ReplicateItems")
    if not ok then finish(false, addon.L.SCAN_EMPTY); return false, "error" end
    addon.Log:info(addon.L.SCAN_START)
    addon.Compat.call("C_Timer.After", TIMEOUT, function()
        if FullScan.inProgress and not FullScan.receiving and mine == ticket then finish(false, addon.L.SCAN_TIMEOUT) end
    end)
    return true
end

function FullScan:maybeStart() return self:start(false) end

function FullScan:command()
    local started, reason, left = self:start(true)
    if started then return end
    if reason == "closed" then addon.Log:info(self.inProgress and addon.L.SCAN_START or addon.L.SCAN_CLOSED)
    elseif reason == "cooldown" then addon.Log:info(string.format(addon.L.SCAN_COOLDOWN, math.ceil(left / 60)))
    elseif reason == "unsupported" then addon.Log:info(addon.L.SCAN_UNSUPPORTED) end
end

addon.Modules:register("fullscan", {
    requires = { "C_AuctionHouse.ReplicateItems" },
    onEnable = function()
        addon.Events:subscribe("fullscan", "REPLICATE_ITEM_LIST_UPDATE", onReplicate)
        addon.Events:subscribe("fullscan", "AUCTION_HOUSE_CLOSED", function()
            FullScan.inProgress, FullScan.receiving = false, false
            ticket = ticket + 1
        end)
    end,
})

return FullScan
