local _, addon = ...

-- Escaneo completo de la casa de subastas con C_AuctionHouse.ReplicateItems, como hace Auctionator.
-- El servidor lo limita (Auctionator espera 15 min entre escaneos); si no responde se vuelve a la cola.
-- El evento de resultados puede llegar varias veces: solo se procesa la primera, y el trabajo se reparte
-- en trozos de pocos milisegundos por fotograma para no congelar el juego.
local FullScan = { inProgress = false }
addon.FullScan = FullScan

local COOLDOWN, TIMEOUT, SLICE_MS, SLICE_ITEMS = 15 * 60, 120, 6, 200
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

-- Ejecuta step(i) para i = 1..total repartido en fotogramas; devuelve true al terminar vía done().
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
    local listings, order, seen = {}, {}, {}
    local function read(position)
        local ok, _, _, quantity, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = pcall(getInfo, position - 1)
        quantity, buyout, itemID = tonumber(quantity), tonumber(buyout), tonumber(itemID)
        if ok and itemID and itemID ~= PET_CAGE and quantity and quantity > 0 and buyout and buyout > 0 then
            -- Objetos con sufijos aleatorios conocidos, solo para el diagnóstico de variantes.
            if itemID == 14902 or itemID == 15520 or itemID == 10057 then addon.Diag:sampleReplicate(itemID, position - 1) end
            local entries = listings[itemID]
            if not entries then entries = {}; listings[itemID], order[#order + 1] = entries, itemID end
            entries[#entries + 1] = { price = buyout / quantity, qty = quantity }
        end
    end
    local function record(position)
        local itemID = order[position]
        if addon.AuctionHouse:recordListings(itemID, listings[itemID]) then seen[itemID] = true end
        listings[itemID] = nil
    end
    local function complete()
        addon.AuctionHouse:resolveQueue(seen)
        local items = 0
        for _ in pairs(seen) do items = items + 1 end
        GoldPilotDB.scan = { t = GoldPilotDB.scan and GoldPilotDB.scan.t or now(), items = items, ads = count }
        finish(true, string.format(addon.L.SCAN_DONE, items))
    end
    sliced(count, read, function() sliced(#order, record, complete, mine) end, mine)
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
    -- El plazo solo vale mientras el servidor no ha respondido; después manda el reparto en trozos.
    addon.Compat.call("C_Timer.After", TIMEOUT, function()
        if FullScan.inProgress and not FullScan.receiving and mine == ticket then finish(false, addon.L.SCAN_TIMEOUT) end
    end)
    return true
end

function FullScan:maybeStart()
    return self:start(false)
end

-- Respuesta del comando /gp scan.
function FullScan:command()
    local started, reason, left = self:start(true)
    if started then return end
    if reason == "closed" then addon.Log:info(self.inProgress and addon.L.SCAN_START or addon.L.SCAN_CLOSED)
    elseif reason == "cooldown" then
        addon.Log:info(string.format(addon.L.SCAN_COOLDOWN, math.ceil(left / 60)))
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
