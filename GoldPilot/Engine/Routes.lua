local _, addon = ...

local Routes = {}
addon.Routes = Routes

Routes.defaults = { radius = 0.02, merge = 0.008, maxStops = 24, minStops = 4, stopCost = 0.01,
    maxPoints = 600, aspect = 1.5 }

local kindCache

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok then return nil end
    return value
end

local function sortedKeys(t)
    local keys = {}
    for key in pairs(t or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local an, bn = tonumber(a), tonumber(b)
        if an and bn and an ~= bn then return an < bn end
        if an and not bn then return true end
        if bn and not an then return false end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function aspectOf(opts)
    local aspect = tonumber(opts and opts.aspect) or Routes.defaults.aspect
    if aspect <= 0 then return Routes.defaults.aspect end
    return aspect
end

local function classifyItems(items, classify)
    if type(classify) ~= "function" or type(items) ~= "table" then return nil end
    for _, key in ipairs(sortedKeys(items)) do
        local kind = call(classify, key)
        if kind == "herb" or kind == "ore" then return kind end
    end
    return nil
end

local function objectKind(object, node, seed, kinds, classify)
    local known = kinds[object]
    if known and known.kind then return known.kind end
    if seed and (seed.kind == "herb" or seed.kind == "ore") then return seed.kind end
    if node then return classifyItems(node.items, classify) end
    return nil
end

local function perGather(node, itemID, unit)
    if type(node) == "table" and type(node.items) == "table"
        and (tonumber(node.gathers) or 0) > 0 then
        local total, any = 0, false
        for _, key in ipairs(sortedKeys(node.items)) do
            local amount = tonumber(node.items[key]) or 0
            if amount > 0 then
                any = true
                local price = tonumber(call(unit, key))
                if price then total = total + price * amount end
            end
        end
        if not any then return nil end
        return total / node.gathers
    end
    if not itemID then return nil end
    return tonumber(call(unit, itemID))
end

local function allowed(kind, skill, skills)
    if type(skills) ~= "table" or skills.known ~= true then return true end
    local level = tonumber(skills[kind])
    if skill then return level ~= nil and level >= skill end
    return level ~= nil
end

local function parseSeed(value)
    local points = {}
    if type(value) ~= "string" then return points end
    for pair in string.gmatch(value, "[^;]+") do
        local x, y = string.match(pair, "^%s*([^,]+),([^,]+)%s*$")
        x, y = tonumber(x), tonumber(y)
        if x and y then points[#points + 1] = { x = x / 10000, y = y / 10000 } end
    end
    return points
end

local function merged(own, object, x, y, aspect, merge)
    local list = own[object]
    if not list then return false end
    for _, point in ipairs(list) do
        local dx, dy = point.x - x, (point.y - y) / aspect
        if dx * dx + dy * dy <= merge * merge then return true end
    end
    return false
end

function Routes.kinds()
    if kindCache then return kindCache end
    kindCache = {}
    local seeds = addon.DataNodeSeeds
    if type(seeds) ~= "table" then return kindCache end
    for _, line in ipairs(seeds) do
        if type(line) == "string" then
            local tipo, object, item = string.match(line, "^([^;]*);([^;]*);([^;]*)")
            local kind = tipo == "hierba" and "herb" or tipo == "mineral" and "ore" or nil
            object = tonumber(object)
            if kind and object and object > 0 and object == math.floor(object) then
                local entry = kindCache[object]
                if not entry then
                    entry = { kind = kind }
                    kindCache[object] = entry
                end
                item = tonumber(item)
                if not entry.itemID and item and item > 0 then entry.itemID = item end
            end
        end
    end
    return kindCache
end

function Routes.points(db, mapID, opts)
    opts = opts or {}
    local stats = { own = 0, seed = 0, unpriced = 0, skill = 0 }
    local aspect = aspectOf(opts)
    local merge = Routes.defaults.merge
    local kinds = Routes.kinds()
    local id = tonumber(mapID)
    local nodes = type(db) == "table" and type(db.nodes) == "table" and id
        and (db.nodes[id] or db.nodes[tostring(id)]) or nil
    local seedMap = type(opts.spots) == "table" and id
        and (opts.spots[id] or opts.spots[tostring(id)]) or nil
    local points, own = {}, {}
    local sequence = 0

    local function add(point)
        sequence = sequence + 1
        point._sequence = sequence
        point._rank = point.source == "own" and 1 or 2
        points[#points + 1] = point
        if point.source == "own" then
            own[point.object] = own[point.object] or {}
            table.insert(own[point.object], point)
        end
    end

    for _, key in ipairs(sortedKeys(nodes)) do
        local node = nodes[key]
        local object = tonumber(key) or key
        if type(node) == "table" then
            local seed = seedMap and (seedMap[object] or seedMap[key]) or nil
            local kind = objectKind(object, node, seed, kinds, opts.classify)
            if kind and (not opts.kind or opts.kind == kind) then
                local spots = node.spots or {}
                if allowed(kind, tonumber(seed and seed.skill), opts.skills) then
                    local value = perGather(node, kinds[object] and kinds[object].itemID, opts.unit)
                    if value and value > 0 then
                        for _, spot in ipairs(spots) do
                            local x, y = tonumber(spot.x), tonumber(spot.y)
                            if x and y then
                                local px, py = x / 10000, y / 10000
                                local factor = tonumber(call(opts.factor, px, py)) or 1
                                add({ x = px, y = py, object = object, kind = kind, weight = value * factor,
                                    n = tonumber(spot.n) or 1, source = "own" })
                            end
                        end
                    else
                        stats.unpriced = stats.unpriced + #spots
                    end
                else
                    stats.skill = stats.skill + #spots
                end
            end
        end
    end

    for _, key in ipairs(sortedKeys(seedMap)) do
        local seed = seedMap[key]
        local object = tonumber(key) or key
        if type(seed) == "table" then
            local node = nodes and (nodes[object] or nodes[key]) or nil
            local kind = objectKind(object, node, seed, kinds, opts.classify)
            if kind and (not opts.kind or opts.kind == kind) then
                local list = parseSeed(seed.p)
                if allowed(kind, tonumber(seed.skill), opts.skills) then
                    local value = perGather(node, kinds[object] and kinds[object].itemID, opts.unit)
                    if value and value > 0 then
                        for _, point in ipairs(list) do
                            if not merged(own, object, point.x, point.y, aspect, merge) then
                                local factor = tonumber(call(opts.factor, point.x, point.y)) or 1
                                add({ x = point.x, y = point.y, object = object, kind = kind,
                                    weight = value * factor, n = 1, source = "seed" })
                            end
                        end
                    else
                        stats.unpriced = stats.unpriced + #list
                    end
                else
                    stats.skill = stats.skill + #list
                end
            end
        end
    end

    local function before(a, b)
        if a.weight ~= b.weight then return a.weight > b.weight end
        if a._rank ~= b._rank then return a._rank < b._rank end
        local ao, bo = tostring(a.object), tostring(b.object)
        if ao ~= bo then return ao < bo end
        if a.x ~= b.x then return a.x < b.x end
        if a.y ~= b.y then return a.y < b.y end
        return a._sequence < b._sequence
    end
    table.sort(points, before)
    while #points > Routes.defaults.maxPoints do table.remove(points) end
    for _, point in ipairs(points) do
        if point.source == "own" then stats.own = stats.own + 1 else stats.seed = stats.seed + 1 end
    end
    table.sort(points, function(a, b)
        if a._rank ~= b._rank then return a._rank < b._rank end
        local ao, bo = tostring(a.object), tostring(b.object)
        if ao ~= bo then return ao < bo end
        if a.x ~= b.x then return a.x < b.x end
        if a.y ~= b.y then return a.y < b.y end
        return a._sequence < b._sequence
    end)
    for _, point in ipairs(points) do
        point._rank, point._sequence = nil, nil
    end
    return points, stats
end

function Routes.build(points, opts)
    opts = opts or {}
    if type(points) ~= "table" then return nil end
    local list = {}
    for _, point in ipairs(points) do
        if type(point) == "table" then
            local x, y, weight = tonumber(point.x), tonumber(point.y), tonumber(point.weight)
            if x and y and weight then
                list[#list + 1] = { x = x, y = y, weight = weight, object = point.object }
            end
        end
    end
    if #list < 3 then return nil end

    local aspect = aspectOf(opts)
    for _, point in ipairs(list) do
        point.X, point.Y = point.x, point.y / aspect
    end

    local radius = Routes.defaults.radius
    local cells = {}
    local function cellKey(cx, cy) return cx .. ":" .. cy end
    for index, point in ipairs(list) do
        point.cx, point.cy = math.floor(point.X / radius), math.floor(point.Y / radius)
        local key = cellKey(point.cx, point.cy)
        cells[key] = cells[key] or {}
        table.insert(cells[key], index)
    end
    local neighbor = {}
    for index, point in ipairs(list) do
        local near = {}
        for dx = -1, 1 do
            for dy = -1, 1 do
                for _, other in ipairs(cells[cellKey(point.cx + dx, point.cy + dy)] or {}) do
                    local candidate = list[other]
                    local ddx, ddy = candidate.X - point.X, candidate.Y - point.Y
                    if ddx * ddx + ddy * ddy <= radius * radius then near[#near + 1] = other end
                end
            end
        end
        table.sort(near)
        neighbor[index] = near
    end
    local sums = {}
    for index, point in ipairs(list) do
        local total = 0
        for _, other in ipairs(neighbor[index]) do total = total + list[other].weight end
        sums[index] = total
    end

    local free = {}
    for index = 1, #list do free[index] = true end
    local stops, firstSum = {}, nil
    while #stops < Routes.defaults.maxStops do
        local best, bestSum
        for index = 1, #list do
            if free[index] and (bestSum == nil or sums[index] > bestSum + 1e-12) then
                best, bestSum = index, sums[index]
            end
        end
        if not best then break end
        if firstSum == nil then
            firstSum = bestSum
        elseif bestSum < firstSum * 0.15 then
            break
        end
        local members = {}
        for _, other in ipairs(neighbor[best]) do
            if free[other] then members[#members + 1] = other end
        end
        local total, xsum, ysum, count, objects = 0, 0, 0, 0, {}
        for _, other in ipairs(members) do
            local point = list[other]
            total = total + point.weight
            xsum, ysum = xsum + point.weight * point.X, ysum + point.weight * point.Y
            count = count + 1
            if point.object ~= nil then objects[point.object] = (objects[point.object] or 0) + 1 end
        end
        local cx, cy
        if total > 0 then
            cx, cy = xsum / total, ysum / total
        else
            cx, cy = 0, 0
            for _, other in ipairs(members) do
                cx, cy = cx + list[other].X / count, cy + list[other].Y / count
            end
        end
        stops[#stops + 1] = { x = cx, y = cy * aspect, weight = total, count = count, objects = objects,
            X = cx, Y = cy }
        for _, other in ipairs(members) do free[other] = false end
        for _, other in ipairs(members) do
            for _, target in ipairs(neighbor[other]) do
                if free[target] then sums[target] = sums[target] - list[other].weight end
            end
        end
    end
    if #stops < 3 then return nil end

    local function distance(a, b)
        local dx, dy = a.X - b.X, a.Y - b.Y
        return math.sqrt(dx * dx + dy * dy)
    end
    local function measured(sequence)
        local total = 0
        for index = 1, #sequence do
            total = total + distance(stops[sequence[index]], stops[sequence[index % #sequence + 1]])
        end
        return total
    end

    local start = 1
    for index = 2, #stops do
        if stops[index].weight > stops[start].weight + 1e-12 then start = index end
    end
    local order, used = { start }, { [start] = true }
    local current = start
    for _ = 2, #stops do
        local best, bestDistance
        for index = 1, #stops do
            if not used[index] then
                local value = distance(stops[current], stops[index])
                if not bestDistance or value < bestDistance - 1e-12 then best, bestDistance = index, value end
            end
        end
        current = best
        used[current] = true
        order[#order + 1] = current
    end

    local function delta(sequence, i, j)
        local count = #sequence
        local previous = sequence[(i - 2) % count + 1]
        local first = sequence[i]
        local last = sequence[j]
        local following = sequence[j % count + 1]
        local before = distance(stops[previous], stops[first]) + distance(stops[last], stops[following])
        local after = distance(stops[previous], stops[last]) + distance(stops[first], stops[following])
        return after - before
    end
    local function twoOpt(sequence)
        local count = #sequence
        for _ = 1, 50 do
            local bestDelta, bestI, bestJ = -1e-9, nil, nil
            for i = 1, count do
                for j = i + 1, count do
                    if not (i == 1 and j == count) then
                        local value = delta(sequence, i, j)
                        if value < bestDelta then bestDelta, bestI, bestJ = value, i, j end
                    end
                end
            end
            if not bestI then break end
            while bestI < bestJ do
                sequence[bestI], sequence[bestJ] = sequence[bestJ], sequence[bestI]
                bestI, bestJ = bestI + 1, bestJ - 1
            end
        end
        return sequence
    end
    twoOpt(order)

    local function score(sequence)
        local weight = 0
        for _, index in ipairs(sequence) do weight = weight + stops[index].weight end
        return weight / (measured(sequence) + Routes.defaults.stopCost * #sequence)
    end
    while #order > Routes.defaults.minStops do
        local currentScore = score(order)
        local bestScore, bestPosition
        for position = 1, #order do
            local candidate = {}
            for index = 1, #order do
                if index ~= position then candidate[#candidate + 1] = order[index] end
            end
            local value = score(candidate)
            if not bestScore or value > bestScore + 1e-12 then bestScore, bestPosition = value, position end
        end
        if not bestPosition or bestScore <= currentScore * 1.01 + 1e-12 then break end
        local trimmed = {}
        for index = 1, #order do
            if index ~= bestPosition then trimmed[#trimmed + 1] = order[index] end
        end
        order = trimmed
    end
    twoOpt(order)

    local output, weight, count = {}, 0, 0
    for _, index in ipairs(order) do
        local stop = stops[index]
        output[#output + 1] = { x = stop.x, y = stop.y, weight = stop.weight, count = stop.count,
            objects = stop.objects }
        weight, count = weight + stop.weight, count + stop.count
    end
    return { stops = output, length = measured(order), weight = weight, points = count }
end
