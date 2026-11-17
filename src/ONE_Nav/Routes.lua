-- Guild Trip Navi: Wegenetz (Addon ONE_Routes) – echte Laufwege ohne Zusatz-Addon.
-- Die Wege zwischen festen Zielen (Questgeber, Lehrer, Händler, Flugmeister, Eingänge …) sind vorab
-- berechnet (scripts/bake_routes.lua, mit Shortest Path Forever, GPL). Hier: nächste Knoten zum Spieler und
-- zum Ziel, kürzester Weg im Netz (Dijkstra), daraus eine Linie, der der Pfeil Punkt für Punkt folgt.
local _, nav = ...
local Routes = {
    reach = 320,       -- so weit (Luftlinie) darf der nächste Netzknoten von Spieler/Ziel weg sein
    offroad = 1.25,    -- Luftlinie zum/vom Netz zählt etwas teurer (kein Weg bekannt)
    candidates = 6,    -- so viele Knoten am Anfang/Ende ausprobieren
    direct = 120,      -- näher als das: direkt hin, kein Netz
    passRadius = 14,   -- Punkt gilt als erreicht
    offRoute = 70,     -- weiter weg von der Linie: neu planen
    shortcut = 140,    -- Einstieg in den Weg: höchstens so weit Luftlinie abkürzen …
    joinWithin = 400,  -- … auf die ersten so vielen Yards des Wegs
}
nav.Routes = Routes

local sqrt, floor, huge = math.sqrt, math.floor, math.huge

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
    if not (raw and type(raw.nodes) == "string" and type(raw.edges) == "table") then
        self.cache[continent] = false
        return nil
    end
    local net = {x = {}, y = {}, adj = {}, edges = raw.edges, grid = {}}
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
    for e, edge in ipairs(raw.edges) do
        local a, b, cost = edge[1], edge[2], edge[3]
        if net.adj[a] and net.adj[b] then
            local la, lb = net.adj[a], net.adj[b]
            la[#la + 1], la[#la + 2], la[#la + 3] = b, cost, e
            lb[#lb + 1], lb[#lb + 2], lb[#lb + 3] = a, cost, -e
        end
    end
    self.cache[continent] = net
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
    local edge = net.edges[forward and e or -e]
    local a, b = edge[1], edge[2]
    local pts = {}
    local x, y = net.x[a], net.y[a]
    for dx, dy in (edge[4] or ""):gmatch("(%-?%d+) (%-?%d+)") do
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
    if #starts == 0 or #goals == 0 then return nil, "far" end
    local goalCost = {}
    for _, g in ipairs(goals) do goalCost[g[1]] = g[2] * self.offroad end
    local dist, via, heap = {}, {}, {}
    for _, s in ipairs(starts) do
        local c = s[2] * self.offroad
        if not dist[s[1]] or c < dist[s[1]] then dist[s[1]] = c Push(heap, s[1], c) end
    end
    -- Umwege (Fluss, Gebirge) sind normal; erst ab dem Vierfachen der Luftlinie lieber geradeaus
    local best, bestNode = straight * 4, nil
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
    if not bestNode then return nil, "none" end
    -- Kantenkette zurückverfolgen
    local chain, n = {}, bestNode
    while via[n] do
        local e = via[n]
        chain[#chain + 1] = e
        local edge = net.edges[e > 0 and e or -e]
        n = e > 0 and edge[1] or edge[2]
    end
    local points = {{x = fx, y = fy}, {x = net.x[n], y = net.y[n]}}
    for k = #chain, 1, -1 do self.EdgePoints(net, chain[k], points) end
    points[#points + 1] = {x = tx, y = ty}
    points = self.Shortcut(points, self.shortcut, self.joinWithin)
    -- am Ziel genauso: rückwärts abkürzen
    local rev = {}
    for k = #points, 1, -1 do rev[#rev + 1] = points[k] end
    rev = self.Shortcut(rev, self.shortcut, self.joinWithin)
    points = {}
    for k = #rev, 1, -1 do points[#points + 1] = rev[k] end
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
    local r = holder.route
    local moved = r and (r.continent ~= continent or (r.tx - tx) ^ 2 + (r.ty - ty) ^ 2 > 30 * 30)
    if r and not moved then
        local p, rest, last = self:Next(r, px, py)
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
