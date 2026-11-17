-- Wegenetz backen: echte Laufwege zwischen festen Zielen vorab berechnen -> src/ONE_Routes/Data.lua
--
--   git clone https://github.com/cjber/shortest-path-forever.git <spf>   (GPL-3.0-or-later)
--   luajit scripts/bake_routes.lua <spf> [ziel=src/ONE_Routes/Data.lua]
--
-- Rechnet mit dem Wegsucher von Shortest Path Forever (Routing/*.lua) auf dessen Laufkarten (Nav/*.lua,
-- „Derived data, GPL-3.0-or-later“). Ins Addon kommen nur die Ergebnisse: Knoten (feste Ziele) und
-- vereinfachte Wege zwischen Nachbarn. Braucht luajit (SPF entpackt seine Karten über ffi/zlib).
--
-- Knoten: Questgeber/Abgaben (ONE_QuestDB), Startpaket (Questgeber, Händler, Lehrer), Lehrer-Grundliste,
-- Eingänge, Flugmeister/Anleger/Portale (SPF Data). Kanten: je Knoten die K nächsten Nachbarn (Luftlinie) auf
-- derselben Landmasse, danach Brücken zwischen getrennten Teilnetzen.
local spf = assert(arg[1], "Aufruf: luajit scripts/bake_routes.lua <shortest-path-forever-Ordner> [Ziel]")
local dest = arg[2] or "src/ONE_Routes/Data.lua"
-- Nachbarn, Versuche je Knoten, max. Luftlinie einer Kante, Knoten verschmelzen, Vereinfachung, Füllraster (Yards)
local K, SECTORS, TRIES, MAXLEN, MERGE, TOL = 4, 8, 24, 1800, 6, 2.5
local FILL = tonumber(os.getenv("FILL") or "") or 400

local function Commit(dir)
    local h = io.popen("git -C '" .. dir:gsub("'", "") .. "' log -1 --format='%h %ad' --date=short 2>/dev/null")
    local c = h and h:read("*l") or "?"
    if h then h:close() end
    return c
end

-- ===== SPF laden (Wegsucher + Laufkarten) =====
local ns = {}
for _, file in ipairs({"Data/Routes.lua", "Data/Transports.lua", "Data/Taxi.lua", "Data/Portals.lua", "Data/Teleports.lua",
    "Data/Zones.lua", "Routing/PathGrid.lua", "Routing/Path.lua", "Routing/PathJobs.lua", "Routing/Planner.lua"}) do
    assert(loadfile(spf .. "/" .. file))("ShortestPathForever", ns)
end
local CONTINENTS = {0, 1, 2991}
for _, map in ipairs(CONTINENTS) do assert(loadfile(spf .. "/tools/load_nav.lua"))(map, spf) end
local Path = ns.Path
Path.graphKB, Path.cacheKB, Path.clusters = 131072, 196608, 2048
local function Landmass(p) return ns.Planner.Landmass(p, ns.Landmasses) end

-- ===== Kartenrahmen (uiMapID -> Welt-Yards) =====
local RECT = {}
for id, z in pairs(ns.Zones) do RECT[id] = {map = z.map, minX = z.minX, maxX = z.maxX, minY = z.minY, maxY = z.maxY} end
-- Eisenschmiede fehlt in SPF Zones: aus 55 eindeutigen NPCs zurückgerechnet (Restfehler < 1 Yard)
RECT[1455] = RECT[1455] or {map = 0, minX = -5093.7, maxX = -4569.1, minY = -1504.8, maxY = -712.6}
local missing = {}
local function World(mapID, x, y) -- x, y 0..1
    local r = RECT[mapID]
    if not r then missing[mapID] = (missing[mapID] or 0) + 1 return end
    return r.map, r.maxX - y * (r.maxX - r.minX), r.maxY - x * (r.maxY - r.minY)
end

-- ===== Knoten sammeln =====
local nodes = {} -- {c, x, y, kind}
local function Add(kind, c, x, y)
    if c and x and y then nodes[#nodes + 1] = {c = c, x = x, y = y, kind = kind} end
end
local function Sandbox(file, ...)
    local chunk = assert(loadfile(file))
    local env = setmetatable({}, {__index = {pairs = pairs, ipairs = ipairs, type = type, math = math, string = string, table = table}})
    setfenv(chunk, env)
    chunk(...)
    return env
end

-- Questgeber/Abgaben (Promille)
do
    local env = Sandbox("src/ONE_QuestDB/Data.lua")
    local D = env.GuildTripQuestDB
    local used = {}
    for _, q in pairs(D.q) do
        for _, list in ipairs({q[6] or {}, q[7] or {}}) do
            for _, nr in ipairs(list) do used[nr] = true end
        end
    end
    for nr in pairs(used) do
        local n = D.n[nr]
        if n then
            for i = 2, #n - 2, 3 do Add("quest", World(n[i], n[i + 1] / 1000, n[i + 2] / 1000)) end
        end
    end
end
-- Startpaket Navi (Questgeber, Händler)
do
    local nav = {}
    Sandbox("src/ONE_Nav/Pack.lua", "ONE_Nav", nav)
    for _, list in pairs(nav.Pack or {}) do
        for _, e in pairs(list) do
            if type(e) == "table" and e.mapID then Add("pack", World(e.mapID, e.x, e.y)) end
        end
    end
end
-- Lehrer: Startpaket + Grundliste
do
    local crafting = {}
    Sandbox("src/ONE_Crafting/TrainerPack.lua", "ONE_Crafting", crafting)
    for _, e in pairs(crafting.TrainerPack or {}) do Add("trainer", World(e.map, e.x, e.y)) end
    local text = assert(io.open("src/ONE_Crafting/Trainers.lua")):read("*a")
    local const = {}
    for namesText, valsText in text:gmatch("local ([%u, ]+) = ([%d, ]+)\n") do
        local names, vals = {}, {}
        for nme in namesText:gmatch("%u+") do names[#names + 1] = nme end
        for v in valsText:gmatch("%d+") do vals[#vals + 1] = tonumber(v) end
        for i, nme in ipairs(names) do const[nme] = vals[i] end
    end
    for map, x, y in text:gmatch("map = (%w+), x = ([%d.]+), y = ([%d.]+)") do
        Add("trainer", World(tonumber(map) or const[map], tonumber(x), tonumber(y)))
    end
end
-- Eingänge (Startpaket: schluessel = {uiMapID, x, y})
do
    local dungeons = {}
    Sandbox("src/ONE_Dungeons/EntrancePack.lua", "ONE_Dungeons", dungeons)
    for _, e in pairs(dungeons.EntrancePack or {}) do Add("entrance", World(e[1], e[2], e[3])) end
end
-- Flugmeister, Anleger, Portale (SPF, Weltkoordinaten)
for _, n in pairs(ns.TaxiNodes) do Add("taxi", n.map, n.x, n.y) end
for _, d in pairs(ns.Docks) do local p = d.walk or d; Add("dock", p.map, p.x, p.y) end
for _, p in ipairs(ns.Portals) do Add("portal", p.from.map, p.from.x, p.from.y); Add("portal", p.to.map, p.to.x, p.to.y) end

-- ===== verschmelzen + auf das Laufnetz legen =====
local byC = {}
for _, c in ipairs(CONTINENTS) do byC[c] = {} end
local raw = #nodes
for _, n in ipairs(nodes) do
    local list = byC[n.c]
    if list then
        local dup
        for _, m in ipairs(list) do
            if math.abs(m.x - n.x) < MERGE and math.abs(m.y - n.y) < MERGE then dup = m break end
        end
        if not dup then list[#list + 1] = n end
    end
end
-- Füllpunkte: regelmäßiges Raster über alle Gebiete, damit das Netz auch abseits der Ziele erreichbar ist
-- (Punkte im Wasser/Fels finden keinen Weg und fallen am Ende wieder raus)
local fills = 0
do
    local boxes = {}
    for _, r in pairs(RECT) do boxes[#boxes + 1] = r end
    for _, l in ipairs(ns.Landmasses) do if l.map == 2991 then boxes[#boxes + 1] = l end end
    local seen = {}
    for _, b in ipairs(boxes) do
        local list = byC[b.map]
        if list then
            for gx = math.ceil(b.minX / FILL), math.floor(b.maxX / FILL) do
                for gy = math.ceil(b.minY / FILL), math.floor(b.maxY / FILL) do
                    local key = b.map .. ":" .. gx .. ":" .. gy
                    if not seen[key] then
                        seen[key] = true
                        local x, y = gx * FILL, gy * FILL
                        local near = false
                        for _, m in ipairs(list) do
                            if m.kind ~= "fill" and math.abs(m.x - x) < FILL / 2 and math.abs(m.y - y) < FILL / 2 then near = true break end
                        end
                        if not near then list[#list + 1] = {c = b.map, x = x, y = y, kind = "fill"} fills = fills + 1 end
                    end
                end
            end
        end
    end
end
io.stderr:write(("Knoten: %d gesammelt, %d Füllpunkte, unbekannte Karten: "):format(raw, fills))
for id, cnt in pairs(missing) do io.stderr:write(id, "×", cnt, " ") end
io.stderr:write("\n")

-- ===== Douglas-Peucker =====
local function Simplify(pts, tol)
    local keep = {[1] = true, [#pts] = true}
    local function Rec(a, b)
        local ax, ay, bx, by = pts[a].x, pts[a].y, pts[b].x, pts[b].y
        local dx, dy = bx - ax, by - ay
        local len2 = dx * dx + dy * dy
        local best, bi = 0, nil
        for i = a + 1, b - 1 do
            local px, py = pts[i].x - ax, pts[i].y - ay
            local d
            if len2 == 0 then d = math.sqrt(px * px + py * py)
            else
                local t = math.max(0, math.min(1, (px * dx + py * dy) / len2))
                local ex, ey = px - t * dx, py - t * dy
                d = math.sqrt(ex * ex + ey * ey)
            end
            if d > best then best, bi = d, i end
        end
        if bi and best > tol then keep[bi] = true Rec(a, bi) Rec(bi, b) end
    end
    if #pts > 2 then Rec(1, #pts) end
    local out = {}
    for i = 1, #pts do if keep[i] then out[#out + 1] = pts[i] end end
    return out
end
local function Round(v) return math.floor(v + .5) end

-- ===== Kanten backen =====
local out = {}
local function W(s) out[#out + 1] = s end
local stats = {}
local started = os.clock()
for _, c in ipairs(CONTINENTS) do
    local list = byC[c]
    -- Knoten, die nicht auf dem Laufnetz liegen (Wasser, Dach …), fallen raus
    local ok = {}
    for _, n in ipairs(list) do
        n.land = Landmass({map = c, x = n.x, y = n.y}) or 0
        ok[#ok + 1] = n
    end
    list = ok
    for i, n in ipairs(list) do n.id = i end
    local edges, have = {}, {}
    local parent = {}
    local function Find(i) while parent[i] and parent[i] ~= i do i = parent[i] end return i end
    for i = 1, #list do parent[i] = i end
    local fails = 0
    local function Bake(a, b)
        local key = a.id < b.id and (a.id .. " " .. b.id) or (b.id .. " " .. a.id)
        if have[key] ~= nil then return have[key] end
        local pts, cost = Path.FindSync(c, {map = c, x = a.x, y = a.y}, {map = c, x = b.x, y = b.y})
        if type(pts) ~= "table" or #pts < 2 or type(cost) ~= "number" then
            have[key], fails = false, fails + 1
            return false
        end
        local s = Simplify(pts, TOL)
        edges[#edges + 1] = {a = a.id, b = b.id, cost = cost, pts = s}
        have[key] = true
        parent[Find(a.id)] = Find(b.id)
        return true
    end
    -- K nächste Nachbarn (Raster für schnelle Suche)
    local CELL = 400
    local grid = {}
    for _, n in ipairs(list) do
        local k = math.floor(n.x / CELL) .. ":" .. math.floor(n.y / CELL)
        grid[k] = grid[k] or {}
        table.insert(grid[k], n)
    end
    local function Near(n, radius)
        local cand = {}
        local r = math.ceil(radius / CELL)
        local cx, cy = math.floor(n.x / CELL), math.floor(n.y / CELL)
        for gx = cx - r, cx + r do
            for gy = cy - r, cy + r do
                for _, m in ipairs(grid[gx .. ":" .. gy] or {}) do
                    if m ~= n and m.land == n.land then
                        local d = math.sqrt((m.x - n.x) ^ 2 + (m.y - n.y) ^ 2)
                        if d <= radius then cand[#cand + 1] = {m = m, d = d} end
                    end
                end
            end
        end
        table.sort(cand, function(p, q) return p.d < q.d end)
        return cand
    end
    for i, n in ipairs(list) do
        local cand = Near(n, MAXLEN)
        -- K nächste Nachbarn + je Himmelsrichtung (SECTORS Sektoren) der nächste: sonst hängen dichte Städte
        -- nur an sich selbst und Wege laufen über Umwege aus der Stadt hinaus
        local got, tries, sector, sectorTries = 0, 0, {}, {}
        for _, p in ipairs(cand) do
            if tries >= TRIES then break end
            local s = math.floor((math.atan2(p.m.y - n.y, p.m.x - n.x) + math.pi) / (2 * math.pi) * SECTORS) % SECTORS
            if got < K or (not sector[s] and (sectorTries[s] or 0) < 2) then
                local key = n.id < p.m.id and (n.id .. " " .. p.m.id) or (p.m.id .. " " .. n.id)
                if have[key] == nil then tries, sectorTries[s] = tries + 1, (sectorTries[s] or 0) + 1 end
                if Bake(n, p.m) then got, sector[s] = got + 1, true end
                -- Füllpunkt, von dem aus nichts geht (Wasser, Fels): nicht weiter probieren
                if n.kind == "fill" and tries >= 3 and got == 0 then break end
            end
        end
        if i % 200 == 0 then
            io.stderr:write(("  Kontinent %d: %d/%d Knoten, %d Wege, %.0f s\n"):format(c, i, #list, #edges, os.clock() - started))
        end
    end
    -- Brücken: getrennte Teilnetze auf derselben Landmasse verbinden (nächstes Paar, wachsende Reichweite)
    for _ = 1, 40 do
        local comps = {}
        for _, n in ipairs(list) do
            local r = Find(n.id)
            comps[r] = comps[r] or {}
            table.insert(comps[r], n)
        end
        local roots = {}
        for r, members in pairs(comps) do
            -- nur Teilnetze mit echtem Ziel (einzelne Füllpunkte im Wasser/Fels lohnen keine Brücke)
            local real = false
            for _, m in ipairs(members) do if m.kind ~= "fill" then real = true break end end
            if real or #members >= 4 then roots[#roots + 1] = {r = r, members = members} end
        end
        if #roots <= 1 then break end
        table.sort(roots, function(p, q) return #p.members > #q.members end)
        local main = Find(roots[1].r)
        local bridged = 0
        for idx = 2, #roots do
            local members = roots[idx].members
            local best, bestD = nil, math.huge
            for _, n in ipairs(members) do
                for _, p in ipairs(Near(n, 4000)) do
                    if Find(p.m.id) ~= Find(n.id) and p.d < bestD and have[(n.id < p.m.id) and (n.id .. " " .. p.m.id) or (p.m.id .. " " .. n.id)] == nil then
                        best, bestD = {n, p.m}, p.d
                    end
                    if p.d >= bestD then break end
                end
            end
            if best and Bake(best[1], best[2]) then bridged = bridged + 1 end
        end
        if bridged == 0 then break end
    end
    -- Knoten ohne einen einzigen Weg weglassen, Nummern neu vergeben
    local degree = {}
    for _, e in ipairs(edges) do degree[e.a], degree[e.b] = true, true end
    local kept, newId = {}, {}
    for _, n in ipairs(list) do
        if degree[n.id] then kept[#kept + 1] = n newId[n.id] = #kept end
    end
    local dropped = #list - #kept
    for _, e in ipairs(edges) do e.a, e.b = newId[e.a], newId[e.b] end
    local comps = {}
    for _, n in ipairs(kept) do comps[Find(n.id)] = true end
    local nComp, nFill = 0, 0
    for _ in pairs(comps) do nComp = nComp + 1 end
    for _, n in ipairs(kept) do if n.kind == "fill" then nFill = nFill + 1 end end
    list = kept
    stats[#stats + 1] = ("Kontinent %d: %d Knoten (davon %d Füllpunkte, %d ohne Weg entfernt), %d Wege, %d Teilnetze")
        :format(c, #list, nFill, dropped, #edges, nComp)
    io.stderr:write(stats[#stats], "\n")

    -- Ausgabe: Knoten "x y x y …" (ganze Yards), Kanten {a, b, Kosten, "Zwischenpunkte als Abstände"}
    local xs = {}
    for _, n in ipairs(list) do xs[#xs + 1] = Round(n.x) .. " " .. Round(n.y) end
    W(("R[%d] = {\nnodes = \"%s\",\nedges = {\n"):format(c, table.concat(xs, " ")))
    for _, e in ipairs(edges) do
        local d = {}
        local px, py = Round(list[e.a].x), Round(list[e.a].y)
        for j = 2, #e.pts - 1 do
            local x, y = Round(e.pts[j].x), Round(e.pts[j].y)
            d[#d + 1] = (x - px) .. " " .. (y - py)
            px, py = x, y
        end
        W(("{%d,%d,%d,\"%s\"},\n"):format(e.a, e.b, Round(e.cost), table.concat(d, " ")))
    end
    W("}}\n")
end

local f = assert(io.open(dest, "w"))
f:write("-- Guild Trip Wegenetz – ERZEUGT von scripts/bake_routes.lua, NICHT von Hand ändern.\n")
f:write("-- Laufwege berechnet mit Shortest Path Forever von cjber (GPL-3.0-or-later, github.com/cjber/shortest-path-forever),\n")
f:write(("-- Stand %s; Wegsucher und Laufkarten von dort, Ziele aus Guild Trip. Siehe THIRD_PARTY.md.\n"):format(Commit(spf)))
for _, s in ipairs(stats) do f:write("-- ", s, "\n") end
f:write(("-- Knoten: Welt-X Welt-Y (Yards) je Kontinent; Kante: Knoten a, Knoten b, Laufweg (Yards), Zwischenpunkte als\n"))
f:write("-- Abstände zum vorigen Punkt (ab Knoten a). Gilt in beide Richtungen.\n")
f:write(("GuildTripRoutes = {source = \"Shortest Path Forever %s\", R = {}}\nlocal R = GuildTripRoutes.R\n"):format(Commit(spf)))
f:write(table.concat(out))
f:close()
io.stderr:write(("fertig in %.0f s -> %s\n"):format(os.clock() - started, dest))
