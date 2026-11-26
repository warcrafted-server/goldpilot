local _, addon = ...

-- Escaneo completo de la casa de subastas con C_AuctionHouse.ReplicateItems, como hace Auctionator.
-- El servidor lo limita a uno cada 15 min; si no responde se vuelve a la cola. El evento de resultados puede
-- llegar varias veces (solo vale la primera) y el trabajo se reparte en trozos para no congelar el juego.
local FullScan = { inProgress = false }
addon.FullScan = FullScan

local COOLDOWN, TIMEOUT, SLICE_MS, SLICE_ITEMS = 15 * 60, 120, 10, 200
-- El cliente carga los objetos poco a poco: se insiste mientras sigan llegando enlaces.
local MAX_ROUNDS, MAX_STALLED, ROUND_DELAY = 15, 3, 2
local ticket = 0
local PET_CAGE = 82800 -- todas las mascotas comparten este identificador: un precio medio no significa nada

local function now()
    local ok, value = addon.Compat.call("time")
    return ok and tonumber(value) or 0
end

local function enabledByUser()
    return addon.Settings.get("fullScan") ~= false
end

-- El progreso viaja como mensaje interno; se avisa al cambiar de fase y al acabar cada trozo, no por cada anuncio.
local function setPhase(phase, total)
    if not FullScan.inProgress then return end
    local previous = FullScan.progress
    local started = previous and previous.started or now()
    -- expected (la espera del escaneo anterior) solo sirve para estimar el porcentaje mientras se espera.
    FullScan.progress = { phase = phase, done = 0, total = total or 0, started = started,
        expected = previous and previous.expected or nil }
    addon.Events:send("GOLDPILOT_SCAN_PROGRESS", FullScan.progress)
end

-- Se conserva por compatibilidad; los suscriptores nuevos usan el mensaje directamente.
function FullScan:onProgress(fn)
    if type(fn) ~= "function" then return end
    addon.Events:subscribe("fullscan-progress", "GOLDPILOT_SCAN_PROGRESS", fn)
    if self.progress then fn(self.progress) end
end

function FullScan:percent()
    local progress = self.progress
    if not progress or progress.phase == "cooldown" then return 0 end
    if progress.phase == "wait" then
        local expected = tonumber(progress.expected) or 0
        if expected <= 0 then expected = 30 end
        local elapsed = math.max(0, now() - (tonumber(progress.started) or now()))
        -- Se queda en el 49 % para no dar por hecha una espera que aún puede alargarse.
        return math.min(49, math.floor(elapsed / expected * 50))
    end
    if not progress.total or progress.total <= 0 then return 0 end
    local done = math.min(progress.total, math.max(0, tonumber(progress.done) or 0))
    local ratio = done / progress.total
    -- La lectura ocupa del 50 al 92 % y el registro de precios el resto.
    if progress.phase == "record" then return math.floor(92 + ratio * 8) end
    if progress.phase == "read" then return math.floor(50 + ratio * 42) end
    return 0
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

local function clockTime(timestamp)
    local ok, value = addon.Compat.call("date", "%H:%M", timestamp)
    return ok and tostring(value) or "--:--"
end

-- Deja la cuenta atrás en la barra y programa el inicio para cuando expire el límite del servidor.
-- Solo vale el último aviso: cerrar la subasta o reprogramar cancela el temporizador anterior.
local function waitCooldown(left, manual)
    local last = GoldPilotDB and GoldPilotDB.scan and tonumber(GoldPilotDB.scan.t) or (now() - COOLDOWN)
    local available = last + COOLDOWN
    FullScan.progress = { phase = "cooldown", ["until"] = available }
    addon.Events:send("GOLDPILOT_SCAN_PROGRESS", FullScan.progress)
    addon.Timer.cancelAll("fullscan")
    addon.Timer.after(left + 1, function()
        if FullScan.inProgress or not addon.AuctionHouse:isOpen() then return end
        if not FullScan:start(manual) and FullScan.progress and FullScan.progress.phase == "cooldown" then
            FullScan.progress = nil
            addon.Events:send("GOLDPILOT_SCAN_PROGRESS", nil)
        end
    end, "fullscan")
    return available
end

local function finish(ok, message)
    FullScan.inProgress, FullScan.receiving = false, false
    FullScan.progress = nil
    ticket = ticket + 1
    addon.AuctionHouse.scanning = false
    addon.Log:info(message)
    addon.Events:send("GOLDPILOT_SCAN_PROGRESS", nil)
    addon.AuctionHouse:_pump()
    return ok
end

