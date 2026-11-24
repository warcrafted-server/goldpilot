local function tooltip()
    local frame = { lines = {} }
    function frame:AddLine(line) self.lines[#self.lines + 1] = line end
    function frame:GetItem() return "Item", "item:25" end
    return frame
end

return {
    ["main crea ventana perezosa con pestañas, Escape y posición por personaje"] = function(addon, mock)
        assert(not addon.Main.frame)
        SlashCmdList.GOLDPILOT("")
        local frame = addon.Main.frame
        assert(frame and frame.width == 760 and frame.height == 520)
        assert(_G.GoldPilotMainFrame == frame)
        assert(#UISpecialFrames == 1 and UISpecialFrames[1] == "GoldPilotMainFrame")
        assert(addon.Main.activeTab == "now")
        addon.Main.tabsBar:select("inventory")
        assert(addon.Main.tabsBar.buttons[4].name == "zones")
        assert(addon.Main.tabsBar.buttons[5].name == "settings")
        addon.Main.tabsBar.buttons[5].scripts.OnClick(addon.Main.tabsBar.buttons[5])
        assert(addon.Main.activeTab == "settings")
        frame.x, frame.y = 120, -45
        frame.scripts.OnDragStop(frame)
        assert(GoldPilotCharDB.window.x == 120 and GoldPilotCharDB.window.y == -45)
        addon.Main:hide()
        addon.Main:show()
        assert(frame.x == 120 and frame.y == -45 and not frame.hidden)
    end,
    ["lista recicla filas y dibuja solo las visibles"] = function(addon)
        addon.Main:show()
        local rows = {}
        for i = 1, 1000 do rows[i] = { text = "Item " .. i } end
        addon.Main.widgets.list:setRows(rows)
        assert(#addon.Main.widgets.list.rows < 40)
        addon.Main.widgets.list.scripts.OnVerticalScroll(addon.Main.widgets.list, 280)
        assert(addon.Main.widgets.list.rows[1].dataIndex == 11)
    end,
    ["plantillas opcionales tienen respaldo y las pestañas admiten extensiones"] = function(addon, mock)
        mock.missingTemplates = {
            BackdropTemplate = true,
            UIPanelScrollFrameTemplate = true,
            UIPanelCloseButton = true,
            UICheckButtonTemplate = true,
        }
        local built
        assert(addon.Main:registerTab("Future", function() end, "Future Label"))
        assert(addon.Main:registerTab("Future", function() built = true end))
        addon.Main:show()
        assert(addon.Main.pages.Future and addon.Main.tabsBar.buttons[6])
        assert(addon.Main.tabsBar.buttons[6].value == "Future Label")
        addon.Main.tabsBar.buttons[6].scripts.OnClick(addon.Main.tabsBar.buttons[6])
        assert(built and addon.Main.activeTab == "Future")
    end,
    ["main no se abre ni crea en combate y avisa"] = function(addon, mock)
        mock.combat = true
        SlashCmdList.GOLDPILOT("")
        assert(not addon.Main.frame and not _G.GoldPilotMainFrame)
        assert(#mock.output == 1 and mock.output[1]:find(addon.L.COMBAT_BLOCKED, 1, true))
    end,
    ["ajustes guardan minimapa y tooltip y tooltip respeta desactivación"] = function(addon, mock)
        addon.Main:show()
        addon.Main.tabsBar.buttons[5].scripts.OnClick(addon.Main.tabsBar.buttons[5])
        local page = addon.Main.pages.settings
        local minimap, tooltipSetting = page.minimapCheckbox, page.tooltipCheckbox
        minimap:SetChecked(false)
        minimap.scripts.OnClick(minimap)
        assert(GoldPilotDB.settings.minimap.hidden)
        tooltipSetting:SetChecked(false)
        tooltipSetting.scripts.OnClick(tooltipSetting)
        assert(GoldPilotDB.settings.tooltip == false)
        local frame = tooltip()
        addon.Tooltip:add(frame, { id = 25 })
        assert(#frame.lines == 0)
    end,
    ["/gpilot help y window tienen acciones separadas"] = function(addon, mock)
        SlashCmdList.GOLDPILOT("help")
        assert(#mock.output == 1 and mock.output[1]:find("window", 1, true))
        SlashCmdList.GOLDPILOT("window")
        assert(addon.Main.frame and not addon.Main.frame.hidden)
    end,
}
