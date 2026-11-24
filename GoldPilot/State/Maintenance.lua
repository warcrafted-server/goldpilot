local _, addon = ...

local function schedule(delay)
    addon.Compat.call("C_Timer.After", delay, function()
        if addon.safeMode then return end
        local combatOK, combat = addon.Compat.call("InCombatLockdown")
        if combatOK and combat then schedule(30); return end
        local ok, current = addon.Compat.call("time")
        if ok and tonumber(current) then addon.Prices.prune(GoldPilotDB or {}, tonumber(current)) end
    end)
end

addon.Modules:register("maintenance", {
    onEnable = function()
        -- Los módulos se activan dentro de PLAYER_LOGIN, así que ese evento llegaría tarde; el siguiente se
        -- repite en cada pantalla de carga y basta con el primero.
        local done = false
        addon.Events:subscribe("maintenance", "PLAYER_ENTERING_WORLD", function()
            if done then return end
            done = true
            schedule(10)
        end)
    end,
})
