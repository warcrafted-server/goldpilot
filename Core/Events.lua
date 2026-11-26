local _, addon = ...

addon.Events = {}
local frame = CreateFrame("Frame")
local handlers, pending = {}, {}

local function report(event, err)
    addon.Log:error("evento " .. event .. ": " .. tostring(err))
end

-- Los mensajes internos entre módulos comparten tabla, pero no son eventos del juego y nunca llegan al frame.
local function internal(name)
    return type(name) == "string" and string.sub(name, 1, 10) == "GOLDPILOT_"
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
    if not internal(event) then frame:RegisterEvent(event) end
end

function addon.Events:send(message, ...)
    local list = handlers[message]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i].callback, ...)
        if not ok then report(message, err) end
    end
end

local function drop(module, event)
    local list = handlers[event]
    if not list then return end
    for i = #list, 1, -1 do if list[i].module == module then table.remove(list, i) end end
    if #list == 0 then
        handlers[event] = nil
        if not internal(event) then frame:UnregisterEvent(event) end
    end
end

function addon.Events:unsubscribe(module, event)
    drop(module, event)
end

function addon.Events:unsubscribeModule(module)
    for event in pairs(handlers) do drop(module, event) end
end
