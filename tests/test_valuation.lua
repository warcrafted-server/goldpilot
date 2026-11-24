return {
    ["valuation elige clase antes que recencia y recencia a igual rango"] = function(addon)
        local chosen = addon.Valuation.choose({
            { class = "EXT", src = "market", price = "30", t = 1000 },
            { class = "EXT", src = "auctionator", price = 20, t = 1900 },
            { class = "OBS", src = "OBS", price = 10, t = 1100 },
            { class = "OBS", src = "OBS", price = 11, t = 1200 },
        }, 2000)
        assert(chosen.price == 11 and chosen.src == "OBS" and chosen.age == 800 and #chosen.inputs == 4)
        assert(type(chosen.price) == "number")
        chosen = addon.Valuation.choose({
            { class = "EXT", src = "tsm", price = 1, t = 1500 },
            { class = "EXT", src = "auctionator", price = 2, t = 1600 },
        }, 2000, 500)
        assert(chosen.price == 2)
    end,
    ["valuation informa datos viejos y ausencia de datos"] = function(addon)
        local value, why = addon.Valuation.choose({
            { class = "OBS", src = "OBS", price = 10, t = 1 },
            { class = "EXT", src = "market", price = 0, t = 1999 },
            { class = "EXT", src = "market", price = 20 },
        }, 2000, 48)
        assert(value == nil and why.reason == "stale" and why.best.price == 10)
        value, why = addon.Valuation.choose({ { class = "OBS", src = "OBS", price = -1, t = 2 } }, 2000)
        assert(value == nil and why.reason == "none")
    end,
    ["valuation lee precio de vendedor del juego"] = function(addon, mock)
        mock.items = { [1] = { sell = 25, stack = 10, class = 2, bind = 3 }, [2] = { sell = nil, stack = 1, class = 2, bind = 3 } }
        local vendor = addon.Valuation.vendor(1)
        assert(vendor.price == 25 and vendor.class == "GAME")
        assert(addon.Valuation.vendor(2) == nil)
        local result = addon.Valuation.value({}, "h", 1, 100)
        assert(result.vendor and result.vendor.price == 25)
    end,
    ["valuation ignora fuentes externas que fallan"] = function(addon, mock)
        mock.items[55] = { class = 0, bind = 0 }
        addon.Valuation.registerSource("broken", function() error("fallo") end)
        addon.Valuation.registerSource("working", function(key) assert(string.match(key, "^55")); return 42, 100 end)
        local value = addon.Valuation.reference({}, "h", "55", 120)
        assert(value and value.price == 42 and value.src == "working" and value.class == "EXT")
        local result = addon.Valuation.value({}, "h", "55:0", 120)
        assert(result.ref and result.ref.price == 42)
        assert(result.vendor == nil and result.why == nil)
    end,
    ["vendor usa solo el proveedor y descarta precios cero"] = function(addon, mock)
        mock.items = { [77] = { sell = 12, stack = 1, class = 0, bind = 0 } }
        addon.Valuation.registerVendor(function(key) assert(key == "77:9"); return 8 end)
        assert(addon.Valuation.vendor("77:9").price == 8)
        addon.Valuation.registerVendor(function() return 0 end)
        assert(addon.Valuation.vendor(77) == nil)
        mock.items = {}
        assert(addon.Valuation.vendor(78) == nil)
        addon.Valuation.registerVendor(function() return nil end)
        assert(addon.Valuation.vendor(78) == nil)
    end,
    ["item data cachea precio cero y GET_ITEM_INFO_RECEIVED lo refresca"] = function(addon, mock)
        local price, requests = 0, 0
        C_Item = {
            GetItemInfo = function()
                return "name", "item:79", 1, 1, 1, "class", "subclass", 1, "", 123, price
            end,
            RequestLoadItemDataByID = function() requests = requests + 1 end,
        }
        addon.Modules:enableAll()
        assert(addon.Valuation.vendor(79) == nil)
        assert(addon.ItemData.cache[79] == 0 and requests == 0)
        price = 25
        assert(addon.Valuation.vendor(79) == nil)
        mock.fire("GET_ITEM_INFO_RECEIVED", 79, true)
        assert(addon.Valuation.vendor(79).price == 25)
    end,
    ["auctionable filtra vinculacion y refresca la cache al recibir datos"] = function(addon, mock)
        mock.items = { [81] = { bind = 1 }, [82] = { bind = 4 }, [83] = { bind = 2 } }
        assert(addon.ItemData.auctionable(81) == false)
        assert(addon.ItemData.auctionable(82) == false)
        assert(addon.ItemData.auctionable(83) == true)
        assert(addon.ItemData.auctionable(84) == nil)
        mock.items[81] = { bind = 0 }
        assert(addon.ItemData.auctionable(81) == false)
        addon.Modules:enableAll()
        mock.fire("GET_ITEM_INFO_RECEIVED", 81, true)
        assert(addon.ItemData.auctionable(81) == true)
    end,
}
