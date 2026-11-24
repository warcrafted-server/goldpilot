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
    ["bagsValue valora ligados al vendedor y libres con recomendación"] = function(addon)
        local auction = addon.Advisor.bagsValue({ [1] = 3 }, function()
            return { vendorPrice = 100, ahPrice = 200, cut = 0.05 }
        end, { [1] = 1 })
        assert(auction.vendor == 300 and auction.auction == 380 and auction.best == 480)
        local vendor = addon.Advisor.bagsValue({ [2] = 3 }, function()
            return { vendorPrice = 50, ahPrice = 30, cut = 0.05 }
        end, { [2] = 1 })
        assert(vendor.vendor == 150 and vendor.auction == 56 and vendor.best == 150)
        local allBound = addon.Advisor.bagsValue({ [1] = 2 }, function()
            return { vendorPrice = 100, ahPrice = 200, cut = 0.05 }
        end, { [1] = 2 })
        assert(allBound.best == 200 and allBound.auction == 0)
    end,
    ["tema formatea dinero antiguedad e insignias"] = function(addon)
        assert(addon.Theme.money(12345) == "1g 23s 45c")
        assert(addon.Theme.age(7200) == "2 h ago")
        assert(addon.Theme.badge("OBS") == "|cff66ccff[OBS]|r")
        GetCoinTextureString = function(value) return "coin:" .. value end
        assert(addon.Theme.money(42) == "coin:42")
    end,
}
