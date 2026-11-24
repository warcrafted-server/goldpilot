local addonName, addon = ...
_G.GoldPilot = addon
addon.name = addonName
addon.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")) or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")) or "desconocida"

local function sessionValues(session)
    local ok, current = addon.Compat.call("time")
    current = ok and tonumber(current) or 0
    local active = addon.Sessions.active(session, current)
    local value = addon.Sessions.value(GoldPilotDB or {}, addon.AuctionHouse.houseKey(),
        { coin = session.coin, items = session.items }, current, addon.ItemData.auctionable)
    return math.floor(active / 60), value.total, addon.Sessions.rate(value.total, active) or 0
end

local function command(input)
    local subcommand = string.match(input or "", "^%s*(%S*)") or ""
    subcommand = string.lower(subcommand)
    if subcommand == "" or subcommand == "window" then
        if addon.Main then addon.Main:toggle() end
        return
    elseif subcommand == "help" then
        addon.Log:info(addon.L.HELP)
        return
    elseif subcommand == "ledger" or subcommand == "libro" then
        local ok, now = addon.Compat.call("time")
        if not ok or not tonumber(now) then now = 0 end
        local summary = addon.Ledger.summary(GoldPilotDB or {}, now - 30 * 86400)
        local balance = summary.balance < 0 and "-" .. addon.Theme.money(math.abs(summary.balance)) or addon.Theme.money(summary.balance)
        addon.Log:info(string.format(addon.L.LEDGER_SUMMARY, summary.sales,
            addon.Theme.money(summary.gross), addon.Theme.money(summary.deposit), addon.Theme.money(summary.cut),
            addon.Theme.money(summary.net), summary.purchases, addon.Theme.money(summary.spent),
            summary.returns, balance))
        return
    end
    if subcommand == "diag" then
        local action, itemID = string.match(input or "", "^%s*%S+%s*(%S*)%s*(%S*)")
        if string.lower(action or "") == "ah" then
            addon.Diag:searchAuction(tonumber(itemID))
        else
            addon.Diag:run()
        end
        return
    end
    if subcommand == "scan" or subcommand == "escanear" then
        if addon.FullScan then addon.FullScan:command() else addon.Log:info(addon.L.SCAN_UNSUPPORTED) end
        return
    end
    if subcommand == "watch" or subcommand == "seguir" then
        local argument = string.match(input or "", "^%s*%S+%s+(.-)%s*$") or ""
        local itemID = tonumber(string.match(argument, "item:(%d+)")) or tonumber(argument)
        if not itemID then
            addon.Log:info(addon.L.WATCH_USAGE)
        elseif itemID <= 0 or itemID ~= math.floor(itemID) then
            addon.Log:info(addon.L.WATCH_USAGE)
        else
            GoldPilotDB = GoldPilotDB or {}
            GoldPilotDB.watch = GoldPilotDB.watch or {}
            local nowWatched = not GoldPilotDB.watch[itemID]
            GoldPilotDB.watch[itemID] = nowWatched or nil
            addon.Log:info(string.format(nowWatched and addon.L.WATCH_ON or addon.L.WATCH_OFF, argument))
            if addon.InventoryUI and addon.InventoryUI.refresh then addon.InventoryUI:refresh() end
        end
    elseif subcommand == "version" then
        addon.Log:info(string.format(addon.L.VERSION, addon.version))
    elseif subcommand == "minimap" then
        if addon.Minimap then addon.Minimap:toggle() end
    elseif subcommand == "bags" or subcommand == "bolsas" then
        local nowOk, now = pcall(time)
        if not nowOk or not tonumber(now) then now = 0 end
        local houseKey = addon.AuctionHouse.houseKey()
        local db = GoldPilotDB or {}
        local cut = db.houses and db.houses[houseKey] and db.houses[houseKey].cut
        local bags, bound = addon.Bags:scan()
        local values = addon.Advisor.bagsValue(bags, function(itemKey)
            local value = addon.Valuation.value(db, houseKey, itemKey, now)
            return {
                vendorPrice = value.vendor and value.vendor.price,
                ahPrice = value.ref and value.ref.price,
                class = value.ref and value.ref.class,
                cut = cut,
            }
        end, bound)
        addon.Log:info(string.format(addon.L.BAGS_SUMMARY, addon.Theme.money(values.vendor),
            addon.Theme.money(values.auction), addon.Theme.money(values.best), values.withoutPrice))
    elseif subcommand == "session" or subcommand == "sesion" then
        local argument = string.lower(string.match(input or "", "^%s*%S+%s+(%S*)") or "")
        if argument == "end" or argument == "fin" then
            local had = GoldPilotCharDB and GoldPilotCharDB.session
            local ok, current = addon.Compat.call("time")
            local saved = addon.Loot:finish(ok and tonumber(current) or 0)
            if not saved then addon.Log:info(had and addon.L.SESSION_SHORT or addon.L.SESSION_NONE) end
        else
            local session = GoldPilotCharDB and GoldPilotCharDB.session
            if session then
                local minutes, total, rate = sessionValues(session)
                addon.Log:info(string.format(addon.L.SESSION_CURRENT, minutes,
                    addon.Theme.money(total), addon.Theme.money(rate)))
            else
                addon.Log:info(addon.L.SESSION_NONE)
            end
        end
    elseif subcommand == "hud" then
        if addon.SessionHUD then
            addon.SessionHUD:toggle()
            addon.Log:info(addon.SessionHUD:enabled() and addon.L.HUD_ON or addon.L.HUD_OFF)
        end
    elseif subcommand == "route" or subcommand == "ruta" then
        if not addon.RouteMap then return end
        local status = addon.RouteMap:status()
        GoldPilotDB = GoldPilotDB or {}
        GoldPilotDB.diag = GoldPilotDB.diag or {}
        local saved = {}
        for key, value in pairs(status) do
            local kind = type(value)
            if kind == "boolean" or kind == "number" or kind == "string" then saved[key] = value end
        end
        if type(status.rect) == "table" then
            saved.rect = table.concat({ tostring(status.rect[1]), tostring(status.rect[2]),
                tostring(status.rect[3]), tostring(status.rect[4]) }, ",")
        end
        GoldPilotDB.diag.route = saved
        addon.Log:info(string.format(addon.L.ROUTE_STATUS,
            tostring(status.available), tostring(status.frame), tostring(status.shown), tostring(status.level),
            tostring(status.mapID), tostring(status.planMap), tostring(status.stops), tostring(status.width),
            tostring(status.height), tostring(status.scale), tostring(status.combat), tostring(saved.rect),
            tostring(addon.RouteMap.lastError)))
    else
        addon.Log:info(addon.L.HELP)
    end
end

SLASH_GOLDPILOT1 = "/goldpilot"
SLASH_GOLDPILOT2 = "/gpilot"
SlashCmdList.GOLDPILOT = command

addon.Events:subscribe("core", "ADDON_LOADED", function(name)
    if name ~= addonName then return end
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotCharDB = GoldPilotCharDB or {}
    if not addon.Migrations:run(GoldPilotDB) then addon.safeMode = true end
    addon.loaded = true
end)
addon.Events:subscribe("core", "PLAYER_LOGIN", function() addon.Modules:enableAll() end)
