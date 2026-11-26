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
    "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT", "ITEM_SEARCH_RESULTS_UPDATED",
}

-- Lista cerrada: el objetivo es averiguar qué ofrece este cliente, no suponerlo.
local ahCapabilities = {
    "C_AuctionHouse.PostItem", "C_AuctionHouse.PostCommodity",
    "C_AuctionHouse.CalculateItemDeposit", "C_AuctionHouse.CalculateCommodityDeposit",
    "C_AuctionHouse.GetAvailablePostCount", "C_AuctionHouse.IsSellItemValid",
    "C_AuctionHouse.GetItemCommodityStatus", "C_AuctionHouse.QueryOwnedAuctions",
    "C_AuctionHouse.GetNumOwnedAuctions", "C_AuctionHouse.GetOwnedAuctionInfo",
    "C_AuctionHouse.GetOwnedAuctions", "C_AuctionHouse.CancelAuction",
    "C_AuctionHouse.CanCancelAuction", "C_AuctionHouse.GetCancelCost",
    "C_AuctionHouse.StartCommoditiesPurchase", "C_AuctionHouse.ConfirmCommoditiesPurchase",
    "C_AuctionHouse.CancelCommoditiesPurchase", "C_AuctionHouse.PlaceBid",
    "C_AuctionHouse.GetCommoditySearchResultInfo", "C_AuctionHouse.GetNumCommoditySearchResults",
    "C_AuctionHouse.GetItemSearchResultInfo", "C_AuctionHouse.GetNumItemSearchResults",
    "C_AuctionHouse.GetAuctionHouseCut", "C_AuctionHouse.GetTimeLeftBandInfo",
    "C_AuctionHouse.SearchForItemKeys", "C_AuctionHouse.MakeItemKey",
    "C_AuctionHouse.GetItemKeyInfo", "hooksecurefunc", "C_Item.GetItemInfoInstant",
}

local ahFrames = {
    "AuctionHouseFrame", "CommoditiesSellFrame", "ItemSellFrame", "CommoditiesBuyFrame",
    "ItemBuyFrame", "AuctionsFrame", "BrowseResultsFrame", "SearchBar",
}

local ahSellFrames = { CommoditiesSellFrame = true, ItemSellFrame = true }

local ahFrameMethods = {
    "SetDisplayMode", "GetDisplayMode", "SelectBrowseResult", "SetPostItem", "GetCategoriesList",
}

local ahFieldMethods = {
    "SetAmount", "GetAmount", "SetPrice", "GetPrice", "SetQuantity", "GetQuantity",
    "SetItem", "GetItem", "SetDuration", "GetDuration", "Click", "IsEnabled",
}

local diagEvents = {
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_AUCTION_CREATED",
    "AUCTION_HOUSE_AUCTIONS_EXPIRED", "AUCTION_CANCELED", "OWNED_AUCTIONS_UPDATED",
    "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED",
    "COMMODITY_PRICE_UPDATED", "COMMODITY_PRICE_UNAVAILABLE",
    "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED", "COMMODITY_PURCHASED",
    "ITEM_PURCHASED", "BIDS_UPDATED", "AUCTION_HOUSE_NEW_RESULTS_RECEIVED",
    "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "AUCTION_HOUSE_POST_WARNING", "AUCTION_HOUSE_POST_ERROR", "AUCTION_HOUSE_SHOW_ERROR",
    "AUCTION_HOUSE_DISPLAY_MODE_CHANGED", "AUCTION_MULTISELL_START",
    "AUCTION_MULTISELL_UPDATE", "AUCTION_MULTISELL_FAILURE", "UI_ERROR_MESSAGE",
    "CHAT_MSG_SYSTEM",
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
    if message then addon.Log:info(message) end
end

local function get(object, key)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
end

local function invoke(object, name, ...)
    local fn = get(object, name)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, object, ...)
    if ok then return value end
end

