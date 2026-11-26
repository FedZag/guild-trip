-- Guild Trip Quest-Fuehrung: Stuetzpunkt fuer Stuetzpunkt (Neuanfang 26.11.2026, mit dem Nutzer abgestimmt).
-- Statt einer am Rechner vorberechneten festen Route entscheidet das Spiel live mit der ECHTEN Stufe:
--  1. Feste Gebietsfolge je Volk (wie ein geschriebener Leitfaden, H.ORDER) – kein "naechstes passendes Gebiet".
--  2. Gequestet wird nur im angefangenen Gebiet (state.zone, je Figur gemerkt). Wo man gerade steht, zaehlt nicht:
--     ein Abstecher nach Orgrimmar zum Lehrer oder ins Auktionshaus bleibt ein Abstecher (Nutzer 26.11.2026).
--  3. Im Gebiet: der Stuetzpunkt (Questgeber nah beieinander) mit passenden Quests, der am naechsten liegt. Dort wird
--     ALLES angenommen, was das Spiel hergibt (Mindeststufe erreicht, nicht grau). Erledigt wird eine Quest, sobald
--     sie hoechstens H.AHEAD (2) Stufen ueber einem liegt – die Schleife bringt sie in die richtige Reihenfolge.
--  4. Eine Schleife: annehmen -> Ziele -> abgeben, kuerzester Weg mit Reihenfolge-Bedingungen (Einfuegen + Verschieben).
--     Quests am Weg mit Ziel im selben Gebiet (Geber nah am Weg, Ziel nah an den Zielen der Runde) kommen mit.
--  5. Stuetzpunkt leer -> naechster im Gebiet; Gebiet leer -> erstes Gebiet der Folge mit passenden Quests (frueher
--     zu hohe Reste werden so nachgeholt, bevor es weitergeht).
--  6. Monster hauen nur fuer ein paar tausend EP (H.GRIND_XP), nie ganze Stufen; sonst ausnahmsweise +2/+3 Stufen.
--  7. Dungeons nicht (Ziel im Dungeon), Vorquests draussen schon; Elite "Spaeter" (1 = ans Ende, 2 = raus).
-- Ergebnis ist ein Fahrplan (follow: "accept:ID"/"obj:ID"/"turnin:ID"/"fp:ID" -> Platz) fuer P:Plan (ctx.route);
-- der Planer macht daraus Schritte mit Reisen (Fuss, Flug, Ruhestein, Schiff/Zeppelin) und Anzeige.
-- Reine Rechnung, offline testbar (tests/test_hubs_178.lua, scripts/sim_leveling.lua SIM_HUB=1).
local _, lev = ...
local H = {}
lev.Hubs = H

H.AHEAD = 2          -- Quests erledigen bis so viele Stufen ueber der eigenen (Nutzer 26.11.: erst "1 reicht", nach
                     -- der Messung (+1 macht die vielen Gebietswechsel) am selben Tag: "stell auf 2 stufen um"; gelb im Spiel)
H.AHEAD_MAX = 3      -- Notfall (nirgends etwas, Hauen waere zu lang): schrittweise bis hierhin
H.GRIND_XP = 3000    -- hoechstens so viele EP Monster hauen ("ein paar tausend EP sind ok, aber nicht ganze Stufen")
H.GRIND_SHARE = .4   -- ... und hoechstens dieser Teil der aktuellen Stufe
H.HUB_R = 200        -- Questgeber so nah beieinander (yd, Kette) bilden einen Stuetzpunkt
H.WAY_NEAR = 150     -- Geber so nah am Weg der Runde: mitnehmen ...
H.AREA_NEAR = 450    -- ... wenn Ziel und Abgabe so nah an Zielen/Abgaben der Runde liegen
H.OUT_NEAR = 600     -- Ziel knapp ueber der Gebietsgrenze: gehoert noch zur Runde, wenn so nah an einem Halt im Gebiet
H.FP_NEAR = 400      -- unbekannter Flugpunkt so nah an einem Halt: in die Runde
H.ZONE_MIN = 3       -- in ein anderes Gebiet erst fuer so viele passende Quests (keine Weltreise fuer eine Quest)
H.REVISIT_MIN = 5    -- zurueck in ein schon verlassenes Gebiet erst fuer so viele (kein Hin und Her)
H.LOG_MAX = 35       -- Questlog (Forever 40, etwas Luft)
H.LOG_SOFT = 25      -- hoehere Quests (noch nicht machbar) nur annehmen, solange das Log hoechstens so voll ist ...
H.ACCEPT_AHEAD = 3   -- ... und sie hoechstens so viele Stufen ueber einem liegen (Platz fuer das, was jetzt geht)
H.FAR = 20000        -- anderer Kontinent (yd, nur fuer die Reihenfolge)

-- Feste Gebietsfolge je Volk (Volks-Bit wie im Planer). Danach die gemeinsame Folge der Fraktion.
local HORDE_TAIL = {1440, 1424, 1441, 1443, 1417, 1434, 1445, 2548, 1418, 1435, 1446, 1444, 1425, 1427, 1447, 1448,
    1449, 1419, 1428, 1422, 1452, 1423, 1451}
local ALLY_TAIL = {1440, 1424, 1441, 1443, 1417, 1434, 1445, 2548, 1418, 1435, 1446, 1444, 1425, 1427, 1447, 1448,
    1449, 1419, 1428, 1422, 1452, 1423, 1451}
