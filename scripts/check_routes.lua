-- Wegenetz prüfen: zufällige Wege im gebackenen Netz (so wie im Spiel) gegen den besten Weg von
-- Shortest Path Forever. Zeigt, wie viel länger unsere Wege sind (1,00 = gleich gut).
--   luajit scripts/check_routes.lua <shortest-path-forever-Ordner> [Anzahl=150] [Saat=1]
local spf = assert(arg[1], "Aufruf: luajit scripts/check_routes.lua <spf> [Anzahl] [Saat]")
local count, seed = tonumber(arg[2] or "") or 150, tonumber(arg[3] or "") or 1
local ns = {}
for _, file in ipairs({"Data/Routes.lua", "Data/Transports.lua", "Data/Taxi.lua", "Data/Portals.lua", "Data/Teleports.lua",
    "Routing/PathGrid.lua", "Routing/Path.lua", "Routing/PathJobs.lua", "Routing/Planner.lua"}) do
    assert(loadfile(spf .. "/" .. file))("ShortestPathForever", ns)
end
for _, map in ipairs({0, 1}) do assert(loadfile(spf .. "/tools/load_nav.lua"))(map, spf) end
local Path = ns.Path
local nav = {}
assert(loadfile("src/ONE_Nav/Routes.lua"))("ONE_Nav", nav)
assert(loadfile("src/ONE_Routes/Data.lua"))()
local R = nav.Routes
math.randomseed(seed)
local ratios, worst, miss = {}, {}, 0
for _, c in ipairs({0, 1}) do
    local net = R:Net(c)
    local done, guard = 0, 0
    while done < count and guard < count * 50 do
        guard = guard + 1
        -- zufällige Punkte in der Nähe zweier Knoten (wie ein Spieler irgendwo draußen)
        local a, b = math.random(net.count), math.random(net.count)
        local fx, fy = net.x[a] + math.random(-150, 150), net.y[a] + math.random(-150, 150)
        local tx, ty = net.x[b] + math.random(-40, 40), net.y[b] + math.random(-40, 40)
        local d = math.sqrt((fx - tx) ^ 2 + (fy - ty) ^ 2)
        local from, to = {map = c, x = fx, y = fy}, {map = c, x = tx, y = ty}
        if d > 600 and d < 5000 and ns.Planner.Landmass(from, ns.Landmasses) == ns.Planner.Landmass(to, ns.Landmasses) then
            local pts, best = Path.FindSync(c, from, to)
            if type(pts) == "table" and type(best) == "number" then
                done = done + 1
                local route = R:Find(c, fx, fy, tx, ty)
                if route then
                    local ratio = route.length / best
                    ratios[#ratios + 1] = ratio
                    worst[#worst + 1] = {ratio, c, fx, fy, tx, ty, best}
                else
                    miss = miss + 1
                end
            end
        end
    end
end
table.sort(ratios)
table.sort(worst, function(p, q) return p[1] > q[1] end)
local function Q(p) return ratios[math.max(1, math.ceil(#ratios * p))] or 0 end
print(("%d Wege, %d ohne Netzweg | Verhältnis Median %.2f, 75 %% %.2f, 90 %% %.2f, 95 %% %.2f, schlechtester %.2f")
    :format(#ratios, miss, Q(.5), Q(.75), Q(.9), Q(.95), Q(1)))
for i = 1, math.min(6, #worst) do
    local w = worst[i]
    print(("  %.2f  Kontinent %d  %d,%d -> %d,%d  (bester Weg %d Yards)"):format(w[1], w[2], w[3], w[4], w[5], w[6], w[7]))
end
