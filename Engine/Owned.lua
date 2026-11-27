local _, addon = ...

local Owned = {}
addon.Owned = Owned

local rank = { undercut = 1, unknown = 2, ok = 3, sold = 4 }

function Owned.review(auctions, lookup, now)
    local rows = {}
    local summary = { undercut = 0, ok = 0, sold = 0, unknown = 0 }
    for _, auction in ipairs(auctions or {}) do
        local min, age, suggestion
        local data = lookup and lookup(auction.key)
        if data then
            min = tonumber(data.min)
            if data.t then age = math.max(0, (tonumber(now) or 0) - (tonumber(data.t) or 0)) end
        end
        local state
        if tonumber(auction.status) == 1 then state = "sold"
        elseif not min then state = "unknown"
        elseif min < (tonumber(auction.unitPrice) or 0) then state = "undercut"
        else state = "ok" end
        if state == "undercut" then
            suggestion = addon.Sell.suggest({ min = min, ref = data.ref, vendor = data.vendor, quantity = auction.quantity })
        end
        summary[state] = summary[state] + 1
        rows[#rows + 1] = { auction = auction, state = state, min = min, age = age, suggestion = suggestion }
    end
    table.sort(rows, function(a, b)
        if rank[a.state] ~= rank[b.state] then return rank[a.state] < rank[b.state] end
        if a.state == "undercut" and a.auction.unitPrice - a.min ~= b.auction.unitPrice - b.min then
            return a.auction.unitPrice - a.min > b.auction.unitPrice - b.min
        end
        return tostring(a.auction.name or "") < tostring(b.auction.name or "")
    end)
    return rows, summary
end

return Owned
