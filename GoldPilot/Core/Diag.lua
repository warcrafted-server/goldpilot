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
    local report = { caps = {} }
    local ok, version, build = addon.Compat.call("GetBuildInfo")
    if ok then report.build = tostring(version or "") .. (build and (" (" .. tostring(build) .. ")") or "") end
    local localeOK, locale = addon.Compat.call("GetLocale")
    if localeOK then report.locale = locale end
    report.version = addon.version
    report.fecha = now()

    local present, absent = 0, {}
    for _, path in ipairs(capabilities) do
        local exists = addon.Compat.has(path)
        report.caps[path] = exists
        if exists then present = present + 1 else absent[#absent + 1] = path end
    end
    GoldPilotDB = GoldPilotDB or {}
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
    local invoices = {}
    for i = 1, math.min(tonumber(nOK and n) or 0, 10) do
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
            invoice.campos[field - 1] = entry
        end
        invoices[i] = invoice
    end
    saveSection("mail", { abierto = true, n = nOK and n or nil, facturas = invoices }, addon.L.DIAG_MAIL)
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
    saveSection("loot", { n = nOK and n or nil, ranuras = slots }, addon.L.DIAG_LOOT)
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
                auction.eventos[#auction.eventos + 1] = entry
                auction.fecha = now()
                addon.Log:info(addon.L.DIAG_AUCTION_EVENT .. eventName)
            end)
        end
    end,
})
