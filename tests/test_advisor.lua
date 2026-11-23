return {
    ["advisor recomienda subasta solo con ganancia superior al diez por ciento"] = function(addon)
        local result = addon.Advisor.recommend(100, 120, 0.05)
        assert(result.action == "auction" and result.net == 114 and result.margin == 14 and not result.cutAssumed)
        assert(addon.Advisor.recommend(100, 110, 0.05).action == "vendor")
    end,
    ["advisor resuelve vendedor y datos ausentes"] = function(addon)
        assert(addon.Advisor.recommend(75, nil).action == "vendor")
        local none = addon.Advisor.recommend(nil, nil)
        assert(none.action == "none" and none.net == nil)
        local assumed = addon.Advisor.recommend(100, 200)
        assert(assumed.action == "auction" and assumed.net == 190 and assumed.cutAssumed)
    end,
    ["advisor calcula bolsas y cuenta objetos sin precio aparte"] = function(addon)
        local summary = addon.Advisor.bagsValue({ [1] = 2, [2] = 3, [3] = 1 }, function(itemID)
            if itemID == 1 then return { vendorPrice = 10, ahPrice = 20, cut = 0.05 } end
            if itemID == 2 then return { vendorPrice = 5 } end
        end)
        assert(summary.items == 3 and summary.withoutPrice == 1)
        assert(summary.vendor == 35 and summary.auction == 38 and summary.best == 53)
    end,
    ["tema formatea dinero antiguedad e insignias"] = function(addon)
        assert(addon.Theme.money(12345) == "1g 23s 45c")
        assert(addon.Theme.age(7200) == "2 h ago")
        assert(addon.Theme.badge("OBS") == "|cff66ccff[OBS]|r")
        GetCoinTextureString = function(value) return "coin:" .. value end
        assert(addon.Theme.money(42) == "coin:42")
    end,
}
