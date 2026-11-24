-- Harte Pruefung der festen Routen (Neubau Bereiche, 23.11.2026 – Nutzer: "speed-leveling heisst nicht, von Ratchet
-- 2,5 km nach Norden zu laufen um dort Samophlang zu machen und dann 2,5 km zurueck"). Misst je Route, was ein Spieler
-- wirklich laeuft (Fluege und Ruhestein abgezogen, wie die Wegfuehrung sie anbietet):
--   LANG   Fusswege ueber LONG_YD
--   ABST   Abstecher: lang hin, dort hoechstens STUB_STEPS Schritte, lang zurueck in die alte Gegend
--   DOPP   Bereich doppelt: ein Ort ausserhalb der Stuetzpunkte (Gasthaus/Flugpunkt) wird nach einem Weg ueber
--          AWAY_YD wieder besucht (unter REVISIT_LVL Stufen spaeter) – "grund" = dort ging damals noch nicht alles
--   ZURUECK Rueckkehr in ein Gebiet, das man vor weniger als ZONE_BACK_LVL Stufen verlassen hat
--   REGEL  Verstoesse gegen Spielregeln (muss 0 sein): Ziel/Abgabe vor dem Annehmen, Abgabe vor dem Ziel, Folgequest
--          vor der Abgabe der Vorquest, Annehmen unter der Mindeststufe (scripts/route_opt.lua stellt Routen um)
-- Aufruf: lua5.1 scripts/check_route_areas.lua <spf> [Routes.lua] [--hart] [-v Schluessel]
--   --hart: Grenzen pruefen (LIMITS unten), Ausgang 1 bei Verstoss (scripts/build_routes.sh liefert dann nicht aus)
local spf = assert(arg[1], "Aufruf: lua5.1 scripts/check_route_areas.lua <spf> [Routes.lua] [--hart] [-v Schluessel]")
local file, hard, verboseKey = "src/ONE_Leveling/Routes.lua", false, nil
do
    local i = 2
    while arg[i] do
        if arg[i] == "--hart" then hard = true
        elseif arg[i] == "-v" then verboseKey = arg[i + 1] i = i + 1
        else file = arg[i] end
        i = i + 1
    end
end
local LONG_YD, STUB_STEPS, AWAY_YD, REVISIT_YD, REVISIT_LVL, ZONE_BACK_LVL, HUB_YD = 1500, 3, 1500, 500, 3, 3, 350
-- Grenzen fuer --hart (je Route); Begruendung siehe docs/NEUBAU_QUESTFUEHRUNG.md "Bereiche"
-- Grenzen je Route (23.11.2026, nach dem Gesamt-Optimierer): REGEL muss 0 sein. Die anderen sind Sperren gegen
-- Rueckschritte, knapp ueber dem schlechtesten erreichten Wert. Ganz 0 geht nicht: manche Quests gibt es erst
-- ab einer Stufe, dann ist ein zweiter Besuch billiger als vorher lange Monster zu hauen (z. B. Nordbrachland).
-- Vorher (22.11.) lagen die Routen bei ABST ~29, ohne Grund ~29, LANG ~210 je Route.
-- 24.11.2026 (Gebiets-Schleife): kein Fussweg ueber 1500 m fuer nur eine Aktion (EINZEL) und keine Quest, die angenommen
-- und nie abgegeben wird (OHNEABG) – beides muss 0 sein
local LIMITS = {abst = 10, doppOhne = 20, lang = 125, regel = 0, zeit = 0, einzel = 0, ohneAbg = 0}
-- Quests mit Zeitlimit: hoechstens TIMED_SHARE des Limits zwischen Annehmen und Abgeben (ZEIT muss 0 sein)
local TIMED_SHARE = .7
local NURA_YD, NURA_STEPS = 500, 80
local EINZEL_YD, CLUSTER_YD = 1640, 300
local HAUEN_MIN = 10
GetLocale = function() return "deDE" end
for _, f in ipairs({"ONE_QuestDB/Data", "ONE_QuestDB/Timed", "ONE_Leveling/Rewards"}) do assert(loadfile("src/" .. f .. ".lua"))() end
local lev = {}
for _, f in ipairs({"Planner", "FlightMasters", "Inns"}) do assert(loadfile("src/ONE_Leveling/" .. f .. ".lua"))("ONE_Leveling", lev) end
GuildTripQuestRoutes = nil
assert(loadfile(file))()
local ROUTES = assert(GuildTripQuestRoutes, "keine Routen in " .. file)
local P, Q = lev.Planner, GuildTripQuestDB
local TIMED = Q.timed or {}
local spfns = {}
assert(loadfile(spf .. "/Data/Zones.lua"))("ShortestPathForever", spfns)
local Z = spfns.Zones
local function World(m, x, y)
    local z = Z[m]
    if not z then return nil end
    return {z.map, z.maxX - y * (z.maxX - z.minX), z.maxY - x * (z.maxY - z.minY), m = m}
end
local function Dist(a, b) return math.sqrt((a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2) end
-- Starts wie scripts/build_routes.sh: Volksmaske -> Fraktion, Start, Heimat
local START = {
    [16] = {"Horde", 1420, .303, .713, 1420, .612, .526}, [2] = {"Horde", 1411, .436, .689, 1411, .519, .416},
    [128] = {"Horde", 1411, .436, .689, 1411, .519, .416}, [32] = {"Horde", 1412, .449, .772, 1412, .469, .602},
    [1] = {"Alliance", 1429, .484, .418, 1429, .437, .658}, [4] = {"Alliance", 1426, .297, .717, 1426, .474, .524},
    [64] = {"Alliance", 1426, .297, .717, 1426, .474, .524}, [8] = {"Alliance", 1438, .587, .424, 1438, .556, .598},
}
local function NodeNear(nr, ref, mapHint)
    local n = Q.n[nr or 0]
    if not n then return nil end
    local best, bd
    for i = 2, #n, 3 do
        local w = World(n[i], n[i + 1] / 1000, n[i + 2] / 1000)
        if w then
            local d = (ref and w[1] == ref[1]) and Dist(w, ref) or 1e9
            if n[i] == mapHint then d = d - 1 end
            if not bd or d < bd then best, bd = w, d end
        end
    end
    return best
end
-- kann eine Aktion schon am frueheren Halt i? (Stufe, Vorquests, angenommen/erledigt davor)
local function Check(key, route)
    local rmask = tonumber(key:match("^(%d+):"))
    local st = START[rmask]
    local fac = st[1]
    local facN = fac == "Alliance" and 1 or 2
    local function Mine(f) return f % (facN * 2) >= facN end
    local known, fps, hubs = {}, {}, {}
    for _, f in ipairs(lev.FLIGHTMASTERS) do
        if Mine(f[5]) then
            local z = Z[f[7] or 0]
            fps[#fps + 1] = {f[2], f[3], f[4], id = f[1], map = f[7]}
            hubs[#hubs + 1] = {f[2], f[3], f[4]}
            if z and ((z.low or 99) < 2 or f[7] == st[2] or z.city) then known[f[1]] = true end
        end
    end
    local inns = {}
    for _, n in ipairs(lev.INNS) do if Mine(n[5]) then inns[n[1]] = {n[2], n[3], n[4]} hubs[#hubs + 1] = {n[2], n[3], n[4]} end end
    local function IsHub(w)
        for _, h in ipairs(hubs) do if h[1] == w[1] and Dist(h, w) <= HUB_YD then return true end end
        return false
    end
    local home = World(st[5], st[6], st[7])
    local pos = World(st[2], st[3], st[4])
    local t, hearthAt = 0, -1e9
    -- Zeitquests (Nutzer 23.11.2026): Minuten zwischen Annehmen und Abgeben wie scripts/route_opt.lua gerechnet
    local tw, tAcc, tGrind = 0, {}, {}
    local out = {lang = 0, abst = 0, dopp = 0, doppOhne = 0, zurueck = 0, walkYd = 0, langYd = 0, steps = #route, lines = {}, zeit = 0, zeitLines = {}}
    local function Note(s) if verboseKey == key then out.lines[#out.lines + 1] = s end end
    -- Zustand fuer "ging das schon?"
    local accAt, objAt, turnAt = {}, {}, {}
    local pts = {}  -- je Schritt: {w, l, i, hub}
    local legs = {} -- je Schritt: laengster Fussweg-Teil dorthin
    local function Walk(a, b) return Dist(a, b) * P.DETOUR / 7 / 60 end
    local function NearestFP(w)
        local best, bd
        for _, f in ipairs(fps) do
            if known[f.id] and f[1] == w[1] then local d = Dist(f, w) if not bd or d < bd then best, bd = f, d end end
        end
        return best
    end
    for i, r in ipairs(route) do
        local w
        if (r.k == "fp" or r.k == "dungeon") and r.m then w = World(r.m, r.x / 1000, r.y / 1000)
        elseif r.k == "fp" and r.z then
            -- Routen-Schritt "Flugpunkt lernen" ohne Lage: der eigene Flugpunkt der Zone, der am naechsten liegt
            local bd
            for _, f in ipairs(fps) do
                if f.map == r.z and pos and f[1] == pos[1] then local d = Dist(f, pos) if not bd or d < bd then w, bd = f, d end end
            end
            if not w then for _, f in ipairs(fps) do if f.map == r.z then w = f break end end end
        elseif r.k == "bind" then w = inns[r.inn or 0]
        elseif r.k == "grind" then w = nil
        elseif r.p and r.p[1] then w = NodeNear(r.p[1], pos, r.z)
        elseif r.n then w = NodeNear(r.n, pos, r.z) end
        if w and pos then
            local legWalk = 0
            if w[1] ~= pos[1] then
                t = t + 10  -- Schiff/Zeppelin
            else
                local d = Dist(pos, w)
                local wm = Walk(pos, w)
                local best, parts = wm, {d}
                local fa, fb = NearestFP(pos), NearestFP(w)
                if fa and fb and fa ~= fb then
                    local fm = Walk(pos, fa) + Dist(fa, fb) * P.FLY_DETOUR / P.FLY_SPEED / 60 + P.FLY_EXTRA + Walk(fb, w)
                    if fm < wm * .8 and fm < best then best, parts = fm, {Dist(pos, fa), Dist(fb, w)} end
                end
                if home and home[1] == w[1] and t - hearthAt >= P.HS_CD then
                    local hm = P.HS_MIN + Walk(home, w)
                    if hm <= wm - P.HS_SAVE and hm < best then best, parts = hm, {Dist(home, w)} hearthAt = t end
                end
                t = t + best
                tw = tw + best
                for _, x in ipairs(parts) do
                    out.walkYd = out.walkYd + x
                    if x > legWalk then legWalk = x end
                end
            end
            legs[i] = legWalk
            if legWalk > LONG_YD then
                out.lang, out.langYd = out.lang + 1, out.langYd + legWalk
                Note(("  LANG %4d yd -> Schritt %d %s (St %d, Karte %d)"):format(legWalk, i, r[1] or r.k, r.l or 0, r.z or 0))
            end
            pos = w
        end
        if r.k == "fp" and w then for _, f in ipairs(fps) do if f[1] == w[1] and Dist(f, w) < 60 then known[f.id] = true end end end
        if r.k == "bind" and w then home = w end
        -- Zeit je Schritt (grob): Ziele 2 min, sonst Sprechen
        for k in (r[1] or ""):gmatch("(%a)%d+") do t = t + (k == "o" and 2 or .2) end
        if r.k == "grind" then for id in pairs(tAcc) do tGrind[id] = true end end
        for k, id in (r[1] or ""):gmatch("(%a)(%d+)") do
            id = tonumber(id)
            local lim = TIMED[id]
            if lim and k == "a" and not tAcc[id] then tAcc[id], tGrind[id] = tw, nil end
            if lim and k == "t" and tAcc[id] then
                local m = tw - tAcc[id]
                if m > lim / 60 * TIMED_SHARE or tGrind[id] then
                    out.zeit = (out.zeit or 0) + 1
                    out.zeitLines[#out.zeitLines + 1] = ("  ZEIT Schritt %d q%d: %.0f min offen (Limit %d min)%s"):format(i, id, m, lim / 60, tGrind[id] and ", Hauen dazwischen" or "")
                end
                tAcc[id] = nil
            end
            tw = tw + (k == "o" and 3 or .5)
        end
        pts[i] = w and {w = w, l = r.l or 0, hub = IsHub(w)} or false
        for k, id in (r[1] or ""):gmatch("(%a)(%d+)") do
            id = tonumber(id)
            if k == "a" then accAt[id] = accAt[id] or i elseif k == "o" then objAt[id] = i elseif k == "t" then turnAt[id] = i end
        end
    end
    -- Nur zum Annehmen hingelaufen (Spieltest 23.11.2026 "Raecht mein Dorf"): ein Schritt, der nur annimmt und mit
    -- einem Fussweg > NURA_YD erreicht wird, braucht fuer mindestens eine seiner Quests Ziel oder Abgabe in den
    -- naechsten NURA_STEPS Schritten im selben Gebiet; sonst ANNEHMEN. Angenommen und nie abgegeben: OHNEABG.
    out.annehmen, out.ohneAbg, out.annLines = 0, 0, {}
    for id, ia in pairs(accAt) do
        if not turnAt[id] then
            out.ohneAbg = out.ohneAbg + 1
            Note(("  OHNEABG q%d angenommen Schritt %d, nie abgegeben"):format(id, ia))
        end
    end
    for i, r in ipairs(route) do
        local toks, onlyA = {}, r[1] ~= nil
        for k, id in (r[1] or ""):gmatch("(%a)(%d+)") do
            if k ~= "a" then onlyA = false end
            toks[#toks + 1] = tonumber(id)
        end
        if onlyA and #toks > 0 and (legs[i] or 0) > NURA_YD then
            local soon = false
            for j = i + 1, math.min(#route, i + NURA_STEPS) do
                local q = route[j]
                if q.z ~= r.z then break end
                for k, id in (q[1] or ""):gmatch("(%a)(%d+)") do
                    id = tonumber(id)
                    if k ~= "a" then for _, t in ipairs(toks) do if t == id then soon = true end end end
                end
                if soon then break end
            end
            if not soon then
                out.annehmen = out.annehmen + 1
                out.annLines[#out.annLines + 1] = ("  ANNEHMEN Schritt %d %s: %.0f yd hin, Quest erst spaeter"):format(i, r[1], legs[i])
            end
        end
    end
    -- Langer Fussweg fuer fast nichts (Nutzer 23.11.2026: "ich soll wieder ueber 2000 m laufen um irgendwo eine Quest
    -- anzunehmen"): Fussweg-Teil > EINZEL_YD (1500 m, nach Flug), und am Ziel (dieser Halt + direkt folgende Halte
    -- < CLUSTER_YD) weniger als ein Block Arbeit: hoechstens eine Annahme/Abgabe und kein Ziel -> EINZEL
    -- Hauen am Stueck (Nutzer: ~10 min ok): Routen-Schritte "grind" mit min > HAUEN_MIN
    out.hauen, out.hauenMax = 0, 0
    for i, r in ipairs(route) do
        if r.k == "grind" and (r.min or 0) > HAUEN_MIN then
            out.hauen = out.hauen + 1
            out.hauenMax = math.max(out.hauenMax, r.min)
            out.annLines[#out.annLines + 1] = ("  HAUEN Schritt %d: %d min am Stueck (St %d -> %d)"):format(i, r.min, r.l or 0, r.to or 0)
        end
    end
    out.einzel = 0
    for i, r in ipairs(route) do
        if (legs[i] or 0) > EINZEL_YD and r[1] and pts[i] then
            local n, obj = 0, false
            local j = i
            while route[j] do
                local q = route[j]
                if j > i and (not pts[j] or Dist(pts[j].w, pts[i].w) > CLUSTER_YD) then break end
                for k in (q[1] or ""):gmatch("(%a)%d+") do n = n + 1 if k == "o" then obj = true end end
                j = j + 1
            end
            if n < 2 and not obj then
                out.einzel = out.einzel + 1
                out.annLines[#out.annLines + 1] = ("  EINZEL Schritt %d %s: %.0f m zu Fuss fuer eine Aktion"):format(i, r[1], legs[i] * .9144)
            end
        end
    end
    local function Could(tok, i)
        local k, id = tok:match("^(%a)(%d+)")
        id = tonumber(id)
        local e = Q.q[id] or {}
        if k == "a" then
            if (e[2] or 0) > (pts[i] and pts[i].l or route[i].l or 0) then return false end
            local function Was(p) return turnAt[p] and turnAt[p] < i end
            if type(e[9]) == "table" then for _, p in ipairs(e[9]) do if turnAt[p] and not Was(p) then return false end end end
            if type(e[5]) == "table" and #e[5] > 0 then
                local any, known2 = false, false
                for _, p in ipairs(e[5]) do if turnAt[p] then known2 = true if Was(p) then any = true end end end
                if known2 and not any then return false end
            end
            return true
        elseif k == "o" then return accAt[id] ~= nil and accAt[id] < i
        elseif k == "t" then return (objAt[id] or accAt[id] or 1e9) < i end
        return false
    end
    -- ABST: lang hin, wenige Schritte dort, lang zurueck in die Gegend von vorher
    for i = 2, #route do
        if (legs[i] or 0) > LONG_YD and pts[i - 1] then
            local origin = nil
            for b = i - 1, 1, -1 do if pts[b] then origin = pts[b].w break end end
            for j = i + 1, math.min(#route, i + STUB_STEPS) do
                if (legs[j] or 0) > LONG_YD and pts[j] and origin and pts[j].w[1] == origin[1] and Dist(pts[j].w, origin) <= 800 then
                    out.abst = out.abst + 1
                    Note(("  ABST Schritte %d-%d (%s) St %d"):format(i, j - 1, route[i][1] or route[i].k, route[i].l or 0))
                    break
                end
            end
        end
    end
    -- DOPP: Ort ausserhalb der Stuetzpunkte nach weitem Weg wieder besucht
    for j = 2, #route do
        local pj = pts[j]
        if pj and not pj.hub and route[j][1] then
            local away = false
            for i = j - 1, 1, -1 do
                local pi = pts[i]
                if pi then
                    if pi.w[1] ~= pj.w[1] then away = true
                    elseif Dist(pi.w, pj.w) > AWAY_YD then away = true
                    elseif away and Dist(pi.w, pj.w) <= REVISIT_YD then
                        -- erste Rueckkehr dieses Besuchs (Schritt davor war nicht schon hier)
                        local prevHere = false
                        for b = j - 1, 1, -1 do if pts[b] then prevHere = pts[b].w[1] == pj.w[1] and Dist(pts[b].w, pj.w) <= REVISIT_YD break end end
                        if not prevHere and pj.l - pi.l < REVISIT_LVL then
                            -- ohne Grund: alles an diesem Besuch (bis man wieder weggeht) ging schon damals
                            local all = true
                            for b = j, #route do
                                local pb = pts[b]
                                if pb and (pb.w[1] ~= pj.w[1] or Dist(pb.w, pj.w) > REVISIT_YD) then break end
                                for tok in (route[b][1] or ""):gmatch("%a%d+") do if not Could(tok, i) then all = false end end
                            end
                            out.dopp = out.dopp + 1
                            if all then out.doppOhne = out.doppOhne + 1 end
                            Note(("  DOPP Schritt %d (%s, St %d) war schon bei Schritt %d (St %d)%s"):format(j, route[j][1], pj.l, i, pi.l, all and " OHNE GRUND" or ""))
                        end
                        break
                    end
                end
            end
        end
    end
    -- ZURUECK: Gebiet (ohne Staedte), das man vor < ZONE_BACK_LVL Stufen verlassen hat
    local cur, leftAt = nil, {}
    for i, r in ipairs(route) do
        local z = r.z
        if z and r[1] and not (Z[z] and Z[z].city) and (r[1]:find("a") or r[1]:find("t")) then
            if cur and z ~= cur then
                leftAt[cur] = r.l or 0
                if leftAt[z] and (r.l or 0) < leftAt[z] + ZONE_BACK_LVL then
                    out.zurueck = out.zurueck + 1
                    Note(("  ZURUECK Schritt %d nach Karte %d (St %d, verlassen mit %d)"):format(i, z, r.l or 0, leftAt[z]))
                end
            end
            cur = z
        end
    end
    out.minutes = t
    return out
end

-- Spielregeln entlang der Route (unabhaengig vom Umstellen gerechnet)
local function Rules(key, route)
    local pa, po, pt, inT = {}, {}, {}, {}
    for i, r in ipairs(route) do
        for k, id in (r[1] or ""):gmatch("(%a)(%d+)") do
            id = tonumber(id)
            if k == "a" then pa[id] = pa[id] or i elseif k == "o" then po[id] = math.max(po[id] or 0, i) else pt[id] = i inT[id] = true end
        end
    end
    local bad, lines = 0, {}
    local function Bad(msg) bad = bad + 1 if #lines < 20 then lines[#lines + 1] = "  REGEL " .. msg end end
    for i, r in ipairs(route) do
        local seen = {}
        for k, id in (r[1] or ""):gmatch("(%a)(%d+)") do
            id = tonumber(id)
            local e = Q.q[id] or {}
            if k == "a" and not seen[id] then
                seen[id] = true
                if (e[2] or 0) > (r.l or 0) then Bad(("Schritt %d a%d mit Stufe %d unter Mindeststufe %d"):format(i, id, r.l or 0, e[2])) end
                if type(e[9]) == "table" then
                    for _, p in ipairs(e[9]) do if inT[p] and not (pt[p] and pt[p] <= i) then Bad(("Schritt %d a%d vor Abgabe der Vorquest %d"):format(i, id, p)) end end
                end
                if type(e[5]) == "table" and #e[5] > 0 then
                    local any, ok = false, false
                    for _, p in ipairs(e[5]) do if inT[p] then any = true if pt[p] and pt[p] <= i then ok = true end end end
                    if any and not ok then Bad(("Schritt %d a%d vor Abgabe einer Vorquest"):format(i, id)) end
                end
            elseif k == "o" then
                if pa[id] and pa[id] > i then Bad(("Schritt %d o%d vor dem Annehmen"):format(i, id)) end
                if pt[id] and pt[id] < i then Bad(("Schritt %d o%d nach der Abgabe"):format(i, id)) end
            elseif k == "t" then
                if pa[id] and pa[id] > i then Bad(("Schritt %d t%d vor dem Annehmen"):format(i, id)) end
            end
        end
    end
    return bad, lines
end

local keys = {}
for k in pairs(ROUTES) do keys[#keys + 1] = k end
table.sort(keys)
local sum = {lang = 0, abst = 0, dopp = 0, doppOhne = 0, zurueck = 0, walkYd = 0, steps = 0, regel = 0, zeit = 0, annehmen = 0, ohneAbg = 0, einzel = 0, hauen = 0}
local bad = {}
for _, k in ipairs(keys) do
    local o = Check(k, ROUTES[k])
    local rl
    o.regel, rl = Rules(k, ROUTES[k])
    print(("%-8s %4d Schr.  Fussweg %5.0f km  LANG %3d  ABST %2d  DOPP %3d (ohne Grund %2d)  ZURUECK %2d  REGEL %d  ZEIT %d  ANNEHMEN %d  OHNEABG %d  EINZEL %d  HAUEN %d (max %d)"):format(k, o.steps,
        o.walkYd / 1094, o.lang, o.abst, o.dopp, o.doppOhne, o.zurueck, o.regel, o.zeit, o.annehmen, o.ohneAbg, o.einzel, o.hauen, o.hauenMax))
    for _, l in ipairs(o.lines) do print(l) end
    for _, l in ipairs(o.zeitLines) do print(l) end
    for _, l in ipairs(o.annLines) do print(l) end
    if o.regel > 0 then for _, l in ipairs(rl) do print(l) end end
    for f in pairs(sum) do sum[f] = sum[f] + (o[f] or 0) end
    for f, lim in pairs(LIMITS) do if (o[f] or 0) > lim then bad[#bad + 1] = ("%s %s=%d (Grenze %d)"):format(k, f, o[f], lim) end end
end
print(("SUMME %d Routen, %d Schritte, Fussweg %.0f km, LANG %d, ABST %d, DOPP %d (ohne Grund %d), ZURUECK %d, REGEL %d, ZEIT %d, ANNEHMEN %d, OHNEABG %d, EINZEL %d, HAUEN %d"):format(#keys, sum.steps,
    sum.walkYd / 1094, sum.lang, sum.abst, sum.dopp, sum.doppOhne, sum.zurueck, sum.regel, sum.zeit, sum.annehmen, sum.ohneAbg, sum.einzel, sum.hauen))
if hard and #bad > 0 then
    print("PRUEFUNG NICHT BESTANDEN:\n  " .. table.concat(bad, "\n  "))
    os.exit(1)
elseif hard then print("PRUEFUNG BESTANDEN") end
