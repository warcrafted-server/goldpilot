local _, addon = ...

addon.Diag = {}

local capabilities = {
    "C_AuctionHouse", "C_AuctionHouse.SendSearchQuery", "C_AuctionHouse.SendBrowseQuery",
    "C_AuctionHouse.GetAuctionHouseCut", "C_AuctionHouse.ReplicateItems",
    "C_AuctionHouse.GetCommoditySearchResultsQuantity", "C_AuctionHouse.GetOwnedAuctions",
    "GetInboxInvoiceInfo", "GetInboxNumItems", "GetLootSourceInfo", "GetNumLootItems",
    "C_TradeSkillUI", "C_TradeSkillUI.GetAllRecipeIDs", "C_Container",
    "C_Container.GetContainerNumSlots", "C_Container.GetContainerItemInfo", "C_Item",
    "C_Item.GetItemInfo", "TooltipDataProcessor", "C_AddOns.GetAddOnMetadata",
    "Auctionator.API.v1", "TSM_API", "C_Timer.After",
}

local auctionEvents = {
    "COMMODITY_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
    "ITEM_SEARCH_RESULTS_UPDATED",
}

local function now()
    local ok, value = addon.Compat.call("time")
    if ok then return value end
end

local function inCombat()
    local ok, value = addon.Compat.call("InCombatLockdown")
    return ok and value == true
end

local function pack(...)
    return { n = select("#", ...), ... }
end

local function saveSection(name, value, message)
    if inCombat() then return end
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.diag = GoldPilotDB.diag or { caps = {} }
    value.fecha = now()
    GoldPilotDB.diag[name] = value
    addon.Log:info(message)
end

