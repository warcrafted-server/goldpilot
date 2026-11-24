return {
    ["los enlaces identifican objetos y variantes por bonificación"] = function(addon)
        local key = addon.ItemKey.fromLink
        assert(key("item:15520::::::::16:1489::1:1:12726:1:28:5237:::::", true) == "15520:12726")
        assert(key("item:10057::::::::16:1489:::1:12747::::::", true) == "10057:12747")
        assert(key("item:10057::::::::16:1489::1:1:12747:1:28:5239:::::", true) == "10057:12747")
        assert(key("|cffa335ee|Hitem:15520::::::::16:1489::1:1:12726:1:28:5237:::::|h[Item]|h|r", true) == "15520:12726")
        assert(key("item:12345:::::::::::::", true) == 12345)
        assert(key("item:12345::::::::::::2:9:4", false) == 12345)
        assert(key("item:12345::::::::::::2:9:4", true) == "12345:4-9")
        assert(key("not an item", true) == nil and key("item:nope", true) == nil)
        assert(addon.ItemKey.itemID("15520:12726") == 15520 and addon.ItemKey.itemID(10057) == 10057)
        assert(addon.ItemKey.itemID("id:15520") == nil)
    end,
}