local function existingMethods(object, candidates)
    local names = {}
    for _, name in ipairs(candidates) do
        if type(get(object, name)) == "function" then names[#names + 1] = name end
        if #names >= 60 then break end
    end
    return names
end

local function collectFields(frame)
    local names = {}
    pcall(function()
        for key, value in pairs(frame) do
            if type(key) == "string" and type(value) == "table"
                and type(get(value, "GetObjectType")) == "function" then
                names[#names + 1] = key
            end
        end
    end)
    table.sort(names)
    local fields = {}
    for i = 1, math.min(#names, 60) do
        fields[i] = { nombre = names[i], tipo = invoke(get(frame, names[i]), "GetObjectType") }
    end
    return fields
end

local function collectDetails(frame)
    local names = {}
    pcall(function()
        for key, value in pairs(frame) do
            if type(key) == "string" and type(value) == "table" then names[#names + 1] = key end
        end
    end)
    table.sort(names)
    local details = {}
    for i = 1, math.min(#names, 60) do
        local field = get(frame, names[i])
        details[i] = {
            nombre = names[i],
            tipo = invoke(field, "GetObjectType"),
            metodos = existingMethods(field, ahFieldMethods),
        }
    end
    return details
end

local function frameEntry(frame, deep)
    local entry = { existe = frame ~= nil }
    if frame == nil then return entry end
    entry.tipo = invoke(frame, "GetObjectType")
    entry.ancho = invoke(frame, "GetWidth")
    entry.alto = invoke(frame, "GetHeight")
    entry.visible = invoke(frame, "IsShown")
    entry.campos = collectFields(frame)
    if deep then entry.detalle = collectDetails(frame) end
    return entry
end

local function collectStructure()
    local frame = _G.AuctionHouseFrame
    local structure = {}
    for _, name in ipairs(ahFrames) do
        local target = name == "AuctionHouseFrame" and frame or get(frame, name)
        structure[name] = frameEntry(target, ahSellFrames[name] == true)
    end
    if frame ~= nil then
        structure.AuctionHouseFrame.metodos = existingMethods(frame, ahFrameMethods)
    end
    return structure
end

local function collectCapabilities()
    local caps = {}
    for _, path in ipairs(ahCapabilities) do caps[path] = addon.Compat.has(path) end
    return caps
end

local function auctionOpen()
    if addon.Diag.auctionOpen then return true end
    -- Tras /reload dentro de la subasta no llega AUCTION_HOUSE_SHOW: el marco visible lo resuelve.
    return invoke(_G.AuctionHouseFrame, "IsShown") == true
end

local function shortValue(value)
    local kind = type(value)
    if kind == "string" then return string.sub(value, 1, 80) end
    if kind == "number" or kind == "boolean" or kind == "nil" then return tostring(value) end
    return "<" .. kind .. ">"
end

local function textArguments(...)
    local texts = {}
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if type(value) == "string" and value ~= "" then
            texts[#texts + 1] = string.sub(value, 1, 120)
        end
        if #texts >= 5 then break end
    end
    return texts
end

local function finishAuctionSession()
    local session = addon.Diag.ahSession
    if not session then return end
    if inCombat() then
        -- saveSection no escribe en combate: se reintenta al salir en vez de perder la sesión.
        addon.Timer.after(5, finishAuctionSession, "diag-ah")
        return
    end
    addon.Diag.ahSession = nil
    addon.Events:unsubscribeModule("diag-ah")
    addon.Timer.cancelAll("diag-ah")

    local auctions = {}
    local countOK, count = addon.Compat.call("C_AuctionHouse.GetNumOwnedAuctions")
    if countOK and tonumber(count) then
        for i = 1, math.min(tonumber(count), 10) do
            local values = pack(addon.Compat.call("C_AuctionHouse.GetOwnedAuctionInfo", i))
            if values[1] == true then
                local entry = {}
                for value = 2, values.n do entry[#entry + 1] = shortValue(values[value]) end
                auctions[i] = entry
            end
        end
    end

    saveSection("ah", {
        inicio = session.inicio,
        fin = now(),
        capacidades = session.capacidades,
        estructura = session.estructura,
        eventos = session.eventos,
        noRegistrados = session.noRegistrados,
        subastas = auctions,
        modo = invoke(_G.AuctionHouseFrame, "GetDisplayMode"),
    }, addon.L.DIAG_AH_SAVED)
end

function addon.Diag:toggleAuction()
    if inCombat() then return end
    if self.ahSession then
        finishAuctionSession()
        return
    end
    if not auctionOpen() then
        addon.Log:info(addon.L.DIAG_AH_CLOSED)
        return
    end
    local session = {
        inicio = now(),
        eventos = {},
        noRegistrados = {},
        capacidades = collectCapabilities(),
        estructura = collectStructure(),
    }
    self.ahSession = session
    for _, event in ipairs(diagEvents) do
        local eventName = event
        local ok = pcall(function()
            addon.Events:subscribe("diag-ah", eventName, function(...)
                if addon.Diag.ahSession ~= session then return end
                local entry = session.eventos[eventName]
                if not entry then
                    entry = { n = 0 }
                    session.eventos[eventName] = entry
                end
                entry.n = entry.n + 1
                local current = now()
                entry.primero = entry.primero or current
                entry.ultimo = current
                if (eventName == "UI_ERROR_MESSAGE" or eventName == "AUCTION_HOUSE_SHOW_ERROR" or eventName == "CHAT_MSG_SYSTEM")
                    and entry.n <= 10 then
                    entry.ejemplos = entry.ejemplos or {}
                    entry.ejemplos[#entry.ejemplos + 1] = textArguments(...)
                end
                -- Se termina fuera del reparto del evento: quitar suscriptores mientras se recorre la lista falla.
                if eventName == "AUCTION_HOUSE_CLOSED" then
                    addon.Timer.after(0, finishAuctionSession, "diag-ah")
                end
            end)
        end)
        if not ok then
            -- Subscribe registra el evento en el cliente al final: si no existe, hay que deshacerlo.
            pcall(function() addon.Events:unsubscribe("diag-ah", eventName) end)
            session.noRegistrados[#session.noRegistrados + 1] = eventName
        end
    end
    addon.Timer.after(600, finishAuctionSession, "diag-ah")
    addon.Log:info(addon.L.DIAG_AH_START)
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

local function observeAuction()
    if inCombat() then return end
    addon.Diag.auctionOpen = true
    local cutOK, cut = addon.Compat.call("C_AuctionHouse.GetAuctionHouseCut")
    saveSection("auction", { abierta = true, cut = cutOK and cut or nil, eventos = {} }, addon.L.DIAG_AUCTION)
end

local function observeMail(quiet)
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
    saveSection("mail", { abierto = true, n = nOK and n or nil, facturas = invoices, cabeceras = headers }, quiet ~= true and addon.L.DIAG_MAIL or nil)
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
    -- LOOT_READY se dispara dos veces por cada ventana de botín.
    local before, first = log[#log], entry.objetos[1]
    if before and first and before.objetos[1] and first.guid and before.objetos[1].guid == first.guid
        and before.objetos[1].itemID == first.itemID and (entry.t or 0) - (before.t or 0) <= 2 then return end
    GoldPilotDB.diag.botin = log
    log[#log + 1] = entry
    while #log > 300 do table.remove(log, 1) end
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
        addon.Events:subscribe("diag", "MAIL_INBOX_UPDATE", function() observeMail(true) end, 1)
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
            end)
        end
    end,
})
