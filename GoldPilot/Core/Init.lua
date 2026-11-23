local addonName, addon = ...
_G.GoldPilot = addon
addon.name = addonName
addon.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")) or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")) or "desconocida"

local function command(input)
    local subcommand = string.match(input or "", "^%s*(%S*)") or ""
    subcommand = string.lower(subcommand)
    if subcommand == "diag" then
        local action, itemID = string.match(input or "", "^%s*%S+%s*(%S*)%s*(%S*)")
        if string.lower(action or "") == "ah" then
            addon.Diag:searchAuction(tonumber(itemID))
        else
            addon.Diag:run()
        end
        return
    end
    if subcommand == "version" then
        addon.Log:info(string.format(addon.L.VERSION, addon.version))
    elseif subcommand == "minimap" then
        if addon.Minimap then addon.Minimap:toggle() end
    elseif subcommand == "bags" or subcommand == "bolsas" then
        local nowOk, now = pcall(time)
        if not nowOk or not tonumber(now) then now = 0 end
        local houseKey = addon.AuctionHouse.houseKey()
        local db = GoldPilotDB or {}
        local cut = db.houses and db.houses[houseKey] and db.houses[houseKey].cut
        local values = addon.Advisor.bagsValue(addon.Bags:scan(), function(itemID)
            local value = addon.Valuation.value(db, houseKey, itemID, now)
            return {
                vendorPrice = value.vendor and value.vendor.price,
                ahPrice = value.ref and value.ref.price,
                class = value.ref and value.ref.class,
                cut = cut,
            }
        end)
        addon.Log:info(string.format(addon.L.BAGS_SUMMARY, addon.Theme.money(values.vendor),
            addon.Theme.money(values.auction), addon.Theme.money(values.best), values.withoutPrice))
    else
        addon.Log:info(addon.L.HELP)
    end
end

SLASH_GOLDPILOT1 = "/goldpilot"
SLASH_GOLDPILOT2 = "/gp"
SlashCmdList.GOLDPILOT = command

addon.Events:subscribe("core", "ADDON_LOADED", function(name)
    if name ~= addonName then return end
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotCharDB = GoldPilotCharDB or {}
    if not addon.Migrations:run(GoldPilotDB) then addon.safeMode = true end
    addon.loaded = true
end)
addon.Events:subscribe("core", "PLAYER_LOGIN", function() addon.Modules:enableAll() end)