function addon.Diag:run()
    if inCombat() then return end
    GoldPilotDB = GoldPilotDB or {}
    local report = {}
    for key, value in pairs(GoldPilotDB.diag or {}) do report[key] = value end
    report.caps = {}
    local ok, version, build = addon.Compat.call("GetBuildInfo")
    if ok then report.build = tostring(version or "") .. (build and (" (" .. tostring(build) .. ")") or "") end
    local localeOK, locale = addon.Compat.call("GetLocale")
    if localeOK then report.locale = locale end
    report.version = addon.version
    report.fecha = now()
    report.bags = {}
    for _, bag in ipairs({ -3, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }) do
        local slotsOK, slots = addon.Compat.call("C_Container.GetContainerNumSlots", bag)
        report.bags[bag] = slotsOK and tonumber(slots) or 0
    end

    local present, absent = 0, {}
    for _, path in ipairs(capabilities) do
        local exists = addon.Compat.has(path)
        report.caps[path] = exists
        if exists then present = present + 1 else absent[#absent + 1] = path end
    end
    GoldPilotDB.diag = report
    addon.Log:info(string.format(addon.L.DIAG_SUMMARY, present, #capabilities - present))
    if #absent > 0 then addon.Log:info(addon.L.DIAG_MISSING .. table.concat(absent, ", ")) end
end

function addon.Diag:searchAuction(itemID)
    if inCombat() or not self.auctionOpen or not itemID then return end
    local itemKey = itemID
    local keyOK, key = addon.Compat.call("C_AuctionHouse.MakeItemKey", itemID)
    if keyOK then itemKey = key end
    local ok = addon.Compat.call("C_AuctionHouse.SendSearchQuery", itemKey, {}, false)
    if ok then
        GoldPilotDB = GoldPilotDB or {}
        GoldPilotDB.diag = GoldPilotDB.diag or { caps = {} }
        GoldPilotDB.diag.auction = GoldPilotDB.diag.auction or { abierta = true, eventos = {} }
        GoldPilotDB.diag.auction.itemID = itemID
    end
end

local function observeAuction()
    if inCombat() then return end
    addon.Diag.auctionOpen = true
    local cutOK, cut = addon.Compat.call("C_AuctionHouse.GetAuctionHouseCut")
    saveSection("auction", { abierta = true, cut = cutOK and cut or nil, eventos = {} }, addon.L.DIAG_AUCTION)
end

local function observeMail()
    if inCombat() then return end
    local nOK, n = addon.Compat.call("GetInboxNumItems")
    local invoices, headers = {}, {}
    for i = 1, math.min(tonumber(nOK and n) or 0, 20) do
        local values = pack(addon.Compat.call("GetInboxInvoiceInfo", i))
        local invoice = {
            tipo = type(values[2]) == "number" and values[2] or nil,
            tipoDato = type(values[2]),
            campos = {},
        }
        for field = 2, values.n do
            local value = values[field]
            local entry = { tipo = type(value) }
            if type(value) == "number" then entry.valor = value end
            if field == 2 and type(value) == "string" then entry.texto = value end
            invoice.campos[field - 1] = entry
        end
        invoices[i] = invoice
        -- Los textos solo se guardan de correos sin respuesta posible (subasta, sistema): nunca de jugadores.
        local head = pack(addon.Compat.call("GetInboxHeaderInfo", i))
        local system = head[1] and not head[13]
        local header = { sender = system and type(head[4]) == "string" and head[4] or nil,
            subject = system and type(head[5]) == "string" and head[5] or nil,
            money = tonumber(head[6]), cod = tonumber(head[7]), daysLeft = tonumber(head[8]),
            hasItem = head[9], wasReturned = head[11], items = {} }
        for attachment = 1, 12 do
            local item = pack(addon.Compat.call("GetInboxItem", i, attachment))
            if item[2] == nil then break end
            header.items[#header.items + 1] = { name = item[2], itemID = tonumber(item[3]), count = tonumber(item[5]) }
        end
        headers[i] = header
    end
    saveSection("mail", { abierto = true, n = nOK and n or nil, facturas = invoices, cabeceras = headers }, addon.L.DIAG_MAIL)
    -- El archivo es de toda la cuenta: una copia por personaje evita que el último buzón borre los anteriores.
    local _, name = addon.Compat.call("UnitName", "player")
    if type(name) == "string" and name ~= "" and GoldPilotDB.diag then
        GoldPilotDB.diag.correos = GoldPilotDB.diag.correos or {}
        GoldPilotDB.diag.correos[name] = { fecha = now(), cabeceras = headers }
    end
end

local function observeLoot()
    if inCombat() then return end
    local nOK, n = addon.Compat.call("GetNumLootItems")
    local slots = {}
    for i = 1, math.min(tonumber(nOK and n) or 0, 5) do
        local sourceOK, guid = addon.Compat.call("GetLootSourceInfo", i)
        if sourceOK and type(guid) == "string" then
            slots[i] = { guid = guid, prefijo = string.match(guid, "^([^-]*)") }
        else
            slots[i] = {}
        end
    end
    local first = not (GoldPilotDB and GoldPilotDB.diag and GoldPilotDB.diag.loot)
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.diag = GoldPilotDB.diag or { caps = {} }
    GoldPilotDB.diag.loot = { n = nOK and n or nil, ranuras = slots, fecha = now() }
    if first then addon.Log:info(addon.L.DIAG_LOOT) end

    -- Registro corto de botines para distinguir nodos, desuello y criaturas.
    local entry = { t = now(), objetos = {} }
    local mapOK, map = addon.Compat.call("C_Map.GetBestMapForUnit", "player")
    entry.mapa = mapOK and tonumber(map) or nil
    for i = 1, math.min(tonumber(nOK and n) or 0, 10) do
        local linkOK, link = addon.Compat.call("GetLootSlotLink", i)
        local source = pack(addon.Compat.call("GetLootSourceInfo", i))
        entry.objetos[#entry.objetos + 1] = {
            itemID = linkOK and type(link) == "string" and tonumber(string.match(link, "item:(%d+)")) or nil,
            guid = source[1] and type(source[2]) == "string" and source[2] or nil,
            cantidad = source[1] and tonumber(source[3]) or nil,
        }
    end
    local log = GoldPilotDB.diag.botin or {}
    GoldPilotDB.diag.botin = log
    log[#log + 1] = entry
    while #log > 300 do table.remove(log, 1) end
end

-- Muestra de variantes de equipo (sufijos aleatorios) en los resultados del resumen de subasta.
local function observeBrowse()
    if inCombat() or not (GoldPilotDB and GoldPilotDB.diag) then return end
    local ok, results = addon.Compat.call("C_AuctionHouse.GetBrowseResults")
    if not ok or type(results) ~= "table" then return end
    local sample = { total = #results, conSufijo = 0, filas = {} }
    for _, result in ipairs(results) do
        local key = result.itemKey
        if type(key) == "table" and (tonumber(key.itemSuffix) or 0) ~= 0 then
            sample.conSufijo = sample.conSufijo + 1
            if #sample.filas < 15 then
                sample.filas[#sample.filas + 1] = { itemID = key.itemID, itemLevel = key.itemLevel,
                    itemSuffix = key.itemSuffix, minPrice = result.minPrice, qty = result.totalQuantity }
            end
        end
    end
    GoldPilotDB.diag.variantes = GoldPilotDB.diag.variantes or {}
    GoldPilotDB.diag.variantes.resumen = sample
end

-- Enlaces del escaneo completo: hasta cuatro por objeto para ver cómo se distingue cada variante.
function addon.Diag:sampleReplicate(itemID, index)
    if not (GoldPilotDB and GoldPilotDB.diag) then return end
    local variants = GoldPilotDB.diag.variantes or {}
    GoldPilotDB.diag.variantes = variants
    variants.enlaces = variants.enlaces or {}
    local links = variants.enlaces[itemID] or {}
    if #links >= 4 then return end
    local ok, link = addon.Compat.call("C_AuctionHouse.GetReplicateItemLink", index)
    if ok and type(link) == "string" then
        for _, seen in ipairs(links) do if seen == link then return end end
        links[#links + 1] = link
        variants.enlaces[itemID] = links
    end
end

local function observeProfessions()
    if inCombat() then return end
    local ok, recipes = addon.Compat.call("C_TradeSkillUI.GetAllRecipeIDs")
    local count = 0
    if ok and type(recipes) == "table" then for _ in pairs(recipes) do count = count + 1 end end
    saveSection("profs", { abierta = true, recetas = ok and count or nil }, addon.L.DIAG_PROFS)
end

addon.Modules:register("diag", {
    onEnable = function()
        addon.Events:subscribe("diag", "AUCTION_HOUSE_SHOW", observeAuction)
        addon.Events:subscribe("diag", "AUCTION_HOUSE_CLOSED", function() addon.Diag.auctionOpen = false end)
        addon.Events:subscribe("diag", "MAIL_SHOW", observeMail)
        addon.Events:subscribe("diag", "MAIL_INBOX_UPDATE", observeMail, 1)
        addon.Events:subscribe("diag", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", observeBrowse, 2)
        addon.Events:subscribe("diag", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", observeBrowse, 2)
        addon.Events:subscribe("diag", "LOOT_READY", observeLoot)
        addon.Events:subscribe("diag", "TRADE_SKILL_SHOW", observeProfessions)
        for _, event in ipairs(auctionEvents) do
            local eventName = event
            addon.Events:subscribe("diag", event, function(...)
                if inCombat() then return end
                GoldPilotDB = GoldPilotDB or {}
                local diag = GoldPilotDB.diag
                if not diag or not diag.auction then return end
                local auction = diag.auction
                auction.eventos = auction.eventos or {}
                local entry = { nombre = eventName }
                local itemID
                for i = 1, select("#", ...) do
                    local value = select(i, ...)
                    if type(value) == "number" then itemID = value; break end
                end
                itemID = itemID or auction.itemID
                if itemID then
                    local qtyOK, quantity = addon.Compat.call("C_AuctionHouse.GetCommoditySearchResultsQuantity", itemID)
                    if qtyOK and type(quantity) == "number" then entry.resultados = quantity end
                end
                auction.fecha = now()
                if #auction.eventos >= 40 then return end
                auction.eventos[#auction.eventos + 1] = entry
                if not auction.logged then auction.logged = {} end
                if not auction.logged[eventName] then
                    auction.logged[eventName] = true
                    addon.Log:info(addon.L.DIAG_AUCTION_EVENT .. eventName)
                end
            end)
        end
    end,
})
