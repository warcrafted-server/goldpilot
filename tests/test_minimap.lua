return {
    ["minimap coloca boton segun angulo y aplica valores por defecto"] = function(addon, mock)
        addon.Modules:enableAll()
        local button = addon.Minimap.button
        assert(button and button.width == 31 and button.height == 31)
        assert(math.abs(button.x - math.cos(math.rad(220)) * 105) < 0.01)
        assert(math.abs(button.y - math.sin(math.rad(220)) * 105) < 0.01)
        assert(GoldPilotDB.settings.minimap.angle == 220 and GoldPilotDB.settings.minimap.hidden == false)
    end,
    ["minimap conserva angulo, permite arrastrar y alterna oculto"] = function(addon, mock)
        GoldPilotDB = { settings = { minimap = { angle = 90, hidden = false } } }
        addon.Modules:enableAll()
        local button = addon.Minimap.button
        assert(math.abs(button.x) < 0.01 and button.y == 105)
        button.x, button.y = 0, 50
        button.scripts.OnDragStop(button)
        assert(math.abs(GoldPilotDB.settings.minimap.angle - 90) < 0.01)
        SlashCmdList.GOLDPILOT("minimap")
        assert(GoldPilotDB.settings.minimap.hidden and button.hidden)
        SlashCmdList.GOLDPILOT("minimap")
        assert(not GoldPilotDB.settings.minimap.hidden and not button.hidden)
    end,
    ["minimap no se crea ni modifica durante combate"] = function(addon, mock)
        mock.combat = true
        addon.Modules:enableAll()
        assert(not addon.Minimap.button)
        SlashCmdList.GOLDPILOT("minimap")
        assert(not GoldPilotDB)
    end,
}
