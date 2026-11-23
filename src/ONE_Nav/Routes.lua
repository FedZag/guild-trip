-- Guild Trip Navi: Wegenetz (Addon ONE_Routes) – echte Laufwege ohne Zusatz-Addon.
-- Die Wege zwischen festen Zielen (Questgeber, Lehrer, Händler, Flugmeister, Eingänge …) sind vorab
-- berechnet (scripts/bake_routes.lua, mit Shortest Path Forever, GPL). Hier: nächste Knoten zum Spieler und
-- zum Ziel, kürzester Weg im Netz (Dijkstra), daraus eine Linie, der der Pfeil Punkt für Punkt folgt.
local _, nav = ...
local Routes = {
    reach = 320,       -- so weit (Luftlinie) darf der nächste Netzknoten von Spieler/Ziel weg sein
    offroad = 1.5,     -- Luftlinie zum/vom Netz zählt teurer (kein Weg bekannt; wie abseits der Straße im Netz)
    candidates = 6,    -- so viele Knoten am Anfang/Ende ausprobieren
    loop = 20,         -- Weg kommt so nah wieder an eine alte Stelle: Schleife abschneiden
    snaps = 24,        -- so viele Kanten-Stellen am Anfang/Ende (Wege teilen sich Straßen, viele liegen übereinander)
    direct = 120,      -- näher als das: direkt hin, kein Netz
    passRadius = 14,   -- Punkt gilt als erreicht
    offRoute = 70,     -- weiter weg von der Linie: neu planen
    recheck = 3,       -- alle so viele Sekunden vom Spieler aus neu rechnen und kuerzeren Weg uebernehmen
    shortcut = 80,     -- Einstieg in den Weg: höchstens so weit Luftlinie abkürzen …
    joinWithin = 200,  -- … auf die ersten so vielen Yards des Wegs
    -- Lange Abkürzungen querfeldein AUS (22.11.2026, Nutzer: „nutzt kaum Straßen … zu oft über Berge“): gemessen
    -- gegen die SPF-Laufkarten führten sie 7–12 % der Strecke geradeaus durch Berge/Kanten, ohne sie 1,5 %.
    -- Das Netz bevorzugt jetzt Straßen (bake_routes.lua ROADS 1,5), Abkürzen würde das wieder aufheben.
    pull = 0,          -- Umweg querfeldein abkürzen, wenn die Gerade höchstens so lang ist (0 = aus) …
    pullRatio = 1.2,   -- … und der Weg dort mindestens so viel länger wäre
}
nav.Routes = Routes

local sqrt, floor, huge = math.sqrt, math.floor, math.huge

-- Städte: Mauern, Rampen und Felswände, die das Netz zwischen seinen Wegen nicht kennt. Hier wird nie
-- querfeldein abgekürzt (Spielbild 20.11.2026, Tal der Geister: Abkürzung führte über die Felskante).
-- Weltrechtecke der Stadtkarten (SPF Data/Zones.lua, Eisenschmiede aus bake_routes.lua), je Kontinent.
Routes.CITIES = {
    [0] = {
        {-9154, -7996, -15, 1723},        -- Sturmwind 1453
        {-5093.7, -4569.1, -1504.8, -712.6}, -- Eisenschmiede 1455
        {1238, 1878, -86, 873},           -- Unterstadt 1458
    },
    [1] = {
        {1338, 2274, -5083, -3681},       -- Orgrimmar 1454
        {-1546, -850, -527, 517},         -- Donnerfels 1456
        {9533, 10238, 1880, 2938},        -- Darnassus 1457
    },
}
function Routes.InCity(continent, x, y)
    local list = continent and Routes.CITIES[continent]
    if not list then return false end
    for _, r in ipairs(list) do
        if x >= r[1] and x <= r[2] and y >= r[3] and y <= r[4] then return true end
    end
    return false
end

function Routes.Data()
    local d = rawget(_G, "GuildTripRoutes")
    return type(d) == "table" and type(d.R) == "table" and d or nil
end
function Routes:Available() return self.Data() ~= nil end