H.START = {
    [2] = {1411, 1413, 1442}, [128] = {1411, 1413, 1442},        -- Orc/Troll: Durotar, Brachland, Steinkrallen
    [32] = {1412, 1413, 1442},                                   -- Tauren: Mulgore, Brachland, Steinkrallen
    [16] = {1420, 1421, 1413, 1442},                             -- Untote: Tirisfal, Silberwald, Brachland, Steinkrallen
    [1] = {1429, 1436, 1433, 1437, 1431},                        -- Menschen: Elwynn, Westfall, Rotkamm, Sumpfland, Daemmerwald
    [4] = {1426, 1432, 1436, 1433, 1437, 1431}, [64] = {1426, 1432, 1436, 1433, 1437, 1431},  -- Zwerge/Gnome
    [8] = {1438, 1439, 1440, 1442, 1433, 1437, 1431},            -- Nachtelfen: Teldrassil, Dunkelkueste, Eschental …
}
-- Himmelsgeborene (Forever, kein altes Volk): wie Tauren (Horde, Donnerfels) bzw. Nachtelfen (Allianz)
H.SKY = {Horde = 32, Alliance = 8}
H.CITY = {[1454] = true, [1456] = true, [1458] = true, [1453] = true, [1455] = true, [1457] = true}
-- Stadt-Quests ohne Ziel draussen gehoeren zu diesen Gebieten (das erste, das in der eigenen Folge vorkommt)
H.CITY_NEAR = {[1454] = {1411, 1413}, [1456] = {1412, 1413}, [1458] = {1420, 1421}, [1453] = {1429, 1436},
    [1455] = {1426, 1432}, [1457] = {1438, 1439}}

local function Planner() return lev.Planner end
local function Data()
    local q, r = rawget(_G, "GuildTripQuestDB"), rawget(_G, "GuildTripLeveling")
    if type(q) ~= "table" or type(q.q) ~= "table" then return nil end
    return q, type(r) == "table" and r or {r = {}, dz = {}}
end

