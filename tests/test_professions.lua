local function clear()
    _G.GetProfessions = nil
    _G.GetProfessionInfo = nil
end

return {
    ["profesiones leen índices con nils intermedios"] = function(addon)
        clear()
        _G.GetProfessions = function() return 1, nil, 4 end
        _G.GetProfessionInfo = function(index)
            if index == 1 then return "Herboristería", "interface/icons/x", 75, 75, 0, 0, 182 end
            if index == 4 then return "Minería", "interface/icons/y", 20, 75, 0, 0, 186 end
            error("índice inesperado")
        end
        local skills = addon.Professions.skills()
        assert(skills.known == true and skills.herb == 75 and skills.ore == 20)
        clear()
    end,
    ["profesiones con varios nils intermedios"] = function(addon)
        clear()
        _G.GetProfessions = function() return nil, nil, 3, nil, 5 end
        _G.GetProfessionInfo = function(index)
            if index == 3 then return "Herboristería", nil, 75, nil, nil, nil, 182 end
            if index == 5 then return "Minería", nil, 20, nil, nil, nil, 186 end
            error("índice inesperado")
        end
        local skills = addon.Professions.skills()
        assert(skills.known == true and skills.herb == 75 and skills.ore == 20)
        clear()
    end,
    ["profesiones sin API no están disponibles"] = function(addon)
        clear()
        local skills = addon.Professions.skills()
        assert(skills.known == false and skills.herb == nil and skills.ore == nil)
    end,
    ["profesiones con un error o sin línea numérica no están disponibles"] = function(addon)
        clear()
        _G.GetProfessions = function() return 1, 2 end
        _G.GetProfessionInfo = function(index)
            if index == 1 then return "Herboristería", nil, 40, 40, 0, 0, 182 end
            error("sin datos")
        end
        local skills = addon.Professions.skills()
        assert(skills.known == false and skills.herb == 40 and skills.ore == nil)
        _G.GetProfessionInfo = function() return "Herboristería", nil, 40 end
        skills = addon.Professions.skills()
        assert(skills.known == false and skills.herb == nil)
        _G.GetProfessions = function() return nil, nil end
        _G.GetProfessionInfo = function() return "Herboristería", nil, 40, 40, 0, 0, 182 end
        skills = addon.Professions.skills()
        assert(skills.known == false and skills.herb == nil)
        _G.GetProfessions = function() error("roto") end
        assert(addon.Professions.skills().known == false)
        clear()
    end,
}
