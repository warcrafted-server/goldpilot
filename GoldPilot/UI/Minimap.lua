local _, addon = ...

addon.Minimap = {}

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function position(button, angle)
    local radians = math.rad(angle)
    local x, y = math.cos(radians), math.sin(radians)
    local shape = Minimap.GetShape and Minimap:GetShape() or "ROUND"
    local corners = {
        ["CORNER-TOPLEFT"] = { UL = true },
        ["CORNER-TOPRIGHT"] = { UR = true },
        ["CORNER-BOTTOMLEFT"] = { LL = true },
        ["CORNER-BOTTOMRIGHT"] = { LR = true },
        ["SIDE-LEFT"] = { UL = true, LL = true },
        ["SIDE-RIGHT"] = { UR = true, LR = true },
        ["SIDE-TOP"] = { UL = true, UR = true },
        ["SIDE-BOTTOM"] = { LL = true, LR = true },
        SQUARE = { UL = true, UR = true, LL = true, LR = true },
    }
    local quadrant = (y >= 0 and (x >= 0 and "UR" or "UL")) or (x >= 0 and "LR" or "LL")
    local radius = corners[shape] and corners[shape][quadrant] and 80 or 105
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", radius * x, radius * y)
end

local function showMainAction()
    if addon.Main then addon.Main:toggle() end
end

function addon.Minimap:toggle()
    if inCombat() then return end
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.settings = GoldPilotDB.settings or {}
    GoldPilotDB.settings.minimap = GoldPilotDB.settings.minimap or { angle = 220, hidden = false }
    local settings = GoldPilotDB.settings.minimap
    self:setVisible(settings.hidden)
end

function addon.Minimap:setVisible(visible)
    if inCombat() then return false end
    GoldPilotDB = GoldPilotDB or {}
    GoldPilotDB.settings = GoldPilotDB.settings or {}
    GoldPilotDB.settings.minimap = GoldPilotDB.settings.minimap or {}
    GoldPilotDB.settings.minimap.hidden = not visible
    if self.button then
        if visible then self.button:Show() else self.button:Hide() end
    end
    return true
end

-- En la copia de desarrollo (junction a la raíz del repo) el addon está en una subcarpeta.
local function iconPath()
    local folder = addon.name or "GoldPilot"
    if folder == "GoldPilotDev" then return "Interface/AddOns/GoldPilotDev/GoldPilot/Media/Icon" end
    return "Interface/AddOns/" .. folder .. "/Media/Icon"
end

addon.Modules:register("minimap", {
    onEnable = function()
        if inCombat() or not CreateFrame or not Minimap then return end
        GoldPilotDB = GoldPilotDB or {}
        GoldPilotDB.settings = GoldPilotDB.settings or {}
        GoldPilotDB.settings.minimap = GoldPilotDB.settings.minimap or {}
        local settings = GoldPilotDB.settings.minimap
        if type(settings.angle) ~= "number" then settings.angle = 220 end
        if type(settings.hidden) ~= "boolean" then settings.hidden = false end

        local button = CreateFrame("Button", nil, Minimap)
        addon.Minimap.button = button
        button:SetSize(31, 31)
        button:SetFrameStrata("MEDIUM")
        button:SetMovable(true)
        button:EnableMouse(true)
        button:RegisterForDrag("LeftButton")
        button:SetClampedToScreen(true)
        button:SetScript("OnDragStart", function(self)
            if inCombat() then return end
            self:StartMoving()
        end)
        button:SetScript("OnDragStop", function(self)
            if inCombat() then return end
            self:StopMovingOrSizing()
            local x, y = Minimap:GetCenter()
            local bx, by = self:GetCenter()
            if x and y and bx and by then
                settings.angle = math.deg(math.atan2(by - y, bx - x))
                position(self, settings.angle)
            end
        end)
        button:SetScript("OnClick", function(_, mouseButton)
            if inCombat() then return end
            if mouseButton == "RightButton" then addon.Diag:run() else showMainAction() end
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(addon.L.MINIMAP_TITLE)
            GameTooltip:AddLine(addon.L.MINIMAP_LEFT)
            GameTooltip:AddLine(addon.L.MINIMAP_RIGHT)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(iconPath())
        button.icon = icon
        position(button, settings.angle)
        if settings.hidden then button:Hide() end

        if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
            pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
                text = addon.L.MINIMAP_TITLE,
                icon = iconPath(),
                notCheckable = true,
                func = function(_, _, mouseButton)
                    if mouseButton == "RightButton" then addon.Diag:run() else showMainAction() end
                end,
                registerForAnyClick = true,
                funcOnEnter = function(frame)
                    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
                    GameTooltip:AddLine(addon.L.MINIMAP_TITLE)
                    GameTooltip:AddLine(addon.L.MINIMAP_LEFT)
                    GameTooltip:AddLine(addon.L.MINIMAP_RIGHT)
                    GameTooltip:Show()
                end,
                funcOnLeave = function() GameTooltip:Hide() end,
            })
        end
    end,
})
