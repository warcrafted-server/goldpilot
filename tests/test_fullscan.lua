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
        assert(addon.ScanBar.frame.text.value == string.format(addon.L.SCAN_BAR_WAIT, 0))
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
    ["el comando con el límite activo dice la hora y los minutos"] = function(addon, mock)
        setup(addon, 0, 200000 - 60)
        mock.fire("AUCTION_HOUSE_SHOW")
        addon.FullScan:command()
        local expected = string.format(addon.L.SCAN_COOLDOWN, os.date("%H:%M", 200000 - 60 + 15 * 60), 14)
        assert(string.find(mock.output[#mock.output], expected, 1, true), mock.output[#mock.output])
    end,
}