-- ===== Netz eines Kontinents (erst bei Bedarf entpackt) =====
local CELL = 200
Routes.cache = {}
function Routes:Net(continent)
    local cached = self.cache[continent]
    if cached ~= nil then return cached or nil end
    local d = self.Data()
    local raw = d and d.R[continent]
    if not (raw and type(raw.nodes) == "string" and (type(raw.edges) == "table" or type(raw.edges) == "string")) then
        self.cache[continent] = false
        return nil
    end
    -- Kanten: kompakt als Text (eine Zeile "a b kosten:zwischenpunkte", seit 19.11.2026 – spart Speicher,
    -- entpackt wird nur der Kontinent, auf dem man ist, in schlanke Listen) oder als Tabelle {a, b, kosten, punkte}
    local net = {x = {}, y = {}, adj = {}, ea = {}, eb = {}, ep = {}, grid = {}}
    local i = 0
    for a, b in raw.nodes:gmatch("(%-?%d+) (%-?%d+)") do
        i = i + 1
        local x, y = tonumber(a), tonumber(b)
        net.x[i], net.y[i], net.adj[i] = x, y, {}
        local key = floor(x / CELL) * 100000 + floor(y / CELL)
        local cell = net.grid[key]
        if not cell then cell = {} net.grid[key] = cell end
        cell[#cell + 1] = i
    end
    net.count = i
    local ea, eb, ep, adj = net.ea, net.eb, net.ep, net.adj
    local e = 0
    local function Add(a, b, cost, pts)
        e = e + 1
        ea[e], eb[e], ep[e] = a, b, pts ~= "" and pts or false
        if adj[a] and adj[b] then
            local la, lb = adj[a], adj[b]
            la[#la + 1], la[#la + 2], la[#la + 3] = b, cost, e
            lb[#lb + 1], lb[#lb + 2], lb[#lb + 3] = a, cost, -e
        end
    end
    if type(raw.edges) == "string" then
        -- Zwischenpunkte nicht ausschneiden, nur ihre Stelle im Text merken (spart rund 13.000 kleine Texte)
        local text = raw.edges
        net.text = text
        for a, b, c, p1, p2 in text:gmatch("(%d+) (%d+) (%d+):()[^\n]*()") do
            Add(tonumber(a), tonumber(b), tonumber(c), "")
            if p2 > p1 then ep[e] = p1 * 65536 + (p2 - p1) end
        end
    else
        for _, edge in ipairs(raw.edges) do Add(edge[1], edge[2], edge[3], edge[4] or "") end
    end
    self.cache[continent] = net
    self.IndexLater(net)
    return net
end

-- Die nächsten Knoten (Luftlinie) innerhalb von radius, sortiert
function Routes.Nearest(net, x, y, radius, max)
    local out = {}
    local r = math.ceil(radius / CELL)
    local cx, cy = floor(x / CELL), floor(y / CELL)
    for gx = cx - r, cx + r do
        for gy = cy - r, cy + r do
            local cell = net.grid[gx * 100000 + gy]
            if cell then
                for _, n in ipairs(cell) do
                    local dx, dy = net.x[n] - x, net.y[n] - y
                    local dist = sqrt(dx * dx + dy * dy)
                    if dist <= radius then out[#out + 1] = {n, dist} end
                end
            end
        end
    end
    table.sort(out, function(p, q) return p[2] < q[2] end)
    for k = #out, (max or #out) + 1, -1 do out[k] = nil end
    return out
end

-- ===== kleiner Binärheap =====
local function Push(h, n, cost)
    local i = #h + 1
    h[i] = {n, cost}
    while i > 1 do
        local p = floor(i / 2)
        if h[p][2] <= h[i][2] then break end
        h[p], h[i] = h[i], h[p]
        i = p
    end
end
local function Pop(h)
    local top = h[1]
    if not top then return end
    local last = h[#h]
    h[#h] = nil
    if #h > 0 then
        h[1] = last
        local i, n = 1, #h
        while true do
            local l, r, m = 2 * i, 2 * i + 1, i
            if l <= n and h[l][2] < h[m][2] then m = l end
            if r <= n and h[r][2] < h[m][2] then m = r end
            if m == i then break end
            h[m], h[i] = h[i], h[m]
            i = m
        end
    end
    return top[1], top[2]
end

-- Punkte einer Kante in Laufrichtung (ohne Anfangsknoten, mit Endknoten)
function Routes.EdgePoints(net, e, out)
    local forward = e > 0
    local k = forward and e or -e
    local a, b = net.ea[k], net.eb[k]
    local pts = {}
    local x, y = net.x[a], net.y[a]
    local p = net.ep[k]
    if type(p) == "number" then p = net.text:sub(floor(p / 65536), floor(p / 65536) + p % 65536 - 1) end
    for dx, dy in (p or ""):gmatch("(%-?%d+) (%-?%d+)") do
        x, y = x + tonumber(dx), y + tonumber(dy)
        pts[#pts + 1] = {x, y}
    end
    if forward then
        for _, p in ipairs(pts) do out[#out + 1] = {x = p[1], y = p[2]} end
        out[#out + 1] = {x = net.x[b], y = net.y[b]}
    else
        for k = #pts, 1, -1 do out[#out + 1] = {x = pts[k][1], y = pts[k][2]} end
        out[#out + 1] = {x = net.x[a], y = net.y[a]}
    end
end

-- ===== Einstieg mitten auf einem Weg =====
-- Das Netz verbindet feste Punkte (Geber, Flugmeister …). Wer zwischen zwei Punkten auf dem Weg steht, darf nicht
-- erst zum nächsten Punkt laufen (Spielbild 23.11.2026, Nördliches Brachland: auf der Straße nach Norden, Navi
-- schickte 200 yd nach Westen zu einem Geber und parallel zurück – 874 statt 303 yd). Darum: nächste Stelle auf
-- einer Kante suchen und von dort in beide Richtungen ins Netz.
local ECELL = 200
function Routes.Poly(net, k)
    local pts = {{x = net.x[net.ea[k]], y = net.y[net.ea[k]]}}
    Routes.EdgePoints(net, k, pts)
    return pts
end
-- Zellen-Index der Kanten (einmal je Kontinent, beim ersten Bedarf). Liest die Zwischenpunkte direkt aus dem
-- Text, ohne Tabellen je Punkt (Lua 5.1: 0,32 s → deutlich weniger).
-- limit = höchstens so viele Kanten in diesem Aufruf (Spiel: in Häppchen im Hintergrund, kein Ruckeln);
-- liefert den Index erst, wenn er fertig ist.
function Routes.EdgeIndex(net, limit)
    if net.ecellDone then return net.ecell end
    net.ecell, net.eseen = net.ecell or {}, net.eseen or {}
    local idx, half = net.ecell, ECELL / 2
    local seen, mark = net.eseen, 0
    local nx, ny, ea, eb, ep, text = net.x, net.y, net.ea, net.eb, net.ep, net.text
    local k
    local function Mark(x, y)
        local key = floor(x / ECELL) * 100000 + floor(y / ECELL)
        if seen[key] == mark then return end
        seen[key] = mark
        local cell = idx[key]
        if not cell then cell = {} idx[key] = cell end
        cell[#cell + 1] = k
    end
    local function Line(x1, y1, x2, y2)
        local dx, dy = x2 - x1, y2 - y1
        local len = sqrt(dx * dx + dy * dy)
        for s = 1, floor(len / half) do
            local t = s * half / len
            Mark(x1 + t * dx, y1 + t * dy)
        end
        Mark(x2, y2)
    end
    local from = net.enext or 1
    local to = limit and math.min(#ea, from + limit - 1) or #ea
    for e = from, to do
        k, mark = e, e
        local x, y = nx[ea[e]], ny[ea[e]]
        Mark(x, y)
        local p = ep[e]
        if type(p) == "number" then p = text:sub(floor(p / 65536), floor(p / 65536) + p % 65536 - 1) end
        if p then
            for dx, dy in p:gmatch("(%-?%d+) (%-?%d+)") do
                local x2, y2 = x + tonumber(dx), y + tonumber(dy)
                Line(x, y, x2, y2)
                x, y = x2, y2
            end
        end
        Line(x, y, nx[eb[e]], ny[eb[e]])
    end
    net.enext = to + 1
    if to < #ea then return nil end
    net.ecellDone, net.eseen = true, nil
    return idx
end
-- Im Spiel: Index nach dem Entpacken in Häppchen bauen (je ~1000 Kanten pro Bild)
function Routes.IndexLater(net)
    if net.ecellDone or net.ebuilding then return end
    local timer = rawget(_G, "C_Timer")
    if not (timer and timer.After) then return end
    net.ebuilding = true
    local function Step()
        if not Routes.EdgeIndex(net, 1000) then timer.After(0, Step) else net.ebuilding = nil end
    end
    timer.After(0, Step)
end
-- Nächste Stellen auf Kanten innerhalb radius (je Kante die nächste), sortiert, höchstens max.
-- Eintrag: {k = Kante, d = Abstand, x, y = Stelle, pts = Linie a→b, seg = Abschnitt (pts[seg]→pts[seg+1]), f = Anteil ab a}
function Routes.Snap(net, x, y, radius, max)
    -- im Spiel wird der Index im Hintergrund gebaut; bis dahin nur Einstieg an Knoten (wie früher)
    local idx
    if rawget(_G, "C_Timer") then
        Routes.IndexLater(net)
        idx = net.ecellDone and net.ecell
    else
        idx = Routes.EdgeIndex(net)
    end
    if not idx then return {} end
    local r = math.ceil(radius / ECELL)
    local cx, cy = floor(x / ECELL), floor(y / ECELL)
    local seen, out = {}, {}
    for gx = cx - r, cx + r do
        for gy = cy - r, cy + r do
            local cell = idx[gx * 100000 + gy]
            if cell then
                for _, k in ipairs(cell) do
                    if not seen[k] then
                        seen[k] = true
                        local pts = Routes.Poly(net, k)
                        local cum, bestD, best = 0, huge, nil
                        local lens = {}
                        for j = 1, #pts - 1 do
                            local a, b = pts[j], pts[j + 1]
                            local vx, vy = b.x - a.x, b.y - a.y
                            local len = sqrt(vx * vx + vy * vy)
                            local t = len > 0 and math.max(0, math.min(1, ((x - a.x) * vx + (y - a.y) * vy) / (len * len))) or 0
                            local jx, jy = a.x + t * vx, a.y + t * vy
                            local d = sqrt((jx - x) ^ 2 + (jy - y) ^ 2)
                            if d < bestD then bestD, best = d, {k = k, d = d, x = jx, y = jy, pts = pts, seg = j, at = cum + t * len} end
                            cum = cum + len
                        end
                        if best and bestD <= radius then
                            best.f = cum > 0 and best.at / cum or 0
                            out[#out + 1] = best
                        end
                    end
                end
            end
        end
    end
    table.sort(out, function(p, q) return p.d < q.d end)
    for k = #out, (max or #out) + 1, -1 do out[k] = nil end
    return out
end
-- Kosten einer Kante (aus der Nachbarliste von a)
local function EdgeCost(net, k)
    local adj = net.adj[net.ea[k]]
    for j = 1, #adj, 3 do if adj[j + 2] == k then return adj[j + 1] end end
    return 0
end
-- Punkte von der Stelle s zum Ende der Kante (toB) bzw. zum Anfang, ohne die Stelle selbst
local function FromSnap(s, toB)
    local out = {}
    if toB then
        for j = s.seg + 1, #s.pts do out[#out + 1] = s.pts[j] end
    else
        for j = s.seg, 1, -1 do out[#out + 1] = s.pts[j] end
    end
    return out
end

-- Schleifen abschneiden: Kommt der Weg später wieder an einer Stelle vorbei, an der er schon war (höchstens
-- within Yards entfernt), geht es dort direkt weiter. Kein Weg soll denselben Ort zweimal besuchen.
function Routes.CutLoops(points, within)
    local n = #points
    if n < 4 then return points end
    local out, i = {points[1]}, 1
    while i < n do
        local p, jump, jx, jy = points[i], nil, nil, nil
        for j = n, i + 3, -1 do
            local a, b = points[j - 1], points[j]
            local vx, vy = b.x - a.x, b.y - a.y
            local len2 = vx * vx + vy * vy
            local t = len2 > 0 and math.max(0, math.min(1, ((p.x - a.x) * vx + (p.y - a.y) * vy) / len2)) or 0
            local qx, qy = a.x + t * vx, a.y + t * vy
            if (qx - p.x) ^ 2 + (qy - p.y) ^ 2 <= within * within then jump, jx, jy = j, qx, qy break end
        end
        if jump then
            out[#out + 1] = {x = jx, y = jy}
            out[#out + 1] = points[jump]
            i = jump
        else
            i = i + 1
            out[#out + 1] = points[i]
        end
    end
    return out
end

-- Einstieg abkürzen: Statt erst zum Netzknoten zu laufen und dann umzukehren, direkt (Luftlinie, höchstens
-- maxStraight Yards) auf den Weg treffen – an der Stelle der ersten within Yards, die am meisten spart.
-- points[1] = Spieler. Liefert eine neue Liste.
function Routes.Shortcut(points, maxStraight, within)
    local sx, sy = points[1].x, points[1].y
    local along, best, bestK, bestX, bestY = 0, 0, nil, nil, nil
    for k = 2, #points do
        local a, b = points[k - 1], points[k]
        local vx, vy = b.x - a.x, b.y - a.y
        local len = sqrt(vx * vx + vy * vy)
        if k > 2 and len > 0 then
            -- nächster Punkt auf diesem Abschnitt
            local t = math.max(0, math.min(1, ((sx - a.x) * vx + (sy - a.y) * vy) / (len * len)))
            local jx, jy = a.x + t * vx, a.y + t * vy
            local straight = sqrt((jx - sx) ^ 2 + (jy - sy) ^ 2)
            local saving = along + t * len - straight
            if straight <= maxStraight and saving > best and straight < (along + t * len) * .85 then
                best, bestK, bestX, bestY = saving, k, jx, jy
            end
        end
        along = along + len
        if along > within then break end
    end
    if not bestK then return points end
    local out = {points[1], {x = bestX, y = bestY}}
    for k = bestK, #points do out[#out + 1] = points[k] end
    return out
end

-- Umwege glätten (Nutzer 19.11.2026: "immer erst zur Straße und dann von dort weiter Richtung Ziel"):
-- Läuft der Weg auf einem Stück deutlich länger als die Gerade (Faktor ratio) und ist die Gerade höchstens
-- maxStraight lang, geht es querfeldein. Längere Geraden nicht – dort liegen eher Berge/Wasser dazwischen.
function Routes.Pull(points, maxStraight, ratio, continent)
    if not maxStraight or maxStraight <= 0 or #points < 3 then return points end
    local n = #points
    local cum = {0}
    for k = 2, n do
        cum[k] = cum[k - 1] + sqrt((points[k].x - points[k - 1].x) ^ 2 + (points[k].y - points[k - 1].y) ^ 2)
    end
    local out, i = {points[1]}, 1
    while i < n do
        local jump
        for j = n, i + 2, -1 do
            local along = cum[j] - cum[i]
            if along > maxStraight * ratio * 3 then
                -- zu weit voraus, kann nicht passen (Gerade <= maxStraight, Weg viel länger) – weiter vorn suchen
            else
                local d = sqrt((points[j].x - points[i].x) ^ 2 + (points[j].y - points[i].y) ^ 2)
                if d <= maxStraight and along >= d * ratio + 25
                    and not Routes.InCity(continent, points[i].x, points[i].y)
                    and not Routes.InCity(continent, points[j].x, points[j].y) then jump = j break end
            end
        end
        i = jump or (i + 1)
        out[#out + 1] = points[i]
    end
    return out
end

-- Weg von (fx, fy) nach (tx, ty) auf einem Kontinent. Ergebnis: {points = {{x,y}…}, length = Yards} oder nil
-- (kein Netz, zu nah oder kein Knoten in Reichweite – dann bleibt der Pfeil bei Luftlinie).
function Routes:Find(continent, fx, fy, tx, ty)
    local net = self:Net(continent)
    if not net then return nil, "nodata" end
    local dx, dy = tx - fx, ty - fy
    local straight = sqrt(dx * dx + dy * dy)
    if straight <= self.direct then return nil, "near" end
    local starts = self.Nearest(net, fx, fy, self.reach, self.candidates)
    local goals = self.Nearest(net, tx, ty, self.reach, self.candidates)
    local sSnap = self.Snap(net, fx, fy, self.reach, self.snaps)
    local gSnap = self.Snap(net, tx, ty, self.reach, self.snaps)
    if (#starts == 0 and #sSnap == 0) or (#goals == 0 and #gSnap == 0) then return nil, "far" end
    -- Ziel: Knoten direkt (Luftlinie) oder über eine Stelle auf einer Kante
    local goalCost, goalVia = {}, {}
    for _, g in ipairs(goals) do goalCost[g[1]] = g[2] * self.offroad end
    local function GoalAdd(n, c, how)
        if c < (goalCost[n] or huge) then goalCost[n], goalVia[n] = c, how end
    end
    for _, g in ipairs(gSnap) do
        local c = EdgeCost(net, g.k)
        GoalAdd(net.ea[g.k], g.d * self.offroad + c * g.f, {g, false})
        GoalAdd(net.eb[g.k], g.d * self.offroad + c * (1 - g.f), {g, true})
    end
    local dist, via, heap, startVia = {}, {}, {}, {}
    local function StartAdd(n, c, how)
        if c < (dist[n] or huge) then dist[n], startVia[n] = c, how Push(heap, n, c) end
    end
    for _, s in ipairs(starts) do StartAdd(s[1], s[2] * self.offroad, false) end
    for _, s in ipairs(sSnap) do
        local c = EdgeCost(net, s.k)
        StartAdd(net.ea[s.k], s.d * self.offroad + c * s.f, {s, false})
        StartAdd(net.eb[s.k], s.d * self.offroad + c * (1 - s.f), {s, true})
    end
    -- Umwege (Fluss, Gebirge) sind normal; erst ab dem Vierfachen der Luftlinie lieber geradeaus
    local best, bestNode = straight * 4, nil
    -- Start und Ziel auf derselben Kante: einfach auf ihr entlang
    local same
    for _, s in ipairs(sSnap) do
        for _, g in ipairs(gSnap) do
            if s.k == g.k then
                local c = (s.d + g.d) * self.offroad + EdgeCost(net, s.k) * math.abs(s.f - g.f)
                if c < best then best, same = c, {s, g} end
            end
        end
    end
    while true do
        local n, c = Pop(heap)
        if not n or c >= best then break end
        if c <= (dist[n] or huge) then
            local gc = goalCost[n]
            if gc and c + gc < best then best, bestNode = c + gc, n end
            local adj = net.adj[n]
            for k = 1, #adj, 3 do
                local m, nc = adj[k], c + adj[k + 1]
                if nc < (dist[m] or huge) then
                    dist[m], via[m] = nc, adj[k + 2]
                    Push(heap, m, nc)
                end
            end
        end
    end
    local points
    if bestNode then
        -- Kantenkette zurückverfolgen
        local chain, n = {}, bestNode
        while via[n] do
            local e = via[n]
            chain[#chain + 1] = e
            local k = e > 0 and e or -e
            n = e > 0 and net.ea[k] or net.eb[k]
        end
        points = {{x = fx, y = fy}}
        local sv = startVia[n]
        if sv then
            -- Einstieg auf der Kante: Stelle, dann die Kante entlang bis zum Knoten n
            points[#points + 1] = {x = sv[1].x, y = sv[1].y}
            for _, p in ipairs(FromSnap(sv[1], sv[2])) do points[#points + 1] = p end
        else
            points[#points + 1] = {x = net.x[n], y = net.y[n]}
        end
        for k = #chain, 1, -1 do self.EdgePoints(net, chain[k], points) end
        local gv = goalVia[bestNode]
        if gv then
            -- Ausstieg: vom Knoten die Kante entlang bis zur Stelle nahe am Ziel
            local back = FromSnap(gv[1], gv[2])
            for j = #back, 1, -1 do points[#points + 1] = back[j] end
            points[#points + 1] = {x = gv[1].x, y = gv[1].y}
        end
        points[#points + 1] = {x = tx, y = ty}
    elseif same then
        local s, g = same[1], same[2]
        points = {{x = fx, y = fy}, {x = s.x, y = s.y}}
        local forward = g.f >= s.f
        local lo, hi = forward and s.seg + 1 or g.seg + 1, forward and g.seg or s.seg
        if forward then
            for j = lo, hi do points[#points + 1] = s.pts[j] end
        else
            for j = hi, lo, -1 do points[#points + 1] = s.pts[j] end
        end
        points[#points + 1] = {x = g.x, y = g.y}
        points[#points + 1] = {x = tx, y = ty}
    else
        return nil, "none"
    end
    -- in Städten nicht abkürzen (Mauern/Felskanten)
    if not self.InCity(continent, fx, fy) then points = self.Shortcut(points, self.shortcut, self.joinWithin) end
    -- am Ziel genauso: rückwärts abkürzen
    local rev = {}
    for k = #points, 1, -1 do rev[#rev + 1] = points[k] end
    if not self.InCity(continent, tx, ty) then rev = self.Shortcut(rev, self.shortcut, self.joinWithin) end
    points = {}
    for k = #rev, 1, -1 do points[#points + 1] = rev[k] end
    points = self.CutLoops(points, self.loop)
    points = self.Pull(points, self.pull, self.pullRatio, continent)
    -- doppelte Punkte (Spieler steht auf dem Knoten) entfernen, Länge messen
    local clean, length = {points[1]}, 0
    for k = 2, #points do
        local p, q = clean[#clean], points[k]
        local d = sqrt((q.x - p.x) ^ 2 + (q.y - p.y) ^ 2)
        if d > 1 or k == #points then
            clean[#clean + 1] = q
            length = length + d
        end
    end
    return {points = clean, length = length, continent = continent, tx = tx, ty = ty, index = 2}
end

-- ===== Folgen =====
local function SegmentDistance(px, py, a, b)
    local vx, vy = b.x - a.x, b.y - a.y
    local len2 = vx * vx + vy * vy
    local t = len2 > 0 and math.max(0, math.min(1, ((px - a.x) * vx + (py - a.y) * vy) / len2)) or 0
    local ex, ey = a.x + t * vx - px, a.y + t * vy - py
    return sqrt(ex * ex + ey * ey), t
end

-- Nächster Punkt, auf den der Pfeil zeigen soll, und Restweg. nil, "off" = von der Linie abgekommen.
function Routes:Next(route, px, py, skipRest)
    local pts = route.points
    local i = route.index or 2
    -- auf welchem Abschnitt sind wir? (von hier bis 25 Abschnitte voraus)
    local bestD, bestI = huge, i
    for k = math.max(2, i - 1), math.min(#pts, i + 25) do
        local d = SegmentDistance(px, py, pts[k - 1], pts[k])
        if d < bestD then bestD, bestI = d, k end
    end
    if bestD > self.offRoute then return nil, "off" end
    i = math.max(i, bestI)
    -- erreichte Punkte überspringen
    while i < #pts do
        local p = pts[i]
        if (p.x - px) ^ 2 + (p.y - py) ^ 2 > self.passRadius * self.passRadius then break end
        i = i + 1
    end
    route.index = i
    local target = pts[i]
    if skipRest then return target, nil, i == #pts end
    local rest = sqrt((target.x - px) ^ 2 + (target.y - py) ^ 2)
    for k = i + 1, #pts do
        rest = rest + sqrt((pts[k].x - pts[k - 1].x) ^ 2 + (pts[k].y - pts[k - 1].y) ^ 2)
    end
    return target, rest, i == #pts
end

-- Für den Pfeil: passende Route halten (neu bei neuem Ziel, Abweichen oder bewegtem Ziel), nächsten Punkt liefern.
-- holder = Tabelle, in der die Route gemerkt wird (Arrow); now = Uhrzeit (s).
function Routes:Steer(holder, continent, px, py, tx, ty, now)
    if not self:Available() then return end
    -- Nah genug: direkt hin. Auch eine alte Route verwerfen – sonst fuehrt sie im Zielgebiet noch
    -- ueber den naechsten Weg und zurueck (Nutzer 19.11.2026: "729 m", obwohl 90 m entfernt).
    if (tx - px) ^ 2 + (ty - py) ^ 2 <= self.direct * self.direct then
        holder.route = nil
        return
    end
    local r = holder.route
    local moved = r and (r.continent ~= continent or (r.tx - tx) ^ 2 + (r.ty - ty) ^ 2 > 30 * 30)
    if r and not moved then
        local p, rest, last = self:Next(r, px, py)
        -- immer wieder vom Spielerpfeil aus neu rechnen (Nutzer 23.11.2026, als Geist querfeldein: "erst zum gelben
        -- Punkt und dann weiter") – ist der neue Weg spuerbar kuerzer als der Rest des alten, gilt der neue
        if p and rest and now and now - (holder.routeChecked or now) >= self.recheck then
            holder.routeChecked = now
            local fresh = self:Find(continent, px, py, tx, ty)
            if fresh and fresh.length < rest - math.max(15, rest * .05) then
                holder.route = fresh
                local p2, rest2, last2 = self:Next(fresh, px, py)
                if p2 then return p2, rest2, last2, fresh end
                holder.route = r
            end
        elseif now and not holder.routeChecked then
            holder.routeChecked = now
        end
        if p then return p, rest, last, r end
    end
    -- neu planen (höchstens alle 3 s, damit Abweichen nicht dauernd rechnet)
    if holder.routeTried and now and now - holder.routeTried < 3 and not moved then
        holder.route = nil
        return
    end
    holder.routeTried = now
    holder.route = self:Find(continent, px, py, tx, ty)
    r = holder.route
    if not r then return end
    local p, rest, last = self:Next(r, px, py)
    if p then return p, rest, last, r end
end