-- Ejecuta step(i) para i = 1..total repartido en fotogramas y llama a done() al terminar.
-- track actualiza el progreso al final de cada trozo; los reintentos en segundo plano no cuentan.
local function sliced(total, step, done, mine, track)
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
        if track and FullScan.progress then
            FullScan.progress.done, FullScan.progress.total = math.min(index - 1, total), total
            addon.Events:send("GOLDPILOT_SCAN_PROGRESS", FullScan.progress)
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

    local wanted = addon.Ledger.unknownNames(GoldPilotDB)

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
        local ok, name, _, quantity, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = pcall(getInfo, position - 1)
        quantity, buyout, itemID = tonumber(quantity), tonumber(buyout), tonumber(itemID)
        if ok and itemID and name and wanted[name] then
            addon.Ledger.learn(GoldPilotDB, name, itemID)
            wanted[name] = nil
        end
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

    -- Las variantes de un objeto con anuncios aún sin enlace se registran al final, completas.
    local held, flushed = {}, false
    local function record(position, late)
        local key = order[position]
        if not listings[key] or (not late and held[addon.ItemKey.itemID(key)]) then return end
        if addon.AuctionHouse:recordListings(key, listings[key]) then registered[key] = true end
        listings[key] = nil
    end

    local function saveStats(phase)
        local previous = GoldPilotDB.scan or {}
        local items, keys = 0, 0
        for _ in pairs(seen) do items = items + 1 end
        for _ in pairs(registered) do keys = keys + 1 end
        GoldPilotDB.scan = { t = previous.t or now(), items = items, keys = keys, ads = count, noLink = #pending,
            wait = previous.wait, main = previous.main, late = previous.late }
        GoldPilotDB.scan[phase] = now() - GoldPilotDB.scan.t
        return items, keys
    end

    local function flush()
        if flushed then return end
        flushed, FullScan.flush = true, nil
        sliced(#order, function(position) record(position, true) end, function() saveStats("late") end, ticket)
    end

    local function retry(round, stalled)
        if flushed or mine ~= ticket then return end
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
            if flushed then return end
            pending = unresolved
            stalled = #pending < before and 0 or stalled + 1
            if #pending == 0 or round >= MAX_ROUNDS or stalled >= MAX_STALLED then flush()
            else addon.Compat.call("C_Timer.After", ROUND_DELAY, function() retry(round + 1, stalled) end) end
        end, mine)
    end

    local function publish()
        addon.AuctionHouse:resolveQueue(seen)
        local items, keys = saveStats("main")
        finish(true, string.format(addon.L.SCAN_DONE, items, keys))
        if #pending == 0 then return end
        -- El resto sigue en segundo plano: finish cambia el ticket y cerrar la subasta llama a flush.
        mine = ticket
        FullScan.flush = flush
        addon.Compat.call("C_Timer.After", ROUND_DELAY, function() retry(1, 0) end)
    end

    setPhase("read", count)
    sliced(count, read, function()
        for _, ad in ipairs(pending) do held[ad.itemID], seen[ad.itemID] = true, true end
        setPhase("record", #order)
        sliced(#order, record, publish, mine, true)
    end, mine, true)
end

local function onReplicate()
    if not FullScan.inProgress or FullScan.receiving then return end
    FullScan.receiving = true
    if GoldPilotDB and GoldPilotDB.scan then
        GoldPilotDB.scan.wait = now() - (tonumber(GoldPilotDB.scan.t) or now())
    end
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
    -- Hay que leer la espera del escaneo anterior antes de que GoldPilotDB.scan se sobrescriba.
    local expected = tonumber(GoldPilotDB.scan and GoldPilotDB.scan.wait) or 0
    GoldPilotDB.scan = { t = now() }
    self.inProgress, self.receiving = true, false
    addon.AuctionHouse.scanning = true
    ticket = ticket + 1
    local mine = ticket
    self.progress = { phase = "wait", done = 0, total = 0, started = GoldPilotDB.scan.t,
        expected = expected > 0 and expected or 30 }
    addon.Events:send("GOLDPILOT_SCAN_PROGRESS", self.progress)
    local ok = addon.Compat.call("C_AuctionHouse.ReplicateItems")
    if not ok then finish(false, addon.L.SCAN_EMPTY); return false, "error" end
    addon.Log:info(addon.L.SCAN_START)
    addon.Compat.call("C_Timer.After", TIMEOUT, function()
        if FullScan.inProgress and not FullScan.receiving and mine == ticket then finish(false, addon.L.SCAN_TIMEOUT) end
    end)
    return true
end

function FullScan:maybeStart()
    local started, reason, left = self:start(false)
    if not started and reason == "cooldown" and enabledByUser() then
        local available = waitCooldown(left, false)
        addon.Log:info(string.format(addon.L.SCAN_SCHEDULED, clockTime(available)))
    end
    return started
end

function FullScan:command()
    local started, reason, left = self:start(true)
    if started then return end
    if reason == "closed" then addon.Log:info(self.inProgress and addon.L.SCAN_START or addon.L.SCAN_CLOSED)
    elseif reason == "cooldown" then
        local available = waitCooldown(left, true)
        addon.Log:info(string.format(addon.L.SCAN_COOLDOWN, clockTime(available), math.ceil(left / 60)))
    elseif reason == "unsupported" then addon.Log:info(addon.L.SCAN_UNSUPPORTED) end
end

addon.Modules:register("fullscan", {
    requires = { "C_AuctionHouse.ReplicateItems" },
    onEnable = function()
        addon.Events:subscribe("fullscan", "REPLICATE_ITEM_LIST_UPDATE", onReplicate)
        addon.Events:subscribe("fullscan", "AUCTION_HOUSE_CLOSED", function()
            local interrupted = FullScan.inProgress
            if interrupted then
                local started = GoldPilotDB and GoldPilotDB.scan and tonumber(GoldPilotDB.scan.t) or now()
                addon.Log:info(string.format(addon.L.SCAN_INTERRUPTED, FullScan:percent(),
                    clockTime(started + COOLDOWN)))
            end
            local hadProgress = FullScan.progress ~= nil
            FullScan.inProgress, FullScan.receiving = false, false
            FullScan.progress = nil
            ticket = ticket + 1
            addon.Timer.cancelAll("fullscan")
            if hadProgress then addon.Events:send("GOLDPILOT_SCAN_PROGRESS", nil) end
            if FullScan.flush then FullScan.flush() end
        end)
    end,
})

return FullScan
