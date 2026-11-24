local function setup(addon)
    GoldPilotDB, GoldPilotCharDB = {}, {}
    addon.Modules:enableAll()
end

local function start(addon, fields)
    local session = addon.Sessions.add(nil, { char = "Player", mapID = 7, coin = 100000, items = {} }, 200000)
    for key, value in pairs(fields or {}) do session[key] = value end
    GoldPilotCharDB.session = session
    return session
end

local function withPrices(addon, items)
    local houseKey = addon.AuctionHouse.houseKey()
    GoldPilotDB.prices = {}
    GoldPilotDB.prices[houseKey] = items or { [25] = { last = { t = 199000, min = 1000, p50 = 1000, qty = 10 } } }
end

return {
    ["el panel aparece con sesión, muestra el oro por hora y se oculta con el ajuste"] = function(addon, mock)
        setup(addon)
        mock.items[25] = { name = "Hierba", sell = 10, class = 7, bind = 0 }
        withPrices(addon)
        start(addon, { active = 1800, items = { [25] = 2, [99] = 1 } })
        assert(addon.SessionHUD:refresh())
        local frame = addon.SessionHUD.frame
        assert(frame and not frame.hidden)
        assert(frame.width == 190 and frame.height == 64)
        assert(frame.x == 0 and frame.y == -220)
        local total = 100000 + 2 * 950
        assert(frame.rateText.value == string.format(addon.L.HUD_RATE,
            addon.Theme.money(addon.Sessions.rate(total, 1800))))
        assert(frame.totalText.value == string.format(addon.L.HUD_TOTAL, addon.Theme.money(total), 30))
        assert(frame.noteText.value == string.format(addon.L.HUD_UNPRICED, 1))
        assert(frame.closeButton and frame.scripts.OnEnter and frame.scripts.OnLeave)
        local lines, original = {}, GameTooltip
        GameTooltip = { SetOwner = function() end, Show = function() end, Hide = function() end,
            AddLine = function(_, value) lines[#lines + 1] = value end }
        frame.scripts.OnEnter(frame)
        local text = table.concat(lines, "\n")
        assert(text:find(addon.L.HUD_TITLE, 1, true))
        assert(text:find("Hierba ×2", 1, true) and text:find("×1", 1, true) == nil)
        assert(text:find(addon.L.HUD_COIN, 1, true) and text:find(addon.L.HUD_NOTE, 1, true))
        GameTooltip = original
        assert(GoldPilotDB.settings.hud == nil)
        assert(addon.SessionHUD:setEnabled(false) == false)
        assert(GoldPilotDB.settings.hud == false and frame.hidden)
        addon.SessionHUD:setEnabled(true)
        assert(GoldPilotDB.settings.hud == true and not frame.hidden)
    end,
    ["el tooltip muestra el dinero y no el valor total"] = function(addon, mock)
        setup(addon)
        mock.items[25] = { name = "Hierba", sell = 10, class = 7, bind = 0 }
        withPrices(addon)
        start(addon, { active = 1800, items = { [25] = 2 } })
        assert(addon.SessionHUD:refresh())
        local frame = addon.SessionHUD.frame
        local lines, original = {}, GameTooltip
        GameTooltip = { SetOwner = function() end, Show = function() end, Hide = function() end,
            AddLine = function(_, value) lines[#lines + 1] = value end }
        frame.scripts.OnEnter(frame)
        GameTooltip = original
        local text = table.concat(lines, "\n")
        local total = 100000 + 2 * 950
        assert(text:find(addon.L.HUD_COIN .. ": " .. addon.Theme.money(100000), 1, true))
        assert(text:find(addon.L.HUD_COIN .. ": " .. addon.Theme.money(total), 1, true) == nil)
    end,
    ["el panel mide, pasa a pausa tras el tiempo inactivo y no cuenta sin precio"] = function(addon, mock)
        setup(addon)
        local session = start(addon)
        addon.SessionHUD:refresh()
        local frame = addon.SessionHUD.frame
        assert(frame.rateText.value == addon.L.HUD_MEASURING)
        assert(frame.totalText.value == string.format(addon.L.HUD_TOTAL, addon.Theme.money(100000), 0))
        assert(frame.noteText.hidden)
        session.active = 1800
        session.last = 199700
        addon.SessionHUD:refresh()
        assert(frame.rateText.value == string.format(addon.L.HUD_RATE,
            addon.Theme.money(addon.Sessions.rate(100000, 1980))))
        assert(frame.totalText.value == string.format(addon.L.HUD_TOTAL_PAUSED,
            addon.Theme.money(100000), addon.L.HUD_PAUSED))
    end,
    ["el panel no se crea ni redibuja en combate y aparece al salir"] = function(addon, mock)
        setup(addon)
        local session = start(addon, { active = 1800 })
        mock.combat = true
        assert(not addon.SessionHUD:refresh())
        addon.Loot.onLoot(session)
        assert(addon.SessionHUD.frame == nil)
        mock.combat = false
        mock.fire("PLAYER_REGEN_ENABLED")
        local frame = addon.SessionHUD.frame
        assert(frame and not frame.hidden)
        mock.combat = true
        addon.SessionHUD:setEnabled(false)
        assert(not frame.hidden)
        mock.combat = false
        mock.fire("PLAYER_REGEN_ENABLED")
        assert(frame.hidden)
    end,
    ["el panel usa un único temporizador de cinco segundos mientras está visible"] = function(addon, mock)
        setup(addon)
        start(addon, { active = 1800 })
        assert(addon.SessionHUD:refresh())
        assert(#mock.timers == 1)
        addon.SessionHUD:refresh()
        addon.SessionHUD:refresh()
        assert(#mock.timers == 1)
        mock.combat = true
        addon.SessionHUD:refresh()
        assert(#mock.timers == 1)
        mock.combat = false
        addon.SessionHUD:setEnabled(false)
        mock.flushTimers()
        assert(#mock.timers == 0)
    end,
    ["al terminar la sesión resume en el registro y siempre refresca el panel"] = function(addon, mock)
        setup(addon)
        mock.items[25] = { name = "Hierba", sell = 10, class = 7, bind = 0 }
        withPrices(addon)
        start(addon, { active = 600, items = { [25] = 1, [99] = 2 } })
        addon.SessionHUD:refresh()
        addon.Loot:finish(200000)
        local text = table.concat(mock.output, "\n")
        local total = 100000 + 950
        assert(text:find(string.format(addon.L.SESSION_SUMMARY, 10, addon.Theme.money(total),
            addon.Theme.money(addon.Sessions.rate(total, 600))), 1, true))
        assert(text:find(string.format(addon.L.SESSION_UNPRICED, 1), 1, true))
        assert(GoldPilotCharDB.session == nil and addon.SessionHUD.frame.hidden)
        local count = #mock.output
        start(addon, { active = 60 })
        addon.Loot:finish(200000)
        assert(#mock.output == count and GoldPilotCharDB.session == nil)
    end,
    ["los comandos session y hud muestran y controlan el panel"] = function(addon, mock)
        setup(addon)
        SlashCmdList.GOLDPILOT("session")
        assert(mock.output[#mock.output]:find(addon.L.SESSION_NONE, 1, true))
        start(addon, { active = 600 })
        SlashCmdList.GOLDPILOT("session")
        assert(mock.output[#mock.output]:find(string.format(addon.L.SESSION_CURRENT, 10,
            addon.Theme.money(100000), addon.Theme.money(600000)), 1, true))
        SlashCmdList.GOLDPILOT("hud")
        assert(GoldPilotDB.settings.hud == false)
        assert(mock.output[#mock.output]:find(addon.L.HUD_OFF, 1, true))
        SlashCmdList.GOLDPILOT("hud")
        assert(GoldPilotDB.settings.hud == true and not addon.SessionHUD.frame.hidden)
        assert(mock.output[#mock.output]:find(addon.L.HUD_ON, 1, true))
        SlashCmdList.GOLDPILOT("sesion fin")
        assert(GoldPilotCharDB.session == nil and #GoldPilotDB.sessions == 1)
        SlashCmdList.GOLDPILOT("session end")
        assert(mock.output[#mock.output]:find(addon.L.SESSION_NONE, 1, true))
        start(addon, { active = 60 })
        SlashCmdList.GOLDPILOT("session end")
        assert(mock.output[#mock.output]:find(addon.L.SESSION_SHORT, 1, true))
    end,
}
