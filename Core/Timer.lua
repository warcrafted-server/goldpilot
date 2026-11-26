local _, addon = ...

-- C_Timer.After no se puede cancelar: cada aviso comprueba que su manejador siga vivo.
addon.Timer = {}
local Timer = addon.Timer
local handles = setmetatable({}, { __mode = "k" })

local function start(seconds, fn, owner, repeating)
    local handle = { fn = fn, owner = owner, seconds = seconds, repeating = repeating }

    function handle:cancel()
        self.canceled = true
        handles[self] = nil
    end

    function handle:active()
        return not self.canceled
    end

    local function run()
        if handle.canceled then return end
        if not handle.repeating then
            handle.canceled = true
            handles[handle] = nil
        end
        local ok, result = pcall(handle.fn)
        if not ok then
            -- Repetir un temporizador que falla solo repetiría el mismo error cada intervalo.
            addon.Log:error("temporizador: " .. tostring(result))
            handle:cancel()
            return
        end
        if handle.repeating then
            if handle.canceled or result == false then handle:cancel()
            else addon.Compat.call("C_Timer.After", handle.seconds, run) end
        end
    end

    handles[handle] = true
    addon.Compat.call("C_Timer.After", seconds, run)
    return handle
end

function Timer.after(seconds, fn, owner)
    return start(seconds, fn, owner, false)
end

function Timer.every(seconds, fn, owner)
    return start(seconds, fn, owner, true)
end

function Timer.cancelAll(owner)
    if owner == nil then return end
    for handle in pairs(handles) do
        if handle.owner == owner then handle:cancel() end
    end
end
