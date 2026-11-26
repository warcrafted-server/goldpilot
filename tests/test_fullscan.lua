local function setup(addon, count, scanTime)
    local ids = {}
    for index = 1, count do ids[index] = 1000 + index end
    C_AuctionHouse = {
        ReplicateItems = function() end,
        GetNumReplicateItems = function() return #ids end,
        GetReplicateItemInfo = function(index)
            return "Item", 1, 1, 1, true, 1, 0, 0, 0, 100, 0, false, "", "o", "o", 0, ids[index + 1], true
        end,
        SendSearchQuery = function() end,
        GetAuctionHouseCut = function() return 0.05 end,
    }
    time = function() return 200000 end
    GoldPilotDB = { settings = { fullScan = true } }
    if scanTime then GoldPilotDB.scan = { t = scanTime } end
    addon.Modules:enableAll()
end

return {
    ["el progreso del escaneo crece por fases y termina en nil"] = function(addon, mock)
        setup(addon, 500)
        local seen, sawBar = {}, false
        addon.FullScan:onProgress(function(progress)
            seen[#seen + 1] = progress and addon.FullScan:percent() or false
            local frame = addon.ScanBar and addon.ScanBar.frame
            if progress and frame and not frame.hidden then
                sawBar = sawBar or string.find(tostring(frame.text.value), "scanning", 1, true) ~= nil
            end
        end)
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(addon.FullScan.inProgress and addon.FullScan:percent() == 0)
        assert(addon.ScanBar.frame.text.value == string.format(addon.L.SCAN_BAR_WAIT, 0, 0))
        mock.fire("REPLICATE_ITEM_LIST_UPDATE")
        for _ = 1, 10 do mock.flushTimers() end
        assert(not addon.FullScan.inProgress and addon.FullScan.progress == nil)
        assert(seen[1] == 0 and seen[#seen] == false)
        local previous, peak = 0, 0
        for index = 1, #seen - 1 do
            local value = seen[index]
            assert(type(value) == "number" and value >= previous and value <= 100)
            previous, peak = value, math.max(peak, value)
        end
        assert(peak == 100 and seen[#seen - 1] == 100 and sawBar)
        assert(addon.ScanBar.frame and addon.ScanBar.frame.hidden)
    end,
    ["la espera estima el porcentaje según el escaneo anterior"] = function(addon, mock)
        setup(addon, 500, 200000 - 15 * 60)
        GoldPilotDB.scan.wait = 20
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(addon.FullScan.inProgress and addon.FullScan.progress.phase == "wait")
        assert(addon.FullScan:percent() == 0)
        time = function() return 200000 + 10 end
        assert(addon.FullScan:percent() == 25)
        addon.ScanBar:update(addon.FullScan.progress)
        assert(addon.ScanBar.frame.text.value == string.format(addon.L.SCAN_BAR_WAIT, 25, 10))
        time = function() return 200000 + 60 * 60 end
        assert(addon.FullScan:percent() == 49)
    end,
    ["la lectura empieza en 50 y el registro termina en 100"] = function(addon, mock)
        setup(addon, 500)
        local values = {}
        addon.FullScan:onProgress(function(progress)
            if progress then values[#values + 1] = { phase = progress.phase, value = addon.FullScan:percent() } end
        end)
        mock.fire("AUCTION_HOUSE_SHOW")
        mock.fire("REPLICATE_ITEM_LIST_UPDATE")
        for _ = 1, 10 do mock.flushTimers() end
        local firstRead, lastRecord, maxWait = nil, nil, 0
        for _, entry in ipairs(values) do
            if entry.phase == "wait" then maxWait = math.max(maxWait, entry.value) end
            if entry.phase == "read" and not firstRead then firstRead = entry.value end
            if entry.phase == "record" then lastRecord = entry.value end
        end
        assert(maxWait <= 49)
        assert(firstRead == 50)
        assert(lastRecord == 100)
    end,
    ["cerrar la subasta a mitad avisa de la interrupción"] = function(addon, mock)
        setup(addon, 500)
        local cleared = false
        addon.FullScan:onProgress(function(progress) if progress == nil then cleared = true end end)
        mock.fire("AUCTION_HOUSE_SHOW")
        mock.fire("REPLICATE_ITEM_LIST_UPDATE")
        mock.flushTimers()
        assert(addon.FullScan.inProgress and addon.FullScan:percent() > 0)
        local percent = addon.FullScan:percent()
        local started = GoldPilotDB.scan.t
        mock.fire("AUCTION_HOUSE_CLOSED")
        assert(not addon.FullScan.inProgress and addon.FullScan.progress == nil and cleared)
        local expected = string.format(addon.L.SCAN_INTERRUPTED, percent, os.date("%H:%M", started + 15 * 60))
        assert(string.find(mock.output[#mock.output], expected, 1, true), mock.output[#mock.output])
    end,
    ["abrir la subasta durante el límite avisa y programa el escaneo"] = function(addon, mock)
        setup(addon, 200, 200000 - 6 * 60)
        local replicated = 0
        C_AuctionHouse.ReplicateItems = function() replicated = replicated + 1 end
        mock.fire("AUCTION_HOUSE_SHOW")
        local available = 200000 - 6 * 60 + 15 * 60
        local expected = string.format(addon.L.SCAN_SCHEDULED, os.date("%H:%M", available))
        local announced = false
        for _, line in ipairs(mock.output) do
            if string.find(line, expected, 1, true) then announced = true end
        end
        assert(announced)
        assert(addon.FullScan.progress and addon.FullScan.progress.phase == "cooldown")
        assert(addon.FullScan.progress["until"] == available and addon.FullScan:percent() == 0)
        assert(not addon.FullScan.inProgress)
        assert(addon.ScanBar.frame.text.value == string.format(addon.L.SCAN_BAR_COOLDOWN, 9, 0))
        time = function() return available + 1 end
        mock.flushTimers()
        assert(replicated == 1 and addon.FullScan.inProgress)
    end,
    ["cerrar la subasta cancela el escaneo programado"] = function(addon, mock)
        setup(addon, 200, 200000 - 6 * 60)
        local replicated = 0
        C_AuctionHouse.ReplicateItems = function() replicated = replicated + 1 end
        mock.fire("AUCTION_HOUSE_SHOW")
        assert(addon.FullScan.progress and addon.FullScan.progress.phase == "cooldown")
        local cleared = false
        addon.FullScan:onProgress(function(progress) if progress == nil then cleared = true end end)
        cleared = false
        mock.fire("AUCTION_HOUSE_CLOSED")
        assert(addon.FullScan.progress == nil and cleared)
        time = function() return 200000 + 15 * 60 + 1 end
        mock.flushTimers()
        assert(replicated == 0 and not addon.FullScan.inProgress)
    end,
    ["el comando con el límite activo dice la hora y los minutos"] = function(addon, mock)
        setup(addon, 0, 200000 - 60)
        mock.fire("AUCTION_HOUSE_SHOW")
        addon.FullScan:command()
        local expected = string.format(addon.L.SCAN_COOLDOWN, os.date("%H:%M", 200000 - 60 + 15 * 60), 14)
        assert(string.find(mock.output[#mock.output], expected, 1, true), mock.output[#mock.output])
    end,
}