local orderCache = {}
local inOrderCache = setmetatable({}, {__mode = "k"})
function H.Order(race, faction)
    local key = tostring(race) .. ":" .. tostring(faction)
    if orderCache[key] then return orderCache[key] end
    local r = race or H.SKY[faction or ""]
    local start = H.START[r or 0]
    if not start then return nil end
    local out, seen = {}, {}
    local tail = (faction == "Alliance") and ALLY_TAIL or HORDE_TAIL
    for _, list in ipairs({start, tail}) do
        for _, z in ipairs(list) do if not seen[z] then seen[z] = true out[#out + 1] = z end end
    end
    orderCache[key] = out
    return out
end

-- ===== Orte (Welt-Yards, gemerkt: die Daten aendern sich nicht) =====
local ptCache = {}
local function Points(Q, nr, world)
    local p = ptCache[nr]
    if p == nil then
        p = {}
        local n = Q.n and Q.n[nr]
        for i = 2, n and #n or 0, 3 do
            local m, x, y = n[i], n[i + 1] / 1000, n[i + 2] / 1000
            local c, wx, wy = world(m, x, y)
            if c then p[#p + 1] = {c, wx, wy, m, x, y} end
        end
        ptCache[nr] = p
    end
    return p
end
H.Points = Points
local function D(a, b)
    if not (a and b) then return H.FAR end
    if a[1] ~= b[1] then return H.FAR end
    return math.sqrt((a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end
H.Dist = D
-- naechster Punkt einer Knotenliste zu ref (ohne ref: erster); optional nur auf Karte zone
local function Nearest(Q, nodes, ref, world, zone)
    local best, bd
    for _, nr in ipairs(nodes or {}) do
        for _, p in ipairs(Points(Q, nr, world)) do
            if not zone or p[4] == zone then
                local d = ref and D(ref, p) or 0
                if not bd or d < bd then best, bd = p, d end
            end
        end
    end
    return best, bd
end

-- ===== Welche Quests gibt es fuer mich? =====
-- Grundsaetzlich machbar (ohne Stufe): Volk/Klasse/Vorquests/Beruf (P.Fits), keine Raid/PvP, kein Ziel im Dungeon,
-- mit Queststufe und EP, Start nicht durch einen Gegenstand von Gegnern
local function Basic(P, Q, R, id, e)
    if (e[1] or 0) <= 0 or (e[11] or 0) <= 0 then return false end
    if (R.dz or {})[e[14] or 0] then return false end
    local rew = P.Rew(R, id)
    local kind = rew and rew[3] or 0
    if math.floor(kind / 4) % 2 == 1 or math.floor(kind / 8) % 2 == 1 then return false end
    return true
end

-- Heimatgebiet einer Quest = Gebiet des Gebers; Stadt-Geber: Gebiet der Ziele/der Abgabe draussen, sonst das erste
-- Nachbargebiet der Stadt in der eigenen Folge
local homeCache = {}
local function Home(Q, id, e, world, inOrder)
    local key = id .. ":" .. tostring(inOrder)
    local h = homeCache[key]
    if h ~= nil then return h or nil end
    local g = Nearest(Q, e[6], nil, world)
    h = g and g[4] or false
    if h and H.CITY[h] then
        -- (nur auf demselben Kontinent: Unterstadt-Quest mit Ziel in Tausend Nadeln ist keine Nadeln-Quest)
        local out
        for _, nr in ipairs(e[8] or {}) do
            for _, p in ipairs(Points(Q, nr, world)) do if not H.CITY[p[4]] and p[1] == g[1] then out = p[4] break end end
            if out then break end
        end
        if not out and #(e[8] or {}) == 0 then
            for _, nr in ipairs(e[7] or {}) do
                for _, p in ipairs(Points(Q, nr, world)) do if not H.CITY[p[4]] and p[1] == g[1] then out = p[4] break end end
                if out then break end
            end
        end
        if not out then
            for _, z in ipairs(H.CITY_NEAR[h] or {}) do if inOrder[z] then out = z break end end
        end
        h = out or h
    end
    homeCache[key] = h
    return h or nil
end

-- ===== Reihenfolge: kuerzester Weg mit Bedingungen =====
-- stops = {{key, w = {c, x, y}, pre = {key, …}}}; Start = start (Welt). Offener Weg (Ende egal).
-- Topologisch einfuegen (billigste Stelle), dann einzelne Halte und Paare verschieben, solange es kuerzer wird.
function H.Order2(stops, start)
    local byKey, succ, indeg = {}, {}, {}
    for _, s in ipairs(stops) do byKey[s.key] = s succ[s.key] = {} indeg[s.key] = 0 end
    for _, s in ipairs(stops) do
        for _, p in ipairs(s.pre or {}) do
            if byKey[p] then table.insert(succ[p], s.key) indeg[s.key] = indeg[s.key] + 1 end
        end
    end
    local rankKind = {fp = 1, accept = 1, obj = 2, turnin = 3}
    local ready = {}
    for _, s in ipairs(stops) do if indeg[s.key] == 0 then ready[#ready + 1] = s end end
    local topo = {}
    local function Better(a, b)
        local ka, kb = rankKind[a.kind] or 2, rankKind[b.kind] or 2
        if ka ~= kb then return ka < kb end
        local da, db = D(start, a.w), D(start, b.w)
        if math.abs(da - db) > .01 then return da < db end
        return a.key < b.key
    end
    while #ready > 0 do
        table.sort(ready, Better)
        local s = table.remove(ready, 1)
        topo[#topo + 1] = s
        for _, k in ipairs(succ[s.key]) do
            indeg[k] = indeg[k] - 1
            if indeg[k] == 0 then ready[#ready + 1] = byKey[k] end
        end
    end
    -- Kreis in den Bedingungen (sollte nicht vorkommen): Rest hinten anhaengen
    if #topo < #stops then
        local inT = {}
        for _, s in ipairs(topo) do inT[s.key] = true end
        for _, s in ipairs(stops) do if not inT[s.key] then topo[#topo + 1] = s end end
    end
    local path = {}
    local function W(i) if i == 0 then return start end return path[i] and path[i].w end
    local function Pos()
        local at = {}
        for i, s in ipairs(path) do at[s.key] = i end
        return at
    end
    local function Range(s, at)
        local lo, hi = 1, #path + 1
        for _, p in ipairs(s.pre or {}) do if at[p] and at[p] + 1 > lo then lo = at[p] + 1 end end
        for _, k in ipairs(succ[s.key]) do if at[k] and at[k] < hi then hi = at[k] end end
        return lo, hi
    end
    local function InsCost(s, i)
        local a, b = W(i - 1), W(i)
        if b then return D(a, s.w) + D(s.w, b) - D(a, b) end
        return D(a, s.w)
    end
    for _, s in ipairs(topo) do
        local at = Pos()
        local lo, hi = Range(s, at)
        local bi, bc = hi, nil
        for i = lo, hi do
            local c = InsCost(s, i)
            if not bc or c < bc - .001 then bi, bc = i, c end
        end
        table.insert(path, bi, s)
    end
    -- Verschieben (Or-Opt mit Laenge 1..3)
    local function RemCost(i, len)
        local a, b = W(i - 1), W(i + len)
        local inner = 0
        for k = i, i + len - 2 do inner = inner + D(path[k].w, path[k + 1].w) end
        local c = D(a, path[i].w) + inner
        if b then c = c + D(path[i + len - 1].w, b) - D(a, b) end
        return c, inner
    end
    for _ = 1, 25 do
        local improved = false
        for len = 1, 3 do
            local i = 1
            while i + len - 1 <= #path do
                local seg = {}
                for k = i, i + len - 1 do seg[#seg + 1] = path[k] end
                local gain, inner = RemCost(i, len)
                for _ = 1, len do table.remove(path, i) end
                local at = Pos()
                local lo, hi = 1, #path + 1
                local inSeg = {}
                for _, s in ipairs(seg) do inSeg[s.key] = true end
                for _, s in ipairs(seg) do
                    local l2, h2 = Range(s, at)
                    if l2 > lo then lo = l2 end
                    if h2 < hi then hi = h2 end
                end
                local bi, bc = i, nil
                for j = lo, hi do
                    local a, b = W(j - 1), W(j)
                    local c = D(a, seg[1].w) + inner
                    if b then c = c + D(seg[#seg].w, b) - D(a, b) end
                    if not bc or c < bc - .001 then bi, bc = j, c end
                end
                if bc and bc < gain - 1 and bi ~= i then
                    for k, s in ipairs(seg) do table.insert(path, bi + k - 1, s) end
                    improved = true
                else
                    for k, s in ipairs(seg) do table.insert(path, i + k - 1, s) end
                end
                i = i + 1
            end
        end
        if not improved then break end
    end
    return path
end
function H.PathLength(path, start)
    local sum, prev = 0, start
    for _, s in ipairs(path) do sum = sum + D(prev, s.w) prev = s.w end
    return sum
end

-- ===== Entscheiden =====
-- ctx wie fuer P:Plan (me, done, inLog, complete, targets, world, fpSpots); state = je Figur gemerkt
-- ({zone, hub, anchor = {c, x, y}, round}), later = {[Quest] = 1|2}.
-- Rueckgabe {zone, hub, hubName, follow, loops, gates, ahead, waiting = {[Quest] = Grund}, work, keys, grindTo}
function H.Decide(ctx, state, later)
    local P = Planner()
    local Q, R = Data()
    if not (P and Q and ctx and ctx.me and ctx.world) then return nil end
    state = state or {}
    later = later or {}
    local me, world = ctx.me, ctx.world
    local L = me.level or 1
    local done = ctx.done or function() return false end
    local inLog = ctx.inLog or function() return false end
    local complete = ctx.complete or function() return false end
    local order = H.Order(me.race, me.faction)
    if not order then return nil end
    -- (je Folge einmal gebaut: Home merkt sich Ergebnisse je Folge – eine neue Tabelle je Aufruf liess den Speicher
    -- bei jedem Neuplanen wachsen)
    local inOrder = inOrderCache[order]
    if not inOrder then
        inOrder = {}
        for i, z in ipairs(order) do inOrder[z] = i end
        inOrderCache[order] = inOrder
    end
    local grey = P.GreyBelow(L)
    local here
    if me.mapID then
        local c, wx, wy = world(me.mapID, me.x or .5, me.y or .5)
        if c then here = {c, wx, wy, me.mapID} end
    end
    local function PreDone(e)
        if type(e[9]) == "table" then for _, p in ipairs(e[9]) do if not done(p) then return false end end end
        if type(e[5]) == "table" and #e[5] > 0 then
            for _, p in ipairs(e[5]) do if done(p) then return true end end
            return false
        end
        return true
    end
    -- offene Ziel-Knoten (im Log nur die noch offenen)
    local function Targets(id)
        if ctx.targets and inLog(id) then
            local ok, r = pcall(ctx.targets, id)
            if ok and type(r) == "table" and #r > 0 then return r end
        end
        return (Q.q[id] or {})[8] or {}
    end
    -- Quests sammeln: im Log (alles, was die DB kennt) + annehmbar (Mindeststufe erreicht, nicht grau)
    local Q2 = {}
    local logCount = 0
    for id, e in pairs(Q.q) do
        local log = inLog(id)
        if log then logCount = logCount + 1 end
        if log and not done(id) then
            Q2[#Q2 + 1] = {id = id, e = e, log = true, complete = complete(id)}
        elseif not done(id) and (later[id] or 0) < 2 and Basic(P, Q, R, id, e) and not P.IsDrop(e)
            and (e[2] or 0) <= L + H.AHEAD_MAX and e[1] > grey and P.Fits(id, e, me, done, inLog)
            and not ((e[12] or 0) > 0 and (done(e[12]) or inLog(e[12]))) then
            -- Vorquest fehlt: nur fuer Ketten in der Runde (s. u.), nicht zum Annehmen
            Q2[#Q2 + 1] = {id = id, e = e, log = false, pre = PreDone(e)}
        end
    end
    for _, q in ipairs(Q2) do
        q.home = Home(Q, q.id, q.e, world, inOrder)
        -- offene Dungeon-Quest im Log (Regel: keine Dungeons): zaehlt nie als Arbeit – der Planer plant sie nicht, sonst
        -- hielte sie das Gebiet fest und die Fuehrung waere leer (Spieltest 26.11.2026: Hoehle des Wehklagens, Ziele
        -- laut Daten teils draussen im Brachland)
        -- (fertig: die Abgabe draussen plant die Fuehrung weiter)
        q.dungeon = (R.dz or {})[q.e[14] or 0] and not q.complete and true or false
        q.class = P.IsClassQuest(q.e)
    end
    -- Klassenquest mit Zauber am Ende der Reihe (R.sp): Abstecher, wechselt nie das Gebiet; andere Klassenquests nicht
    local spellCache = {}
    local function ClassSpell(id)
        if spellCache[id] ~= nil then return spellCache[id] end
        local cid, n, sp = id, 0, false
        while cid and cid > 0 and n < 8 do
            if R.sp and R.sp[cid] then sp = true break end
            cid, n = (Q.q[cid] or {})[12], n + 1
        end
        spellCache[id] = sp
        return sp
    end

    -- Naechster Halt einer Quest: annehmen (Geber im Heimatgebiet), Ziel, Abgabe; Gebiet des Halts
    local function GiverPt(q)
        if q.g == nil then q.g = Nearest(Q, q.e[6], nil, world, q.home) or Nearest(Q, q.e[6], nil, world) or false end
        return q.g or nil
    end
    -- Ziel-Punkt nahe ref (Stuetzpunkt/Geber), bevorzugt im Gebiet zone
    local function ObjPt(q, ref, zone)
        local nodes = Targets(q.id)
        if #nodes == 0 then return nil end
        local p, d = Nearest(Q, nodes, ref, world, zone)
        if p then return p, d end
        return Nearest(Q, nodes, ref, world)
    end
    local function EndPt(q, ref) return Nearest(Q, q.e[7], ref, world) end

    -- Gebiete der Ziele/Abgaben je Quest (aus den Daten, einmal gemerkt)
    local function ZoneSet(nodes)
        local set = {}
        for _, nr in ipairs(nodes or {}) do for _, p in ipairs(Points(Q, nr, world)) do set[p[4]] = p[1] end end
        return set
    end
    local function Stat(q)
        if not q.st then
            local e = q.e
            q.st = {obj = ZoneSet(e[8]), en = ZoneSet(e[7]), hasObj = #(e[8] or {}) > 0}
        end
        return q.st
    end
    -- Abgabe/Ziel im Gebiet z (eine Stadt zaehlt zum Heimatgebiet der Quest)
    -- Kontinent eines Gebiets (Mitte der Karte)
    local zc = {}
    local function ZoneCont(z)
        if zc[z] == nil then zc[z] = (world(z, .5, .5)) or false end
        return zc[z]
    end
    local function In(set, z, home)
        if set[z] then return true end
        -- Stadt auf demselben Kontinent (Botengang Dunkelkueste -> Sturmwind gehoert nicht dazu)
        if home == z then for m, c in pairs(set) do if H.CITY[m] and c == ZoneCont(z) then return true end end end
        return false
    end
    -- Arbeit im Gebiet z mit Stufe lv + ahead: Quests, die man dort jetzt machen kann
    --  * im Log, fertig: Abgabe im Gebiet
    --  * im Log, offen: Queststufe passt, nicht grau, Ziel im Gebiet (ohne Ziele: Abgabe im Gebiet)
    --  * nicht im Log: Heimatgebiet z, Mindeststufe erreicht, Vorquests erledigt, Queststufe passt
    local function Work(z, lv, ahead)
        local list = {}
        for _, q in ipairs(Q2) do
            local e = q.e
            if (later[q.id] or 0) >= 2 or q.class or q.dungeon then
                -- zweimal "Spaeter": raus; Klassenquests sind Abstecher (s. u.) und zaehlen nicht fuers Gebiet;
                -- Dungeon-Quests gehoeren nicht in die Fuehrung
            elseif q.log then
                local st = Stat(q)
                if q.complete then
                    -- fertig: abgeben (Botengang ohne Ziele erst, wenn die Stufe passt)
                    if In(st.en, z, q.home) and (st.hasObj or e[1] <= lv + ahead) then list[#list + 1] = q end
                elseif e[1] <= lv + ahead and e[1] > grey then
                    if st.hasObj then
                        if In(st.obj, z, q.home) then list[#list + 1] = q end
                    elseif In(st.en, z, q.home) then list[#list + 1] = q end
                end
            elseif q.home == z and q.pre and (e[2] or 0) <= lv and e[1] <= lv + ahead then
                -- Ziele (oder ohne Ziele: Abgabe) im Gebiet – sonst wartet sie nach dem Annehmen nur
                local st = Stat(q)
                if (st.hasObj and In(st.obj, z, q.home)) or (not st.hasObj and In(st.en, z, q.home)) then list[#list + 1] = q end
            end
        end
        return list
    end

    -- ===== 1) Gebiet =====
    local function Need(qlvl, ahead)
        -- EP bis Stufe qlvl - ahead (0 = schon da)
        local target = qlvl - ahead
        if target <= L or (me.xpMax or 0) <= 0 then return 0 end
        return P.XPTo(L, me.xp or 0, me.xpMax, 0, target)
    end
    local grindMax = math.min(H.GRIND_XP, (me.xpMax or 0) * H.GRIND_SHARE)
    -- EP, bis die Quest passt (im Log offen: Queststufe; neu: auch Mindeststufe), nil = kommt nicht in Frage
    local function GrindNeed(q, a)
        if q.class or (later[q.id] or 0) >= 2 then return nil end
        if q.log then
            if q.complete then return nil end
            return Need(q.e[1], a)
        end
        if not q.pre then return nil end
        return math.max(Need(q.e[1], a), Need((q.e[2] or 0) + a, a))
    end
    local zone, ahead, lvUse, grindTo
    local cur = state.zone
    if not cur then
        -- Anfang: das Gebiet, in dem man steht (wenn es in der Folge vorkommt), sonst das erste der Folge
        if here and inOrder[here[4]] then cur = here[4] end
    end
    -- im angefangenen Gebiet bleiben, solange dort etwas passt (auch nur eine Quest)
    if cur and inOrder[cur] and #Work(cur, L, H.AHEAD) > 0 then zone, ahead = cur, H.AHEAD end
    for a = H.AHEAD, H.AHEAD_MAX do
        if zone then break end
        if a > H.AHEAD and cur and inOrder[cur] and #Work(cur, L, a) > 0 then zone, ahead = cur, a break end
        -- sonst das erste Gebiet der Folge mit mindestens H.ZONE_MIN passenden Quests (schon verlassen: H.REVISIT_MIN)
        -- (das Gebiet, aus dem man gerade hierher kam, nur wenn sonst nichts passt: kein A -> B -> A -> B)
        local left = state.left or {}
        for pass = 1, 2 do
            for _, z in ipairs(order) do
                if z ~= cur and (pass == 2 or z ~= state.from) and #Work(z, L, a) >= (left[z] and H.REVISIT_MIN or H.ZONE_MIN) then
                    zone, ahead = z, a
                    break
                end
            end
            if zone then break end
        end
        if zone then break end
        -- nirgends etwas: kurz Monster hauen, wenn ein paar tausend EP reichen
        if a == H.AHEAD and grindMax > 0 then
            local best, bz
            for _, zz in ipairs(cur and inOrder[cur] and {cur} or {}) do
                for _, q in ipairs(Q2) do
                    local n = q.home == zz and GrindNeed(q, a)
                    if n and n > 0 and n <= grindMax and (not best or n < best) then best, bz = n, zz end
                end
            end
            if not best then
                for _, zz in ipairs(order) do
                    for _, q in ipairs(Q2) do
                        local n = q.home == zz and GrindNeed(q, a)
                        if n and n > 0 and n <= grindMax and (not best or n < best) then best, bz = n, zz end
                    end
                    if best then break end
                end
            end
            if best then
                -- Stufe, ab der dort wieder etwas geht
                -- (nur so weit, wie das Hauen kurz bleibt)
                local lv = L + 1
                local need = bz == cur and 1 or H.ZONE_MIN
                while #Work(bz, lv, a) < need and P.XPTo(L, me.xp or 0, me.xpMax, 0, lv + 1) <= grindMax do lv = lv + 1 end
                if #Work(bz, lv, a) >= need and P.XPTo(L, me.xp or 0, me.xpMax, 0, lv) <= grindMax then
                    zone, ahead, lvUse, grindTo = bz, a, lv, lv
                    break
                end
            end
        end
    end
    if not zone then
        -- letzter Ausweg (Stufenluecke, z. B. Allianz um 50): das Gebiet der Folge mit den meisten passenden Quests
        -- bis H.AHEAD_MAX (gleich viele: das fruehere) – nicht irgendeins fuer eine einzelne Quest
        local bestN = 0
        for _, z in ipairs(order) do
            local n = #Work(z, L, H.AHEAD_MAX)
            if n > bestN then zone, ahead, bestN = z, H.AHEAD_MAX, n end
        end
    end
    lvUse = lvUse or L
    local res = {zone = zone, ahead = ahead or H.AHEAD, follow = {}, loops = {}, gates = {}, waiting = {}, keys = {}, level = L}
    if not zone then
        state.zone = cur
        res.zone = cur
        return res
    end
    if zone ~= state.zone then
        if state.zone then
            state.left = state.left or {}
            state.left[state.zone] = L
        end
        state.from = state.zone
        state.zone, state.hub, state.round = zone, nil, (state.round or 0) + 1
        state.zones = state.zones or {}
    end
    local work = Work(zone, lvUse, ahead)
    res.work, res.workList = #work, work

    -- ===== 2) Stuetzpunkt =====
    -- Geber aller Quests mit Heimat in diesem Gebiet (auch erledigte nicht noetig: nur fuer die Anzeige/Schluessel)
    local givers = {}
    for _, q in ipairs(Q2) do
        if q.home == zone and not q.log and not q.class then
            local g = GiverPt(q)
            if g then givers[#givers + 1] = {q = q, w = g} end
        end
    end
    -- Ketten-Gruppen (H.HUB_R): Stuetzpunkt-Schluessel = kleinste Quest-ID der Gruppe ist nicht stabil – deshalb
    -- Schluessel = gerundete Mitte des Gebers mit der kleinsten Entfernung zur Gruppen-Mitte
    local groups, gi = {}, {}
    for i, g in ipairs(givers) do
        if not gi[i] then
            local grp = {members = {}}
            local stack = {i}
            gi[i] = grp
            while #stack > 0 do
                local k = table.remove(stack)
                grp.members[#grp.members + 1] = givers[k]
                for j, h in ipairs(givers) do
                    if not gi[j] and D(givers[k].w, h.w) <= H.HUB_R then gi[j] = grp stack[#stack + 1] = j end
                end
            end
            groups[#groups + 1] = grp
        end
    end
    local workSet = {}
    for _, q in ipairs(work) do workSet[q.id] = true end
    for _, grp in ipairs(groups) do
        local sx, sy, n = 0, 0, 0
        for _, m in ipairs(grp.members) do sx, sy, n = sx + m.w[2], sy + m.w[3], n + 1 end
        grp.c = {grp.members[1].w[1], sx / n, sy / n, grp.members[1].w[4]}
        grp.city = H.CITY[grp.members[1].w[4]] and true or false
        grp.key = ("%d:%d:%d"):format(grp.c[1], math.floor(grp.c[2] / 50 + .5), math.floor(grp.c[3] / 50 + .5))
        grp.doable = 0
        for _, m in ipairs(grp.members) do if workSet[m.q.id] then grp.doable = grp.doable + 1 end end
    end
    local function FindGroup(key)
        if not key then return nil end
        for _, grp in ipairs(groups) do if grp.key == key then return grp end end
        -- Schluessel leicht verschoben (Geber erledigt): Gruppe nahe der gemerkten Mitte
        if state.anchor then
            for _, grp in ipairs(groups) do if D(grp.c, state.anchor) <= H.HUB_R then return grp end end
        end
    end
    local logWork = 0
    for _, q in ipairs(work) do if q.log then logWork = logWork + 1 end end
    local hub = FindGroup(state.hub)
    if hub and hub.doable == 0 and logWork == 0 then hub = nil end
    if not hub then
        -- naechster Stuetzpunkt mit Machbarem; gemessen vom letzten Stuetzpunkt (Abstecher zaehlen nicht), Staedte zuletzt
        local ref = state.anchor
        if not (ref and here and ref[1] == here[1]) and not ref then ref = here end
        if here and here[4] == zone then ref = here end
        local best, bd
        for _, grp in ipairs(groups) do
            if grp.doable > 0 then
                local d = D(ref, grp.c) + (grp.city and H.FAR * 2 or 0)
                if not bd or d < bd then best, bd = grp, d end
            end
        end
        if best and logWork == 0 then
            hub = best
            if state.hub ~= best.key then state.round = (state.round or 0) + 1 end
        elseif best and not hub then
            hub = best
        end
    end
    if hub then
        state.hub, state.anchor = hub.key, {hub.c[1], hub.c[2], hub.c[3]}
        res.hub, res.hubCenter = hub.key, hub.c
        -- Ort fuer die Anzeige (Karte, x, y des Gebers nahe der Mitte)
        local bm, bd
        for _, m in ipairs(hub.members) do
            local d = D(m.w, hub.c)
            if not bd or d < bd then bm, bd = m, d end
        end
        if bm then res.hubAt = {bm.w[4], bm.w[5], bm.w[6]} end
    end

    -- ===== 3) Runde: Halte sammeln =====
    local stops, sel, keyOf = {}, {}, {}
    local center = hub and hub.c or (here and here[4] == zone and here) or state.anchor or here
    local function Add(key, kind, w, pre, id)
        if not w or keyOf[key] then return end
        local s = {key = key, kind = kind, w = w, pre = pre or {}, id = id}
        stops[#stops + 1] = s
        keyOf[key] = s
        return s
    end
    -- Quest einplanen: Annehmen (wenn noetig), Ziel (wenn machbar), Abgabe. doIt = Ziel/Abgabe in dieser Runde.
    local function Plan(q, doIt, preKeys, free)
        if sel[q.id] then return end
        sel[q.id] = true
        local e = q.e
        local aKey = "accept:" .. q.id
        local ref = center
        -- Abstecher (Klassenquest): nur auf dem Kontinent der Runde, nie Schiff/Zeppelin mitten in der Runde
        local function Far(w) return free and center and w and w[1] ~= center[1] end
        if not q.log then
            local g = GiverPt(q)
            if not g or Far(g) then return end
            Add(aKey, "accept", g, preKeys, q.id)
            ref = g
        end
        if not doIt then return end
        local last = not q.log and aKey or nil
        if not q.complete and #((Q.q[q.id] or {})[8] or {}) > 0 then
            local o = ObjPt(q, ref, zone)
            -- Ziel ausserhalb des Gebiets: nur knapp ueber der Grenze (nah an einem Halt im Gebiet)
            -- (Stadt auf dem Kontinent des Gebiets wie in Work/In – nicht des letzten Stuetzpunkts: der kann nach einem
            -- Gebietswechsel auf einem anderen Kontinent liegen, dann wartete die Quest ewig und die Fuehrung stand still)
            if o and o[4] ~= zone and not (H.CITY[o[4]] and o[1] == ZoneCont(zone)) and not free then
                local ok = false
                for _, s in ipairs(stops) do if s.w[4] == zone and D(s.w, o) <= H.OUT_NEAR then ok = true break end end
                if not ok and center and D(center, o) <= H.OUT_NEAR then ok = true end
                if not ok then res.waiting[q.id] = "zone" return end
            end
            if Far(o) then res.waiting[q.id] = "class" return end
            if o then
                Add("obj:" .. q.id, "obj", o, last and {last} or {}, q.id)
                last = "obj:" .. q.id
                ref = o
            end
        end
        local en = EndPt(q, ref)
        if Far(en) then res.waiting[q.id] = "class" return end
        local cityOK = en and H.CITY[en[4]] and en[1] == ZoneCont(zone)
        if en and (free or en[4] == zone or cityOK or D(en, ref) <= H.OUT_NEAR or Nearest(Q, e[7], nil, world, zone)) then
            local enz = Nearest(Q, e[7], ref, world, zone)
            if enz and D(enz, ref) < D(en, ref) + 300 then en = enz end
            Add("turnin:" .. q.id, "turnin", en, last and {last} or {}, q.id)
        elseif en then
            res.waiting[q.id] = "turnin"
        end
    end
    -- a) machbare Quests im Log (dieses Gebiet)
    local base = {}
    for _, q in ipairs(work) do if q.log then base[#base + 1] = q end end
    -- b) am Stuetzpunkt: alles annehmen; machbare gleich erledigen
    local atHub = {}
    if hub then
        for _, m in ipairs(hub.members) do
            local q = m.q
            -- nur Quests dieses Gebiets (Ziel bzw. Abgabe hier): mit Ziel ganz woanders wartet sie sonst ewig im Log
            local st = Stat(q)
            local here2 = (st.hasObj and In(st.obj, zone, q.home)) or (not st.hasObj and In(st.en, zone, q.home))
            if q.pre and (q.e[2] or 0) <= lvUse and here2 then atHub[#atHub + 1] = q end
        end
        table.sort(atHub, function(a, b) if a.e[1] ~= b.e[1] then return a.e[1] < b.e[1] end return a.id < b.id end)
    end
    for _, q in ipairs(base) do Plan(q, true) end
    local room = H.LOG_MAX - logCount
    local blocked = 0
    for _, q in ipairs(atHub) do
        local now = workSet[q.id] == true
        -- machbar: immer (solange Platz); hoeher: nur mit viel Platz und hoechstens H.ACCEPT_AHEAD drueber
        local okHigh = H.LOG_MAX - room < H.LOG_SOFT and q.e[1] <= lvUse + H.ACCEPT_AHEAD
        if room > 0 and (now or okHigh) then
            room = room - 1
            Plan(q, now)
        elseif now then blocked = blocked + 1 end
    end
    res.logFull = blocked > 0
    -- c) Ketten: Folgequest einer Quest der Runde, Geber nah an deren Abgabe, machbar
    local function Chains()
        local added = false
        for _, q in ipairs(Q2) do
            if not q.log and not sel[q.id] and q.home == zone and not q.pre and room > 0
                and (q.e[2] or 0) <= lvUse and q.e[1] <= lvUse + (ahead or H.AHEAD) then
                local pre, ok = {}, true
                local e = q.e
                local function Need1(p)
                    if done(p) then return true end
                    local tk = keyOf["turnin:" .. p]
                    if tk then pre[#pre + 1] = tk.key return true end
                    return false
                end
                if type(e[9]) == "table" then for _, p in ipairs(e[9]) do if not Need1(p) then ok = false end end end
                if ok and type(e[5]) == "table" and #e[5] > 0 then
                    local any = false
                    for _, p in ipairs(e[5]) do if Need1(p) then any = true break end end
                    ok = any
                end
                if ok and #pre > 0 then
                    local g = GiverPt(q)
                    local near = false
                    for _, k in ipairs(pre) do if g and D(keyOf[k].w, g) <= H.AREA_NEAR then near = true end end
                    if near then
                        room = room - 1
                        Plan(q, true, pre)
                        added = true
                    end
                end
            end
        end
        return added
    end
    for _ = 1, 4 do if not Chains() then break end end
    -- Klassenquests mit Zauber: Abstecher in die Runde (im Log: wenn die Stufe passt; neu: Mindest- und Queststufe)
    for _, q in ipairs(Q2) do
        if q.class and not sel[q.id] and ClassSpell(q.id) and (later[q.id] or 0) < 2 then
            local ok = q.e[1] <= lvUse + (ahead or H.AHEAD) or (q.log and q.complete and Stat(q).hasObj)
            if ok and (q.log or (q.pre and (q.e[2] or 0) <= lvUse and room > 0)) then
                if not q.log then room = room - 1 end
                Plan(q, true, nil, true)
                res.classIn = (res.classIn or 0) + 1
            end
        end
    end
    -- d) am Weg: Geber nah am Weg, Ziel und Abgabe nah an Zielen/Abgaben der Runde (Nutzer 26.11.2026)
    local start = here or center
    local path = H.Order2(stops, start)
    local function NearPath(w)
        local prev = start
        for _, s in ipairs(path) do
            local a, b = prev, s.w
            if a and b and a[1] == w[1] and b[1] == w[1] then
                local vx, vy = b[2] - a[2], b[3] - a[3]
                local l2 = vx * vx + vy * vy
                local t = l2 > 0 and math.max(0, math.min(1, ((w[2] - a[2]) * vx + (w[3] - a[3]) * vy) / l2)) or 0
                local px, py = a[2] + t * vx, a[3] + t * vy
                if math.sqrt((w[2] - px) ^ 2 + (w[3] - py) ^ 2) <= H.WAY_NEAR then return true end
            end
            prev = b
        end
        return false
    end
    local function NearStops(w, kinds)
        for _, s in ipairs(stops) do if kinds[s.kind] and D(s.w, w) <= H.AREA_NEAR then return true end end
        return false
    end
    local addedWay = false
    for _, q in ipairs(work) do
        if not q.log and not sel[q.id] and room > 0 then
            local g = GiverPt(q)
            if g and NearPath(g) then
                local o = #Targets(q.id) > 0 and ObjPt(q, g, zone) or nil
                local en = EndPt(q, o or g)
                local okO = not o or NearStops(o, {obj = true})
                local okE = en and (NearStops(en, {turnin = true, accept = true}) or D(en, g) <= H.WAY_NEAR)
                if okO and okE then
                    room = room - 1
                    Plan(q, true)
                    addedWay = true
                end
            end
        end
    end
    -- e) unbekannte Flugpunkte nah an einem Halt
    for _, f in ipairs(ctx.fpSpots or {}) do
        local w = {f[1], f[2], f[3]}
        for _, s in ipairs(stops) do
            if D(s.w, w) <= H.FP_NEAR then
                Add("fp:" .. tostring(f.id), "fp", {w[1], w[2], w[3], s.w[4]}, {}, nil)
                break
            end
        end
    end
    -- Stufe im Lauf: Quests, die erst mit den EP dieser Runde passen, kommen ans Ende (zweite Runde)
    if addedWay or #stops > 0 then path = H.Order2(stops, start) end
    -- Elite "Spaeter" (1): Ziel und Abgabe ans Ende
    local tail = {}
    for i = #path, 1, -1 do
        local s = path[i]
        if s.id and (later[s.id] or 0) == 1 and s.kind ~= "accept" then table.insert(tail, 1, table.remove(path, i)) end
    end
    for _, s in ipairs(tail) do path[#path + 1] = s end
    for i, s in ipairs(path) do
        res.follow[s.key] = i
        res.loops[s.key] = state.round or 1
        res.keys[#res.keys + 1] = s.key
    end
    res.path = path
    -- Hauen vor dem ersten Schritt (nur ein paar tausend EP)
    -- (an jedem Schritt: der Planer haut einmal, vor dem ersten, der noch da ist)
    if grindTo and path[1] then
        for _, st0 in ipairs(path) do res.gates[st0.key] = grindTo end
        res.grindTo = grindTo
    end
    -- Quests im Log, die warten (zu hoch, anderes Gebiet): kein "Nicht im Plan"
    for _, q in ipairs(Q2) do
        if q.log and not (res.follow["obj:" .. q.id] or res.follow["turnin:" .. q.id]) then
            if not res.waiting[q.id] then
                local st = Stat(q)
                if q.dungeon then res.waiting[q.id] = "dungeon"
                elseif q.class then res.waiting[q.id] = "class"
                elseif q.e[1] <= grey and not q.complete then
                    -- grau: kein Warten (der Kasten bietet "Nicht im Plan" zum Abbrechen an)
                elseif q.e[1] > lvUse + (ahead or H.AHEAD) and not q.complete then res.waiting[q.id] = "high"
                -- Grund wie in Work: wo liegt das, was als Naechstes ansteht (Ziel bzw. Abgabe)?
                elseif (q.complete or not st.hasObj) and not In(st.en, zone, q.home) then res.waiting[q.id] = "turnin"
                elseif st.hasObj and not q.complete and not In(st.obj, zone, q.home) then res.waiting[q.id] = "zone"
                else res.waiting[q.id] = "later" end
            end
        end
    end
    -- Name des Stuetzpunkts: Flugpunkt/Gastwirt in der Naehe, sonst Gebiet
    if hub then
        local bestN, bd
        for _, f in ipairs(lev.FLIGHTMASTERS or {}) do
            local d = D({f[2], f[3], f[4]}, hub.c)
            if d <= 400 and (not bd or d < bd) then bestN, bd = f[6], d end
        end
        if bestN then res.hubName = (tostring(bestN):match("^([^,]+)")) end
    end
    res.round = state.round or 1
    return res
end

