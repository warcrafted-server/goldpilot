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
    ["valuation lee precio de vendedor y pila generados"] = function(addon)
        addon.DataItems = { [1] = "25;10;0;2;3", [2] = "0;1;0;2;3" }
        local vendor = addon.Valuation.vendor(1)
        assert(vendor.price == 25 and vendor.class == "GAME")
        assert(addon.Valuation.stack(1) == 10 and addon.Valuation.vendor(2) == nil)
        assert(addon.Valuation.stack(99) == nil)
        local result = addon.Valuation.value({}, "h", 1, 100)
        assert(result.vendor and result.vendor.price == 25)
    end,
    ["valuation ignora fuentes externas que fallan"] = function(addon)
        addon.DataItems[55] = "0;1;0;0;0"
        addon.Valuation.registerSource("broken", function() error("fallo") end)
        addon.Valuation.registerSource("working", function(key) assert(string.match(key, "^55")); return 42, 100 end)
        local value = addon.Valuation.reference({}, "h", "55", 120)
        assert(value and value.price == 42 and value.src == "working" and value.class == "EXT")
        local result = addon.Valuation.value({}, "h", "55:0", 120)
        assert(result.ref and result.ref.price == 42)
        assert(result.vendor == nil and result.why == nil)
    end,
}
