local _, addon = ...

addon.Events = {}
local frame = CreateFrame("Frame")
local handlers, pending = {}, {}

local function report(event, err)
    addon.Log:error("evento " .. event .. ": " .. tostring(err))
end

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local entry = list[i]
        if entry.delay then
            if not pending[event] then
                pending[event] = true
                local function dispatch()
                    pending[event] = nil
                    for j = 1, #list do
                        if list[j].delay then
                            local ok, err = pcall(list[j].callback)
                            if not ok then report(event, err) end
                        end
                    end
                end
                if C_Timer and C_Timer.After then C_Timer.After(entry.delay, dispatch) else dispatch() end
            end
        else
            local ok, err = pcall(entry.callback, ...)
            if not ok then report(event, err) end
        end
    end
end)

function addon.Events:subscribe(module, event, callback, delay)
    handlers[event] = handlers[event] or {}
    handlers[event][#handlers[event] + 1] = { module = module, callback = callback, delay = delay }
    frame:RegisterEvent(event)
end

function addon.Events:unsubscribeModule(module)
    for event, list in pairs(handlers) do
        for i = #list, 1, -1 do if list[i].module == module then table.remove(list, i) end end
        if #list == 0 then handlers[event] = nil; frame:UnregisterEvent(event) end
    end
end
