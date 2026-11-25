local _, addon = ...

local Professions = {}
addon.Professions = Professions

local kinds = { [182] = "herb", [186] = "ore" }

local function invoke(path, ...)
    local output
    local function collect(...)
        local count = select("#", ...)
        output = { ok = select(1, ...) == true, n = 0 }
        for index = 2, count do
            output[index - 1] = select(index, ...)
            output.n = index - 1
        end
    end
    collect(addon.Compat.call(path, ...))
    return output
end

function Professions.skills()
    local result = { known = false }
    local professions = invoke("GetProfessions")
    if not professions.ok then return result end
    local complete, numeric = true, false
    for index = 1, professions.n do
        local slot = tonumber(professions[index])
        if slot then
            local info = invoke("GetProfessionInfo", slot)
            if not info.ok then
                complete = false
            else
                local level, line = tonumber(info[3]), tonumber(info[7])
                if line then numeric = true end
                local kind = line and kinds[line]
                if kind then result[kind] = level end
            end
        end
    end
    result.known = complete and numeric
    return result
end
