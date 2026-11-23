local mock = { events = {}, output = {}, timers = {}, frames = {} }
function CreateFrame()
    local frame = {}
    mock.frames[#mock.frames + 1] = frame
    function frame:RegisterEvent(event) mock.events[event] = self end
    function frame:UnregisterEvent(event) mock.events[event] = nil end
    function frame:SetScript(script, fn) self.handler = fn; self.scripts = self.scripts or {}; self.scripts[script] = fn end
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:SetPoint(_, _, _, x, y) self.x, self.y = x, y end
    function frame:ClearAllPoints() end
    function frame:SetFrameStrata() end
    function frame:SetMovable() end
    function frame:EnableMouse() end
    function frame:RegisterForDrag() end
    function frame:SetClampedToScreen() end
    function frame:StartMoving() self.moving = true end
    function frame:StopMovingOrSizing() self.moving = false end
    function frame:Hide() self.hidden = true end
    function frame:Show() self.hidden = false end
    function frame:CreateTexture() return { SetAllPoints = function() end, SetTexture = function(_, value) frame.texture = value end } end
    function frame:GetCenter() return self.x or 0, self.y or 0 end
    return frame
end
function print(...) mock.output[#mock.output + 1] = table.concat({ ... }, " ") end
function GetLocale() return "enUS" end
function InCombatLockdown() return mock.combat == true end
Minimap = { GetShape = function() return "ROUND" end, GetCenter = function() return 0, 0 end }
GameTooltip = { SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
SlashCmdList = {}
C_Timer = { After = function(_, fn) mock.timers[#mock.timers + 1] = fn end }
function mock.fire(event, ...)
    if mock.events[event] then mock.events[event].handler(nil, event, ...) end
end
function mock.flushTimers()
    local timers = mock.timers; mock.timers = {}
    for _, fn in ipairs(timers) do fn() end
end
return mock
