-- Gebiets-Schleife (Neubau 24.11.2026, Nutzer: "wir nehmen nur noch die quests in den gebieten an, bauen daraus eine
-- zuverlaessige schleife, dungeon pre-quests mit rein, elite mit rein mit der option sie nach hinten zu verschieben,
-- falls sich keine gruppe findet, am besten gar keine leerlaeufe und auch keine einzelnen quests in einem gebiet").
-- Kein Speed-Leveling, keine EP/min-Auswahl der Quests: je Gebiet (Hauptstaedte zaehlen als eigenes Gebiet) ALLE
-- passenden Quests (Volk, Klasse, Fraktion, Questsstufe hoechstens AHEAD ueber der eigenen; auch Elite), Runde fuer
-- Runde:
--   1. alles annehmen, was im Gebiet jetzt geht (Folgequests und neu frei gewordene Stufen: naechste Runde)
--   2. Ziele und Abgaben in einer Schleife (billigstes Einfuegen mit Reihenfolge annehmen < Ziel < abgeben, danach
--      einzelne Halte umsetzen), Ziele/Abgaben in anderen Gebieten bleiben im Log, bis die Route ohnehin dort ist
--      (Nutzer 24.11.2026: "wird sie angenommen und liegen gelassen, bis man sowieso in das gebiet muss")
--   3. kein Bereich fuer eine einzelne Quest: ein Halt weiter als ISO_YD von allen Halten anderer Quests faellt aus
--      der Runde (neue Quest: nicht annehmen; Quest im Log: bleibt liegen)
--   4. naechstes Gebiet: das aktuelle, solange es eine Runde mit MIN_ROUND Quests hergibt, sonst das Gebiet mit der
--      besten Runde (EP je Minute inkl. Anreise) – nur zur Wahl der Gebietsfolge, nie zum Weglassen von Quests
--   5. Dungeon-Quests nur, wenn ihr Geber in der Runde liegt; Dungeon-Lauf als Schritt, wenn die Stufe passt
-- Quests, die bis zum Ende nicht abgegeben werden (Gebiet nie wieder besucht, Dungeon zu spaet), kommen beim
-- naechsten Durchgang gar nicht erst in die Route (bis nichts mehr offen bleibt).
-- Aufruf: lua5.1 scripts/build_loop.lua <spf> "<Fraktion,Volk,KLASSE,Karte,x,y,HeimKarte,hx,hy>" <aus.lua> [-v]
local spf = assert(arg[1], "Aufruf: lua5.1 scripts/build_loop.lua <spf> <Lage> <aus.lua> [-v]")
local scen = assert(arg[2], "Lage fehlt")
local outFile = assert(arg[3], "Ausgabedatei fehlt")
local verbose = false
for i = 4, #arg do if arg[i] == "-v" then verbose = true end end
local root = "src"
GetLocale = function() return "deDE" end
for _, f in ipairs({"ONE_QuestDB/Data", "ONE_QuestDB/Timed", "ONE_QuestDB/Names_deDE", "ONE_Leveling/Rewards"}) do
    assert(loadfile(root .. "/" .. f .. ".lua"))()
end
local lev = {}
for _, f in ipairs({"Planner", "FlightMasters", "Inns"}) do assert(loadfile(root .. "/ONE_Leveling/" .. f .. ".lua"))("ONE_Leveling", lev) end
local P, Q, R = lev.Planner, GuildTripQuestDB, GuildTripLeveling
local DG = {}
assert(loadfile(root .. "/ONE_Dungeons/Catalog.lua"))("ONE_Dungeons", DG)
assert(loadfile(root .. "/ONE_Dungeons/EntranceData.lua"))("ONE_Dungeons", DG)
local CAT = {}
for _, c in ipairs(DG.Catalog or {}) do CAT[c.key] = c end
local spfns = {}
assert(loadfile(spf .. "/Data/Zones.lua"))("ShortestPathForever", spfns)
local Z = spfns.Zones
local navns = {}
assert(pcall(function() assert(loadfile(root .. "/ONE_Nav/Travel.lua"))("ONE_Nav", navns) end), "Travel.lua laden")
local DZ = R.dz or {}
local TIMED = Q.timed or {}

-- ===== Regeln (Zahlen) =====
local AHEAD = 2          -- Queststufe hoechstens so viel ueber der eigenen (mit dem Nutzer besprochen: "~2")
local AHEAD_GAP = 3      -- nur wenn sonst gehauen wuerde (Stufenluecke, z. B. Allianz 47-50): bis 3 drueber
local GREY = 5           -- Quests so viele Stufen unter der eigenen nicht mehr annehmen (Nutzer 24.11.2026: "bau die untergrenze ein, wenn die quests dann noch bis level 60 reichen" – bis 5 darunter volle EP, Orc-Magier fuhr mit 16 fuer Stufe-8-Quests nach Tirisfal)
local GREY_GAP = 8       -- nur in Stufenluecken (sonst Hauen): auch so alte Quests (vorher 10; Bau-Vergleich 24.11.: mit 8 weniger Hauen als mit 10 und als vorher)
local MIN_ROUND = 3      -- eine Runde (Besuch eines Gebiets) erst ab so vielen Quests
local ISO_YD = 1100      -- Halt so weit (yd, ~1000 m) von allen Halten anderer Quests: Ausreisser, nicht in diese Runde
local OBJ_NEAR_YD = 1500 -- Ziel-Spawn so nah am Geber gehoert noch zur Runde, auch wenn er im Nachbargebiet liegt
local PART_YD = 900      -- Ziele einer Quest weiter auseinander: eigene Teil-Schritte ("o821.2")
local CARRY_MAX = 10     -- hoechstens so viele Quests im Log, die erst in einem anderen Gebiet weitergehen
local LOG_MAX = 32       -- Questlog (Forever 40, etwas Luft fuer Drops und Selbstangenommenes)
local DUN_MIN, DUN_FROM = 60, 2
-- Ohne Dungeon-Laeufe (Nutzer 24.11.2026: "nur die dungeon-vorquests rein, wenn sich daraus trotzdem noch genuegend ep
-- ansammeln um bis stufe 60 zu leveln, wenn nicht, dann die kompletten dungeons"). Nachstellung 8 Routen: ohne Laeufe
-- 0 Hau-Bloecke > 10 min, im Schnitt ~2 % laenger bis 60 -> Standard ohne. Vorquests ausserhalb bleiben drin, Quests,
-- die im Dungeon enden, fallen weg. DUNGEON=1 baut mit Laeufen (k="dungeon").
local NODUNGEON = os.getenv("DUNGEON") ~= "1"
local TIMED_SHARE = .5   -- strenger als die Pruefung (.7): dort zaehlen Ziele anders
local FP_NEAR_YD = 450   -- unbekannter Flugpunkt so nah an einem Halt der Runde: mitnehmen
local SPEED = 7
local CLUSTER_YD = 300
local MOB_SHARE = .8     -- Gegner-EP beim Questen vorsichtig rechnen (Nachstellung im Spiel lag ~0,4 Stufen dahinter)
local OVER_XP = 2.5      -- ueber 60 hinaus weiterbauen (so viele Stufen-EP der 59), damit im Spiel am Ende nichts fehlt
local CARRY_LVL = 5      -- Quest liegt laenger (Stufen zwischen Annehmen und Abgeben) im Log: beim naechsten Durchgang weglassen

-- ===== Lage =====
local f = {}
for x in scen:gmatch("[^,]+") do f[#f + 1] = x end
local CLASS = {WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024}
local RACE = {Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Undead = 16, Tauren = 32, Gnome = 64, Troll = 128}
local FAC, RMASK, CMASK = f[1], RACE[f[2]], CLASS[f[3]]
local START = {tonumber(f[4]), tonumber(f[5]), tonumber(f[6])}
local HOME = {tonumber(f[7]), tonumber(f[8]), tonumber(f[9])}
local facN = FAC == "Alliance" and 1 or 2
local function Mine(m) return m % (facN * 2) >= facN end

local function World(m, x, y)
    local z = Z[m]
    if not z then return nil end
    return {z.map, z.maxX - y * (z.maxX - z.minX), z.maxY - x * (z.maxY - z.minY), m}
end
local function Dist(a, b) return math.sqrt((a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2) end
local function D(a, b) if a[1] ~= b[1] then return 1e6 end return Dist(a, b) end
local function Walk(a, b) if a[1] ~= b[1] then return P.FAR_MIN * 2 end return Dist(a, b) * P.DETOUR / SPEED / 60 end
local function ZName(m) local n = Z[m] and Z[m].name return n or tostring(m) end
local function Name(id) local n = Q.names and Q.names[id] return type(n) == "table" and n[1] or n or ("q" .. id) end

-- Punkte eines Knotens (NPC/Objekt/Ziel): {{c, wx, wy, map}, ...}
local ncache = {}
local function Pts(nr)
    local p = ncache[nr]
    if p then return p end
    p = {}
    local n = Q.n[nr or 0]
    if n then
        for i = 2, #n, 3 do
            local w = World(n[i], n[i + 1] / 1000, n[i + 2] / 1000)
            if w then p[#p + 1] = w end
        end
    end
    ncache[nr] = p
    return p
end
-- naechster Punkt aus Knotenliste zu ref (optional nur Karte map)
local function NearestOf(list, ref, map)
    local best, bd, bnr
    for _, nr in ipairs(list or {}) do
        for _, w in ipairs(Pts(nr)) do
            if (not map or w[4] == map) and (not ref or w[1] == ref[1]) then
                local d = ref and Dist(w, ref) or 0
                if not bd or d < bd then best, bd, bnr = w, d, nr end
            end
        end
    end
    return best, bnr, bd
end

-- ===== Quests: feste Daten je Quest (passt zu Volk/Klasse/Fraktion, Art, Aufwand, Ziel-Teile) =====
local me60 = {level = 60, race = RMASK, class = CMASK, faction = FAC}
local never = function() return false end
local static = {}
for id, e in pairs(Q.q) do
    local rew = P.Rew(R, id)
    local kind = rew and rew[3] or 0
    local raidPvp = math.floor(kind / 4) % 2 == 1 or math.floor(kind / 8) % 2 == 1
    -- Mindeststufe (Fits prueft Hoechststufe e[13] gegen die Stufe – mit 60 fiele alles mit Hoechststufe weg)
    local me = {level = 1, race = RMASK, class = CMASK, faction = FAC}
    if (e[1] or 0) > 0 and not raidPvp and not P.IsDrop(e) and type(e[6]) == "table" and #e[6] > 0
        and type(e[7]) == "table" and #e[7] > 0 and P.Fits(id, e, me, never, never) then
        local givers = {}
        for _, nr in ipairs(e[6]) do for _, w in ipairs(Pts(nr)) do givers[#givers + 1] = {w = w, nr = nr} end end
        local enders = {}
        for _, nr in ipairs(e[7]) do for _, w in ipairs(Pts(nr)) do enders[#enders + 1] = {w = w, nr = nr} end end
        if #givers > 0 and #enders > 0 then
            static[id] = {id = id, e = e, kind = kind, work = rew and rew[2] or 0, dungeon = DZ[e[14] or 0],
                givers = givers, enders = enders, elite = kind % 2 == 1 or math.floor(kind / 16) % 2 == 1}
        end
    end
end

-- Quests je Geber-Knoten (Folgequests am selben NPC gleich mitnehmen)
local byGiver = {}
for id, st in pairs(static) do
    for _, nr in ipairs(st.e[6]) do byGiver[nr] = byGiver[nr] or {} table.insert(byGiver[nr], id) end
end
for _, list in pairs(byGiver) do table.sort(list) end
-- Geber nach Ort (Raster 200 yd): neu annehmbare Quests direkt am Weg finden
local GRID = 200
local giverGrid = {}
for id, st in pairs(static) do
    for _, g in ipairs(st.givers) do
        local key = g.w[1] .. ":" .. math.floor(g.w[2] / GRID) .. ":" .. math.floor(g.w[3] / GRID)
        giverGrid[key] = giverGrid[key] or {}
        table.insert(giverGrid[key], {id = id, w = g.w, nr = g.nr})
    end
end
local function GiversNear(w, yd)
    local out = {}
    local cx, cy = math.floor(w[2] / GRID), math.floor(w[3] / GRID)
    for dx = -1, 1 do for dy = -1, 1 do
        for _, g in ipairs(giverGrid[w[1] .. ":" .. (cx + dx) .. ":" .. (cy + dy)] or {}) do
            if Dist(g.w, w) <= yd then out[#out + 1] = g end
        end
    end end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end
local MID_YD = 80        -- neu annehmbare Quest mit Geber so nah am Halt: gleich mitnehmen
-- Sammelrunde (Stufenluecke, Nutzer 24.11.2026 "so wie du sagst"): einzelne Quests aus mehreren Gebieten per Flug
local SAMMEL_FP_YD = 1400  -- Geber (bzw. Abgabe) hoechstens so weit vom naechsten bekannten Flugpunkt
local SAMMEL_GAIN = .6     -- Quest-EP mindestens 60 % von Hauen in der Zeit, die ihr Weg kostet (Questen statt
                           -- langem Hauen darf etwas langsamer sein; Gegner-EP der Ziele zaehlen hier nicht mit)
local SAMMEL_MIN = 2       -- keine Sammelrunde fuer eine einzige Quest
-- ===== Bau =====
local XP_NEED = P.XP_NEED
local FitsHere
local function Build(banned, noMid, noCarry, pass)
    local L, xp, t = 1, 0, 0
    local pos = World(START[1], START[2], START[3])
    local done, log = {}, {}       -- log[id] = {parts = {offene Teile}, acceptL, objDone}
    local logN = 0
    local route, stats = {}, {late = {}, noMid = {}, noCarry = {}, quests = 0, rounds = 0, grind = 0, grindMin = 0, dungeons = 0, flights = 0}
    local known = {}
    for _, fm in ipairs(lev.FLIGHTMASTERS) do
        local z = Z[fm[7] or 0]
        if Mine(fm[5]) and z and (fm[7] == START[1] or z.city) then known[fm[1]] = true end
    end
    local departures = {}
    for _, d in ipairs(navns.Travel.departures) do
        if not d.faction or d.faction == FAC then
            local w = World(d.mapID, d.x, d.y)
            if w then departures[#departures + 1] = {w[1], w[2], w[3], from = d.from, to = d.to, name = d.name} end
        end
    end
    local home = World(HOME[1], HOME[2], HOME[3])
    local hearthAt = -999
    local lastZone
    local function Net()
        local fl = {}
        for _, fm in ipairs(lev.FLIGHTMASTERS) do if known[fm[1]] and Mine(fm[5]) then fl[#fl + 1] = {fm[2], fm[3], fm[4], name = fm[6]} end end
        return {speed = SPEED, flights = fl, departures = departures}
    end
    local net = Net()
    -- Reise mit Flug/Schiff/Ruhestein (Minuten)
    local function Trip(a, b)
        local m = P.Travel(a, b, net)
        if home and t - hearthAt >= P.HS_CD then
            local hm = P.HS_MIN + P.Travel(home, b, net)
            if hm < m - P.HS_SAVE then return hm, "hearth" end
        end
        return m
    end
    local over = 0
    local aheadNow, greyNow = AHEAD, GREY
    local function AddXP(n)
        if L >= 60 then over = over + n return end
        xp = xp + n
        while L < 60 and xp >= XP_NEED[L] do xp = xp - XP_NEED[L] L = L + 1 end
        if L >= 60 then over, xp = xp, 0 stats.t60 = stats.t60 or t end
    end
    local function Emit(r) r.l = r.l or L route[#route + 1] = r return r end
    local function PreOK(e)
        if type(e[9]) == "table" then for _, p in ipairs(e[9]) do if not done[p] then return false end end end
        if type(e[5]) == "table" and #e[5] > 0 then
            local ok = false
            for _, p in ipairs(e[5]) do if done[p] then ok = true end end
            if not ok then return false end
        end
        return true
    end
    local function Available(s)
        local e = s.e
        if done[s.id] or log[s.id] or banned[s.id] then return false end
        if (e[2] or 0) > L or e[1] > L + aheadNow or e[1] < L - greyNow then return false end
        if (e[13] or 0) > 0 and L > e[13] then return false end
        if type(e[10]) == "table" then for _, p in ipairs(e[10]) do if done[p] or log[p] then return false end end end
        if s.dungeon and NODUNGEON then return false end
        if s.dungeon then
            local c = CAT[s.dungeon]
            if not c or not DG.EntranceData[s.dungeon] or (c.faction and c.faction ~= FAC) or L > c.max - 3 then return false end
        end
        return PreOK(e)
    end
    -- Ziel-Teile einer Quest: Knotengruppen, deren Spawns (naechste zum Geber) weiter als PART_YD auseinanderliegen
    local function Parts(s, ref)
        local objs = s.e[8] or {}
        if s.dungeon or #objs == 0 then return {} end
        local parts = {}
        for _, nr in ipairs(objs) do
            local w = NearestOf({nr}, ref)
            if w then
                local hit
                for _, p in ipairs(parts) do if D(p.w, w) <= PART_YD then hit = p break end end
                if hit then hit.nodes[#hit.nodes + 1] = nr else parts[#parts + 1] = {w = w, nodes = {nr}, nr = nr} end
            end
        end
        return parts
    end
    -- Folgequest am selben NPC mitnehmen nur, wenn alle Ziele und die Abgabe in diesem Gebiet nah liegen (sonst
    -- verstopft sie das Log)
    function FitsHere(qs, gw, zm)
        for _, p in ipairs(Parts(qs, gw)) do
            local w = NearestOf(p.nodes, gw, zm)
            if not w or D(w, gw) > OBJ_NEAR_YD * 2 then return false end
        end
        local en = NearestOf(qs.e[7], gw, zm)
        return en ~= nil and D(en, gw) <= OBJ_NEAR_YD * 2
    end
    -- Runde in Gebiet zm vorbereiten: Halte {kind, id, w, nr, part}; ohne Ausreisser
    local function Round(zm, avail)
        local quests = {}
        local room = LOG_MAX - logN
        local carryN = logN
        -- neue Quests (Geber in zm), naechste zuerst
        local news = {}
        for _, s in ipairs(avail) do
            local g = nil
            for _, gv in ipairs(s.givers) do if gv.w[4] == zm and (not g or D(gv.w, pos) < D(g.w, pos)) then g = gv end end
            if g then news[#news + 1] = {s = s, g = g, d = D(g.w, pos)} end
        end
        table.sort(news, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.s.id < b.s.id end)
        for _, n in ipairs(news) do
            if room <= 0 then break end
            local s = n.s
            local q = {id = s.id, s = s, new = true, stops = {}}
            q.stops[1] = {kind = "a", id = s.id, w = n.g.w, nr = n.g.nr}
            local parts = Parts(s, n.g.w)
            local carry = false
            for k, p in ipairs(parts) do
                -- Ziel in der Runde: im Gebiet oder nah am Geber; sonst bleibt der Teil im Log liegen
                local w = NearestOf(p.nodes, n.g.w, zm) or p.w
                if w[4] == zm or D(w, n.g.w) <= OBJ_NEAR_YD then
                    q.stops[#q.stops + 1] = {kind = "o", id = s.id, w = w, nr = p.nr, part = #parts > 1 and k or nil, nodes = p.nodes}
                else carry = true end
            end
            q.parts = parts
            if not carry and not s.dungeon then
                local en = NearestOf(s.e[7], q.stops[#q.stops].w, zm)
                local ref = q.stops[#q.stops].w
                if not en then
                    -- Abgabe knapp hinter der Grenze (nie in einer Hauptstadt: sonst Stadtbesuch fuer eine Quest)
                    local w2 = NearestOf(s.e[7], ref)
                    if w2 and D(w2, ref) <= OBJ_NEAR_YD and not (Z[w2[4]] and Z[w2[4]].city) then en = w2 end
                end
                if en then
                    local _, enr = NearestOf(s.e[7], en)
                    q.stops[#q.stops + 1] = {kind = "t", id = s.id, w = en, nr = enr}
                else carry = true end
            end
            -- geht erst in einem anderen Gebiet weiter (oder im Dungeon): nur wenige davon im Log
            if s.dungeon then carry = true end
            q.carry = carry
            if not carry or (carryN < CARRY_MAX and not noCarry[s.id]) then
                if carry then carryN = carryN + 1 end
                quests[#quests + 1] = q
                room = room - 1
            end
        end
        -- Quests im Log: offene Teile / Abgabe in zm
        local logIDs = {}
        for id in pairs(log) do logIDs[#logIDs + 1] = id end
        table.sort(logIDs)
        for _, id in ipairs(logIDs) do
            local lg = log[id]
            local s = static[id]
            local q = {id = id, s = s, new = false, stops = {}}
            local openParts = 0
            for k, p in ipairs(lg.parts) do
                if not p.done then
                    openParts = openParts + 1
                    local w, nr = NearestOf(p.nodes, pos, zm)
                    if w then q.stops[#q.stops + 1] = {kind = "o", id = id, w = w, nr = nr, part = #lg.parts > 1 and k or nil, nodes = p.nodes} end
                end
            end
            local objsHere = #q.stops
            if (openParts == objsHere) and not (s.dungeon and not lg.dunDone) then
                local en, enr = NearestOf(s.e[7], pos, zm)
                if en then q.stops[#q.stops + 1] = {kind = "t", id = id, w = en, nr = enr} end
            end
            if #q.stops > 0 then quests[#quests + 1] = q end
        end
        -- Ausreisser raus (Regel "kein Bereich fuer eine einzelne Quest"), bis stabil
        local changed = true
        while changed do
            changed = false
            for qi = #quests, 1, -1 do
                local q = quests[qi]
                local iso = false
                for _, st in ipairs(q.stops) do
                    local near = D(st.w, pos) <= ISO_YD and pos[4] == zm
                    if not near then
                        for _, o in ipairs(quests) do
                            if o ~= q then
                                for _, os in ipairs(o.stops) do if D(os.w, st.w) <= ISO_YD then near = true break end end
                            end
                            if near then break end
                        end
                    end
                    if not near then iso = true break end
                end
                if iso then
                    if q.new then table.remove(quests, qi) changed = true
                    else
                        -- Quest im Log: nur die isolierten Halte liegen lassen
                        local keep = {}
                        for _, st in ipairs(q.stops) do
                            local near = false
                            for _, o in ipairs(quests) do
                                if o ~= q then for _, os in ipairs(o.stops) do if D(os.w, st.w) <= ISO_YD then near = true break end end end
                                if near then break end
                            end
                            if near then keep[#keep + 1] = st end
                        end
                        -- Abgabe nur, wenn alle offenen Ziele davor in der Runde sind
                        local objKept, objAll = 0, 0
                        for _, st in ipairs(q.stops) do if st.kind == "o" then objAll = objAll + 1 end end
                        for _, st in ipairs(keep) do if st.kind == "o" then objKept = objKept + 1 end end
                        if objKept < objAll then for i = #keep, 1, -1 do if keep[i].kind == "t" then table.remove(keep, i) end end end
                        q.stops = keep
                        if #keep == 0 then table.remove(quests, qi) end
                        changed = true
                    end
                end
            end
        end
        return quests
    end
    -- Schleife: billigstes Einfuegen (annehmen < Ziele < abgeben), dann Halte einzeln umsetzen
    local function Tour(quests, W)
        W = W or Walk
        local seq = {}
        local function Cost(i, x)   -- Mehrweg, wenn x nach seq[i] (i = 0: Start) eingefuegt wird
            local a = i == 0 and pos or seq[i].w
            local b = seq[i + 1] and seq[i + 1].w
            if b then return W(a, x.w) + W(x.w, b) - W(a, b) end
            return W(a, x.w)
        end
        for _, q in ipairs(quests) do
            local after = 0
            for _, st in ipairs(q.stops) do
                local bi, bc
                for i = after, #seq do
                    local c = Cost(i, st)
                    if not bc or c < bc - 1e-9 then bi, bc = i, c end
                end
                table.insert(seq, bi + 1, st)
                after = bi + 1
            end
        end
        -- Umsetzen: jeder Halt an die beste Stelle zwischen seinem Vorgaenger und Nachfolger derselben Quest
        for pass = 1, 6 do
            local better = false
            for i = 1, #seq do
                local st = seq[i]
                local lo, hi = 0, #seq + 1
                for j = 1, #seq do
                    local o = seq[j]
                    if o ~= st and o.id == st.id then
                        local ord = ({a = 1, o = 2, t = 3})
                        if ord[o.kind] < ord[st.kind] or (o.kind == "o" and st.kind == "o" and false) then lo = math.max(lo, j) end
                        if ord[o.kind] > ord[st.kind] then hi = math.min(hi, j) end
                    end
                end
                local prev = i == 1 and pos or seq[i - 1].w
                local nxt = seq[i + 1] and seq[i + 1].w
                local gain = W(prev, st.w) + (nxt and (W(st.w, nxt) - W(prev, nxt)) or 0)
                table.remove(seq, i)
                if lo >= i then lo = lo - 1 end
                if hi > i then hi = hi - 1 end
                local bi, bc = i - 1, Cost(i - 1, st)
                for k = lo, hi - 1 do
                    if k >= 0 and k <= #seq then
                        local c = Cost(k, st)
                        if c < bc - .01 then bi, bc = k, c end
                    end
                end
                table.insert(seq, bi + 1, st)
                if bc < gain - .01 then better = true end
            end
            if not better then break end
        end
        return seq
    end
    -- Zeitquests: Annehmen -> Abgeben hoechstens TIMED_SHARE des Limits; sonst als Block an die billigste Stelle
    local function FixTimed(seq)
        local function Span(id)
            local ia, it
            for i, st in ipairs(seq) do if st.id == id then if st.kind == "a" then ia = i end if st.kind == "t" then it = i end end end
            if not (ia and it) then return 0 end
            local m = 0
            for i = ia + 1, it do
                m = m + Walk(seq[i - 1].w, seq[i].w)
                if seq[i].kind == "o" then m = m + math.max(2, (static[seq[i].id].work or 0) * P.KILL_SEC / 60) end
            end
            return m
        end
        local drop = {}
        local tids = {}
        for id in pairs(TIMED) do tids[#tids + 1] = id end
        table.sort(tids)
        for _, id in ipairs(tids) do
            local has = false
            for _, st in ipairs(seq) do if st.id == id and st.kind == "a" then has = true end end
            if has and Span(id) > TIMED[id] / 60 * TIMED_SHARE then
                local block = {}
                for i = #seq, 1, -1 do if seq[i].id == id then table.insert(block, 1, table.remove(seq, i)) end end
                local bm = 0
                for i = 2, #block do bm = bm + Walk(block[i - 1].w, block[i].w) end
                for _, st in ipairs(block) do if st.kind == "o" then bm = bm + math.max(2, (static[id].work or 0) * P.KILL_SEC / 60) end end
                if bm > TIMED[id] / 60 * TIMED_SHARE or block[1].kind ~= "a" then drop[id] = true
                else
                    local bi, bc
                    for i = 0, #seq do
                        local a = i == 0 and pos or seq[i].w
                        local b = seq[i + 1] and seq[i + 1].w
                        local c = Walk(a, block[1].w) + (b and (Walk(block[#block].w, b) - Walk(a, b)) or 0)
                        if not bc or c < bc then bi, bc = i, c end
                    end
                    for k, st in ipairs(block) do table.insert(seq, bi + k, st) end
                end
            end
        end
        return drop
    end
    -- Kein langer Fussweg fuer eine einzelne Aktion (harte Pruefung EINZEL, wie scripts/check_route_areas.lua): Weg
    -- > EINZEL_YD (nach Flug) zu einem Halt, an dem (mit den direkt folgenden Halten < 300 yd) hoechstens eine
    -- Annahme/Abgabe und kein Ziel liegt -> Halt an eine Stelle ohne das umsetzen, sonst aus der Runde (neue Quest:
    -- nicht annehmen; Abgabe: bleibt im Log fuer spaeter)
    local EINZEL_YD = 1500
    local function FlightLeg(a, b)
        if a[1] ~= b[1] then return 0 end
        local d = Dist(a, b)
        local fa, da = nil, nil
        local fb, db = nil, nil
        for _, fl in ipairs(net.flights) do
            if fl[1] == a[1] then
                local x = Dist(fl, a) if not da or x < da then fa, da = fl, x end
                local y = Dist(fl, b) if not db or y < db then fb, db = fl, y end
            end
        end
        if fa and fb and fa ~= fb then
            local fly = (da + db) * P.DETOUR / SPEED / 60 + Dist(fa, fb) * P.FLY_DETOUR / P.FLY_SPEED / 60 + P.FLY_EXTRA
            if fly < d * P.DETOUR / SPEED / 60 * .8 then return math.max(da, db) end
        end
        return d
    end
    -- wie die Pruefung: mit Ruhestein (wenn bereit) und ohne – der laengere Fussweg-Teil zaehlt
    local function Leg(a, b)
        local l = FlightLeg(a, b)
        if home and home[1] == b[1] and a[1] == b[1] then
            local wm = Walk(a, b)
            local hm = P.HS_MIN + Walk(home, b)
            if hm <= wm - P.HS_SAVE then l = math.max(l, Dist(home, b)) end
        end
        return l
    end
    local function Single(seq, i)
        local n, obj = 0, false
        local j = i
        while seq[j] do
            if j > i and (D(seq[j].w, seq[i].w) > CLUSTER_YD) then break end
            n = n + 1
            if seq[j].kind == "o" then obj = true end
            j = j + 1
        end
        return n < 2 and not obj
    end
    local function Bad(seq, i)
        local prev = i == 1 and pos or seq[i - 1].w
        return Leg(prev, seq[i].w) > EINZEL_YD and Single(seq, i)
    end
    local function FixEinzel(seq)
        local dropped, moved = {}, {}
        for guard = 1, 200 do
            local bi
            for i = 1, #seq do if Bad(seq, i) then bi = i break end end
            if not bi then break end
            local st = table.remove(seq, bi)
            -- Fenster: nach Vorgaenger, vor Nachfolger derselben Quest
            local ord = {a = 1, o = 2, t = 3}
            local lo, hi = 0, #seq
            for j, o in ipairs(seq) do
                if o.id == st.id then
                    if ord[o.kind] < ord[st.kind] then lo = math.max(lo, j) end
                    if ord[o.kind] > ord[st.kind] and j - 1 < hi then hi = j - 1 end
                end
            end
            local best, bc
            if not TIMED[st.id] then
                for k = lo, hi do
                    table.insert(seq, k + 1, st)
                    local ok = not Bad(seq, k + 1) and not (seq[k + 2] and Bad(seq, k + 2))
                    if ok then
                        local a = k == 0 and pos or seq[k].w
                        local b = seq[k + 2] and seq[k + 2].w
                        local c = Walk(a, st.w) + (b and (Walk(st.w, b) - Walk(a, b)) or 0)
                        if not bc or c < bc then best, bc = k, c end
                    end
                    table.remove(seq, k + 1)
                end
            end
            if best and bc < 8 and not moved[st] then moved[st] = true table.insert(seq, best + 1, st)
            else
                -- raus: neue Quest ganz (alle Halte), sonst nur dieser Halt und was danach von ihr kommt
                local q = st.id
                if st.kind == "a" or not log[q] then
                    for j = #seq, 1, -1 do if seq[j].id == q then table.remove(seq, j) end end
                else
                    for j = #seq, 1, -1 do if seq[j].id == q and ord[seq[j].kind] > ord[st.kind] then table.remove(seq, j) end end
                end
                dropped[#dropped + 1] = q
            end
        end
        return dropped
    end
    -- Ziel-Spawn je Halt neu: der naechste zum Halt davor (wie Wegfuehrung und Pruefung), im Gebiet bevorzugt
    local function Refine(seq, zm)
        local prev = pos
        for _, st in ipairs(seq) do
            if st.kind == "o" and st.nodes then
                local w, nr = NearestOf(st.nodes, prev, zm)
                local w2, nr2 = NearestOf(st.nodes, prev)
                if w2 and (not w or D(w2, prev) < D(w, prev) * .5) and D(w2, st.w) <= OBJ_NEAR_YD then w, nr = w2, nr2 end
                if w then st.w, st.nr = w, nr end
            end
            prev = st.w
        end
    end
    -- unbekannte Flugpunkte nahe der Runde
    local function FPs(seq)
        local out = {}
        for _, fm in ipairs(lev.FLIGHTMASTERS) do
            if Mine(fm[5]) and not known[fm[1]] then
                local w = {fm[2], fm[3], fm[4], fm[7]}
                local bi, bd
                for i, st in ipairs(seq) do local d = D(st.w, w) if not bd or d < bd then bi, bd = i, d end end
                if bi and bd <= FP_NEAR_YD then out[#out + 1] = {i = bi, fm = fm, w = w} end
            end
        end
        return out
    end
    -- Runde ausfuehren: Schritte schreiben, Zeit/EP/Stufe nachrechnen
    local function Run(zm, quests, seq, availStart)
        stats.rounds = stats.rounds + 1
        local midSteps = {}
        local carryOf = {}
        for _, q in ipairs(quests) do if q.new then carryOf[q.id] = q.carry end end
        local fps = FPs(seq)
        local fpAt = {}   -- je Halt (Objekt, nicht Platz: mitgenommene Quests schieben Halte nach hinten)
        for _, x in ipairs(fps) do local k = seq[x.i] fpAt[k] = fpAt[k] or {} table.insert(fpAt[k], x) end
        -- mitgenommene Quest in den Rest dieser Runde einfuegen (billigste Stelle, Reihenfolge Ziele < Abgabe)
        local function InsertRest(i, stops)
            local after = i
            for _, x in ipairs(stops) do
                local bk, bc
                for k = after, #seq do
                    local a = seq[k].w
                    local b = seq[k + 1] and seq[k + 1].w
                    local c = Walk(a, x.w) + (b and (Walk(x.w, b) - Walk(a, b)) or 0)
                    if not bc or c < bc - 1e-9 then bk, bc = k, c end
                end
                table.insert(seq, bk + 1, x)
                after = bk + 1
            end
        end
        local first = true
        local cur
        local L0 = L
        -- Ruhestein setzen (Abkuerzung, Nutzer 24.11.2026): neues Gebiet, Gastwirt der eigenen Fraktion (nicht in
        -- einer Hauptstadt) nah an einem Halt der Runde
        local bindAt
        if zm ~= lastZone and not (Z[zm] and Z[zm].city) then
            local bd
            for _, inn in ipairs(lev.INNS) do
                if Mine(inn[5]) and not P.CITY_INNS[inn[1]] then
                    local w = {inn[2], inn[3], inn[4]}
                    for i, st in ipairs(seq) do
                        local d = D(st.w, w)
                        if st.w[4] == zm and d <= 400 and (not bd or d < bd) then bd, bindAt = d, {st = st, inn = inn, w = w} end
                    end
                end
            end
            if bindAt and home and D(home, bindAt.w) < 300 then bindAt = nil end
        end
        local i = 0
        while i < #seq do
            i = i + 1
            local st = seq[i]
            local m, how = Trip(pos, st.w)
            if how == "hearth" then hearthAt = t end
            if m > 3 and #net.flights > 0 then
                local _, via = P.Travel(pos, st.w, net)
                if via and via.kind == "flight" then stats.flights = stats.flights + 1 end
            end
            t = t + m
            pos = st.w
            local s = static[st.id]
            local tok
            if st.kind == "a" then
                t = t + .2
                local parts = {}
                for _, p in ipairs(Parts(s, st.w)) do parts[#parts + 1] = {nodes = p.nodes, done = false} end
                log[st.id] = {parts = parts, acceptL = L, carry = carryOf[st.id]}
                logN = logN + 1
                tok = "a" .. st.id
            elseif st.kind == "o" then
                local lg = log[st.id]
                local nparts = #lg.parts
                local share = nparts > 0 and 1 / nparts or 1
                local work = (s.work or 0) * share
                t = t + work * P.KILL_SEC / 60
                AddXP(work * P.MobXP(L, math.min(s.e[1], L + 2)) * MOB_SHARE)
                if st.part then lg.parts[st.part].done = true else for _, p in ipairs(lg.parts) do p.done = true end end
                tok = "o" .. st.id .. (st.part and ("." .. st.part) or "")
            else
                t = t + .2
                AddXP((P.QuestXP(s.e[11] or 0, s.e[1], L)))
                local lg = log[st.id]
                -- mitgenommene Folgequest nicht in der naechsten Runde erledigt: beim naechsten Durchgang nicht mitnehmen
                if lg.mid and stats.rounds > lg.mid + 1 then stats.noMid[#stats.noMid + 1] = st.id
                elseif L - lg.acceptL > CARRY_LVL then
                    if lg.carry and not s.dungeon then stats.noCarry[#stats.noCarry + 1] = st.id else stats.late[#stats.late + 1] = st.id end
                end
                done[st.id] = true
                log[st.id] = nil
                logN = logN - 1
                stats.quests = stats.quests + 1
                tok = "t" .. st.id
            end
            -- neu frei gewordene Quest (Folgequest, Stufe) mit Geber direkt hier: gleich mitnehmen und noch in dieser
            -- Runde erledigen, statt spaeter extra herzukommen
            if st.kind ~= "o" then
                local seenQ = {}
                for _, g in ipairs(GiversNear(st.w, MID_YD)) do
                    local qid = g.id
                    local qs = static[qid]
                    -- nur, was zu Rundenbeginn noch nicht ging (sonst hat die Runde sie bewusst ausgelassen)
                    if not seenQ[qid] and not availStart[qid] and g.w[4] == zm and logN < LOG_MAX and Available(qs) and not TIMED[qid]
                        and not qs.dungeon and not noMid[qid] and FitsHere(qs, g.w, zm) then
                        seenQ[qid] = true
                        t = t + .2
                        local pl = Parts(qs, g.w)
                        local parts = {}
                        for _, p in ipairs(pl) do parts[#parts + 1] = {nodes = p.nodes, done = false} end
                        log[qid] = {parts = parts, acceptL = L, mid = stats.rounds}
                        logN = logN + 1
                        -- gleich in dieser Runde erledigen (Ziele und Abgabe liegen hier, FitsHere)
                        local rest = {}
                        for k, p in ipairs(pl) do
                            local w, nr = NearestOf(p.nodes, g.w, zm)
                            rest[#rest + 1] = {kind = "o", id = qid, w = w, nr = nr, part = #pl > 1 and k or nil, nodes = p.nodes}
                        end
                        local en, enr = NearestOf(qs.e[7], g.w, zm)
                        rest[#rest + 1] = {kind = "t", id = qid, w = en, nr = enr}
                        InsertRest(i, rest)
                        if g.nr == st.nr then tok = tok .. " a" .. qid
                        else
                            -- anderer NPC direkt daneben: eigener Schritt
                            midSteps[#midSteps + 1] = {"a" .. qid, n = g.nr, z = g.w[4], w = g.w}
                        end
                    end
                end
            end
            -- gleicher NPC/Ziel wie der Schritt davor: zusammenfassen
            if cur and cur.n == st.nr and not cur.p and not st.part and D(cur.w, st.w) < 30 then
                cur[1] = cur[1] .. " " .. tok
                -- Stufe des Schritts = Stufe bei der letzten Annahme darin (Spielregel Mindeststufe)
                if tok:find("a%d") then cur.l = math.max(cur.l or 0, L) end
            else
                cur = Emit({tok, n = st.nr, z = st.w[4], w = st.w, l = L})
                if st.part then
                    -- gewaehlter Knoten zuerst (Pruefung und Spiel nehmen p[1] als Ort des Teils)
                    cur.p = {st.nr}
                    for _, nr in ipairs(st.nodes) do if nr ~= st.nr then cur.p[#cur.p + 1] = nr end end
                end
                if first then cur.r = stats.rounds first = false end
            end
            for _, ms in ipairs(midSteps) do
                ms.l = L
                cur = Emit(ms)
            end
            midSteps = {}
            if bindAt and bindAt.st == st then
                home = {bindAt.w[1], bindAt.w[2], bindAt.w[3], zm}
                Emit({k = "bind", inn = bindAt.inn[1], z = zm, w = home})
                cur = nil
            end
            for _, x in ipairs(fpAt[st] or {}) do
                known[x.fm[1]] = true
                net = Net()
                local zz = Z[x.fm[7] or 0]
                local r = Emit({k = "fp", fp = x.fm[1], z = x.fm[7], w = x.w})
                if zz then
                    r.m = x.fm[7]
                    r.x = math.floor((zz.maxY - x.fm[4]) / (zz.maxY - zz.minY) * 1000 + .5)
                    r.y = math.floor((zz.maxX - x.fm[3]) / (zz.maxX - zz.minX) * 1000 + .5)
                end
                cur = nil
            end
        end
        if verbose then
            local nn, nl = 0, 0
            for _, q in ipairs(quests) do if q.new then nn = nn + 1 else nl = nl + 1 end end
            print(("Runde %3d %-18s St %2d->%2d  %3d neu %2d aus Log  %3d Halte  t=%6.0f min  Log %d"):format(stats.rounds, ZName(zm), L0, L, nn, nl, #seq, t, logN))
        end
    end
    -- Dungeon-Laeufe: Quests im Log, Stufe passt
    local function Dungeons()
        if NODUNGEON then return end
        local byKey = {}
        for id, lg in pairs(log) do
            local s = static[id]
            if s.dungeon and not lg.dunDone then byKey[s.dungeon] = byKey[s.dungeon] or {} table.insert(byKey[s.dungeon], id) end
        end
        local keys = {}
        for k in pairs(byKey) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local c, ent = CAT[key], DG.EntranceData[key]
            if c and ent and L >= math.min(c.min + DUN_FROM, c.max - 2) and L <= c.max - 2 then
                local w = World(ent[1], ent[2], ent[3])
                if w then
                    t = t + Trip(pos, w)
                    pos = w
                    local ids = byKey[key]
                    table.sort(ids)
                    local toks = {}
                    for _, id in ipairs(ids) do toks[#toks + 1] = "o" .. id log[id].dunDone = true end
                    t = t + DUN_MIN
                    AddXP(DUN_MIN * P.GrindEPM(L) * (P.GRIND_REAL or .7))
                    stats.dungeons = stats.dungeons + 1
                    Emit({table.concat(toks, " "), k = "dungeon", key = key, z = ent[1], w = w, min = DUN_MIN, m = ent[1],
                        x = math.floor(ent[2] * 1000 + .5), y = math.floor(ent[3] * 1000 + .5)})
                    if verbose then print(("  DUNGEON %s St %d (%s)"):format(key, L, table.concat(toks, " "))) end
                end
            end
        end
    end
    -- Sammelrunde: in keinem Gebiet gibt es noch eine Runde (Stufenluecke, v. a. Allianz 48-51). Statt lange zu
    -- hauen: die einzeln liegenden Quests mehrerer Gebiete per Flugmeister einsammeln. Nur Quests mit Geber nah an
    -- einem bekannten Flugpunkt und Zielen/Abgabe nah beieinander (kein langer Fussweg fuer eine Aktion); jede Quest
    -- muss mehr EP bringen, als man in der Zeit ihres Wegs mit Hauen bekaeme.
    local function NearFP(w)
        local bd = Dist(w, pos) * (w[1] == pos[1] and 1 or 1e6)
        for _, fl in ipairs(net.flights) do if fl[1] == w[1] then local d = Dist(fl, w) if d < bd then bd = d end end end
        return bd
    end
    local function TravelW(a, b) return (P.Travel(a, b, net)) end
    local function SeqTime(seq)
        local m, prev = 0, pos
        for _, st in ipairs(seq) do m = m + TravelW(prev, st.w) + (st.kind == "o" and 0 or .2) prev = st.w end
        return m
    end
    -- je Kontinent getrennt (Anreise per Schiff zaehlt mit), der bessere gewinnt
    local function SammelOn(cont, av)
        local cref = pos[1] == cont and pos or nil
        if not cref then for _, fl in ipairs(net.flights) do if fl[1] == cont then cref = fl break end end end
        if not cref then return nil end
        local quests = {}
        local room = LOG_MAX - logN
        for _, s in ipairs(av) do
            if room <= 0 then break end
            if not s.dungeon and not TIMED[s.id] then
                local g, gd
                for _, gv in ipairs(s.givers) do
                    if gv.w[1] == cont then
                        local d = NearFP(gv.w)
                        if not gd or d < gd then g, gd = gv, d end
                    end
                end
                if g and gd <= SAMMEL_FP_YD then
                    local q = {id = s.id, s = s, new = true, stops = {{kind = "a", id = s.id, w = g.w, nr = g.nr}}}
                    local parts = Parts(s, g.w)
                    local ok = true
                    for k, p in ipairs(parts) do
                        local w, nr = NearestOf(p.nodes, g.w)
                        if not w or D(w, g.w) > OBJ_NEAR_YD * 2 then ok = false break end
                        q.stops[#q.stops + 1] = {kind = "o", id = s.id, w = w, nr = nr, part = #parts > 1 and k or nil, nodes = p.nodes}
                    end
                    if ok then
                        local ref = q.stops[#q.stops].w
                        local en, enr = NearestOf(s.e[7], ref)
                        if en and (D(en, ref) <= SAMMEL_FP_YD or NearFP(en) <= SAMMEL_FP_YD) then
                            q.stops[#q.stops + 1] = {kind = "t", id = s.id, w = en, nr = enr}
                            q.parts = parts
                            quests[#quests + 1] = q
                            room = room - 1
                        end
                    end
                end
            end
        end
        -- Quests im Log (liegen gelassen): Rest mitnehmen, wenn er auf diesem Kontinent nah an Flugpunkten liegt
        local logIDs = {}
        for id in pairs(log) do logIDs[#logIDs + 1] = id end
        table.sort(logIDs)
        for _, id in ipairs(logIDs) do
            local lg, s = log[id], static[id]
            if not (s.dungeon and not lg.dunDone) then
                local q = {id = id, s = s, new = false, stops = {}}
                local ok, ref = true, cref
                for k, p in ipairs(lg.parts) do
                    if not p.done then
                        local w, nr = NearestOf(p.nodes, cref)
                        if not w or NearFP(w) > OBJ_NEAR_YD * 2 then ok = false break end
                        q.stops[#q.stops + 1] = {kind = "o", id = id, w = w, nr = nr, part = #lg.parts > 1 and k or nil, nodes = p.nodes}
                        ref = w
                    end
                end
                local en, enr = NearestOf(s.e[7], ref)
                if ok and en and (NearFP(en) <= SAMMEL_FP_YD or (ref ~= cref and D(en, ref) <= SAMMEL_FP_YD)) then
                    q.stops[#q.stops + 1] = {kind = "t", id = id, w = en, nr = enr}
                    quests[#quests + 1] = q
                end
            end
        end
        if os.getenv("SAMDBG") then print(("    sammel St %d Kontinent %d: Kandidaten %d (verfuegbar %d)"):format(L, cont, #quests, #av)) end
        -- Quests, deren Weg mehr kostet, als sie bringen, nacheinander raus (die schlechteste zuerst)
        local rate = math.max(1, P.GrindEPM(L) * (P.GRIND_REAL or .7))
        local seq
        for _ = 1, 60 do
            if #quests < SAMMEL_MIN then return nil end
            seq = Tour(quests, TravelW)
            local total = SeqTime(seq)
            local worst, wi
            for qi, q in ipairs(quests) do
                local without = {}
                for _, st in ipairs(seq) do if st.id ~= q.id then without[#without + 1] = st end end
                local saved = total - SeqTime(without)
                local val = P.QuestXP(q.s.e[11] or 0, q.s.e[1], L)
                local ratio = val / math.max(.1, saved * rate)
                if ratio < SAMMEL_GAIN and (not worst or ratio < worst) then worst, wi = ratio, qi end
            end
            if not wi then break end
            if os.getenv("SAMDBG") then print(("    sammel St %d raus q%d (%.2f) von %d, %.0f min"):format(L, quests[wi].id, worst, #quests, total)) end
            table.remove(quests, wi)
        end
        if os.getenv("SAMDBG") then print(("    sammel St %d: %d Quests, %d Halte"):format(L, #quests, #seq)) end
        Refine(seq, nil)
        local dropped = FixEinzel(seq)
        Refine(seq, nil)
        for _, id in ipairs(FixEinzel(seq)) do dropped[#dropped + 1] = id end
        if os.getenv("SAMDBG") and #dropped > 0 then local t2 = {} for _, x in ipairs(dropped) do t2[#t2 + 1] = "q" .. x end print("    sammel EINZEL raus " .. table.concat(t2, " ")) end
        local left = {}
        for _, st in ipairs(seq) do left[st.id] = true end
        local n = 0
        for _ in pairs(left) do n = n + 1 end
        if n < SAMMEL_MIN then return nil end
        local keep = {}
        local gain = 0
        for _, q in ipairs(quests) do
            if left[q.id] then
                keep[#keep + 1] = q
                for _, st in ipairs(seq) do if st.id == q.id and st.kind == "t" then gain = gain + P.QuestXP(q.s.e[11] or 0, q.s.e[1], L) end end
            end
        end
        -- ganze Runde (mit Anreise) muss sich auch lohnen
        local mins = SeqTime(seq)
        local ratio = gain / math.max(.1, mins * rate)
        if os.getenv("SAMDBG") then print(("    sammel St %d Kontinent %d: %d Quests, %.0f min, Wert %.2f"):format(L, cont, #keep, mins, ratio)) end
        if ratio < SAMMEL_GAIN then return nil end
        return {quests = keep, seq = seq, perMin = gain / math.max(.1, mins)}
    end
    local function Sammel()
        aheadNow, greyNow = AHEAD_GAP, GREY_GAP
        local av = {}
        for _, s in pairs(static) do if Available(s) then av[#av + 1] = s end end
        aheadNow, greyNow = AHEAD, GREY
        table.sort(av, function(a, b) return a.id < b.id end)
        local conts, seen = {}, {}
        for _, fl in ipairs(net.flights) do if not seen[fl[1]] then seen[fl[1]] = true conts[#conts + 1] = fl[1] end end
        if not seen[pos[1]] then conts[#conts + 1] = pos[1] end
        table.sort(conts)
        local best
        for _, c in ipairs(conts) do
            local r = SammelOn(c, av)
            if r and (not best or r.perMin > best.perMin) then best = r end
        end
        return best
    end
    -- Gebiet waehlen
    local guard, emptyAt = 0, {}
    while (L < 60 or over < OVER_XP * XP_NEED[59]) and guard < 2000 do
        guard = guard + 1
        local avail, cand, best
        local function Choose()
        avail = {}
        cand = {}
        best = nil
        for id, s in pairs(static) do if Available(s) then avail[#avail + 1] = s end end
        table.sort(avail, function(a, b) return a.id < b.id end)
        -- Gebiete mit neuen Quests oder Log-Halten
        local zones = {}
        for _, s in ipairs(avail) do for _, g in ipairs(s.givers) do if g.w[1] == pos[1] or true then zones[g.w[4]] = true end end end
        for id, lg in pairs(log) do
            for _, p in ipairs(lg.parts) do if not p.done then for _, nr in ipairs(p.nodes) do for _, w in ipairs(Pts(nr)) do zones[w[4]] = true end end end end
            for _, nr in ipairs(static[id].e[7]) do for _, w in ipairs(Pts(nr)) do zones[w[4]] = true end end
        end
        local list = {}
        for zm in pairs(zones) do list[#list + 1] = zm end
        table.sort(list)
        for _, zm in ipairs(list) do
            local quests = emptyAt[zm] == L and {} or Round(zm, avail)
            local n, gain, work = 0, 0, 0
            local first
            for _, q in ipairs(quests) do
                n = n + 1
                for _, st in ipairs(q.stops) do
                    if not first or D(st.w, pos) < D(first, pos) then first = st.w end
                    if st.kind == "t" then gain = gain + P.QuestXP(q.s.e[11] or 0, q.s.e[1], L) end
                    if st.kind == "o" then work = work + (q.s.work or 0) end
                end
            end
            if n > 0 and first then
                local travel = (zm == pos[4] or D(first, pos) < 600) and 0 or Trip(pos, first)
                local mins = travel + n * 2 + work * P.KILL_SEC / 60
                local score = (gain + work * P.MobXP(L, L)) / math.max(1, mins)
                cand[#cand + 1] = {zm = zm, quests = quests, n = n, score = score, travel = travel}
            end
        end
        -- aktuelles Gebiet zuerst, solange es eine Runde hergibt; sonst die beste Runde mit MIN_ROUND Quests
        for _, c in ipairs(cand) do
            if c.zm == lastZone and c.n >= MIN_ROUND then best = c end
        end
        if not best then
            for _, c in ipairs(cand) do
                if c.n >= MIN_ROUND and (not best or c.score > best.score) then best = c end
            end
        end
        -- Rueckfall statt Hauen: Runde mit 2 Quests (keine einzelne Quest), die beste
        if not best then
            for _, c in ipairs(cand) do
                if c.n >= 2 and (not best or c.score > best.score) then best = c end
            end
        end
        -- Rest im aktuellen Gebiet (weniger als MIN_ROUND), wenn er direkt hier ist
        if not best then
            for _, c in ipairs(cand) do
                if c.zm == lastZone and c.travel == 0 then best = c end
            end
        end
        end
        Choose()
        if not best then
            -- Stufenluecke: statt Hauen Quests bis AHEAD_GAP ueber der eigenen Stufe
            aheadNow = AHEAD_GAP
            Choose()
            if not best then
                -- und auch aeltere Quests (wenig EP, aber besser als nur Monster hauen)
                greyNow = GREY_GAP
                Choose()
            end
            aheadNow, greyNow = AHEAD, GREY
        end
        local sam = not best and Sammel() or nil
        if sam then
            Run(nil, sam.quests, sam.seq, {})
            stats.sammel = (stats.sammel or 0) + 1
            if verbose then
                local zs, seen = {}, {}
                for _, st in ipairs(sam.seq) do local zn = ZName(st.w[4]) if not seen[zn] then seen[zn] = true zs[#zs + 1] = zn end end
                print(("  SAMMELRUNDE St %d: %d Quests, %d Halte (%s)"):format(L, #sam.quests, #sam.seq, table.concat(zs, " ")))
            end
            lastZone = pos[4]
            Dungeons()
        elseif best then
            local seq = Tour(best.quests)
            local drop = FixTimed(seq)
            if next(drop) then
                for id in pairs(drop) do banned[id] = true end
                for i = #seq, 1, -1 do if drop[seq[i].id] and seq[i].kind == "a" then table.remove(seq, i) end end
                for i = #seq, 1, -1 do if drop[seq[i].id] and not log[seq[i].id] then table.remove(seq, i) end end
            end
            Refine(seq, best.zm)
            FixEinzel(seq)
            Refine(seq, best.zm)
            FixEinzel(seq)
            if #seq > 0 then
                local availStart = {}
                for _, a in ipairs(avail) do availStart[a.id] = true end
                Run(best.zm, best.quests, seq, availStart)
                lastZone = best.zm
            else
                -- Runde fiel ganz weg (Einzelwege): dieses Gebiet bis zur naechsten Stufe nicht mehr anbieten
                emptyAt[best.zm] = L
            end
            Dungeons()
        else
            -- nichts geplant: bis zur naechsten Stufe Monster hauen (soll gegen 0 gehen)
            if L >= 60 then break end
            local need = XP_NEED[L] - xp
            local rate = math.max(1, P.GrindEPM(L) * (P.GRIND_REAL or .7))
            local m = math.floor(need / rate + .5)
            stats.grind, stats.grindMin = stats.grind + 1, stats.grindMin + m
            Emit({k = "grind", z = pos[4], to = L + 1, min = m})
            if verbose then
                local cl = {}
                for _, c in ipairs(cand) do cl[#cl + 1] = ZName(c.zm) .. "=" .. c.n end
                print(("  HAUEN St %d -> %d: %d min (%s) – Gebiete: %s"):format(L, L + 1, m, ZName(pos[4]), table.concat(cl, " ")))
                local why = {}
                for id, st in pairs(static) do
                    local e = st.e
                    if e[1] <= L + AHEAD and e[1] >= L - GREY and (e[2] or 0) <= L and not done[id] then
                        local w = banned[id] and "gesperrt" or log[id] and "im Log" or not PreOK(e) and "Vorquest" or noCarry[id] and "nicht liegen lassen" or "verfuegbar"
                        why[w] = (why[w] or 0) + 1
                        if os.getenv("GAPDBG") and (w == "verfuegbar" or w == "nicht liegen lassen") then
                            local g = st.givers[1].w
                            local oz = {}
                            for _, p in ipairs(Parts(st, g)) do oz[#oz + 1] = ZName(p.w[4]) end
                            print(("      %s q%d St%d %s | Geber %s (%.0f,%.0f) | Ziele %s | Abgabe %s"):format(w, id, e[1], Name(id),
                                ZName(g[4]), g[2], g[3], table.concat(oz, ","), ZName(st.enders[1].w[4])))
                        end
                    end
                end
                local wl = {}
                for k, v in pairs(why) do wl[#wl + 1] = k .. "=" .. v end
                table.sort(wl)
                print("    Quests in der Stufe: " .. table.concat(wl, " "))
            end
            t = t + m
            AddXP(need)
            Dungeons()
        end
    end
    stats.t = t
    stats.level = L
    stats.open = {}
    -- offen am Ende: erst ab Stufe 59 angenommen -> nur am Schluss aus der Route nehmen (stoert davor nichts);
    -- frueher angenommen -> beim naechsten Durchgang nicht annehmen (bzw. nicht mitnehmen)
    stats.tail = {}
    for id, lg in pairs(log) do
        if lg.acceptL >= 59 then stats.tail[#stats.tail + 1] = id
        elseif lg.mid then stats.noMid[#stats.noMid + 1] = id
        elseif lg.carry and not static[id].dungeon then stats.noCarry[#stats.noCarry + 1] = id
        else stats.open[#stats.open + 1] = id end
    end
    return route, stats
end

-- Nachschliff: Annahmen, die schon beim frueheren Besuch am selben NPC gingen, dorthin vorziehen (harte Pruefung
-- "Bereich doppelt ohne Grund"); leer gewordene Schritte fallen weg
local function Polish(route)
    local moved = 0
    for pass = 1, 3 do
        local turnAt, accAt = {}, {}
        for i, r in ipairs(route) do
            if type(r[1]) == "string" then
                for k, id in r[1]:gmatch("(%a)(%d+)") do
                    id = tonumber(id)
                    if k == "t" then turnAt[id] = i end
                    if k == "a" then accAt[id] = i end
                end
            end
        end
        -- offene Quests je Schritt (Log)
        local logAt, open = {}, 0
        for i, r in ipairs(route) do
            for k in (type(r[1]) == "string" and r[1] or ""):gmatch("(%a)%d+") do
                if k == "a" then open = open + 1 elseif k == "t" then open = open - 1 end
            end
            logAt[i] = open
        end
        local function Done(p, i) return turnAt[p] and turnAt[p] <= i end   -- im selben Schritt: Annahme steht hinten
        local function Could(id, i)
            local e = Q.q[id]
            local lv = route[i].l or 0
            if not e or (e[2] or 0) > lv or e[1] > lv + AHEAD or TIMED[id] then return false end
            if type(e[9]) == "table" then for _, p in ipairs(e[9]) do if not Done(p, i) then return false end end end
            if type(e[5]) == "table" and #e[5] > 0 then
                local ok = false
                for _, p in ipairs(e[5]) do if Done(p, i) then ok = true end end
                if not ok then return false end
            end
            if type(e[10]) == "table" then for _, p in ipairs(e[10]) do if accAt[p] and accAt[p] < i then return false end end end
            return true
        end
        local changed = false
        for j = 2, #route do
            local r = route[j]
            if type(r[1]) == "string" and r.n and not r.k then
                local keep = {}
                for tok in r[1]:gmatch("%S+") do
                    local k, id = tok:match("^(%a)(%d+)$")
                    id = tonumber(id)
                    local target
                    if k == "a" then
                        -- frueherer Besuch am selben NPC (davor ein anderer Ort), Log hat Platz bis hierher
                        for i = j - 1, math.max(1, j - 300), -1 do
                            local ri = route[i]
                            if ri.n == r.n and type(ri[1]) == "string" and not ri.k and (i == 1 or route[i + 1].n ~= r.n or true) then
                                if Could(id, i) then
                                    local room = true
                                    for x = i, j - 1 do if logAt[x] >= LOG_MAX then room = false break end end
                                    if room then target = i end
                                end
                                break
                            end
                        end
                    end
                    if target and target < j - 1 then
                        route[target][1] = route[target][1] .. " " .. tok
                        for x = target, j - 1 do logAt[x] = logAt[x] + 1 end
                        accAt[id] = target
                        moved, changed = moved + 1, true
                    else keep[#keep + 1] = tok end
                end
                r[1] = #keep > 0 and table.concat(keep, " ") or nil
            end
        end
        -- leere Schritte weg (Rundenbeginn wandert zum naechsten Schritt)
        local out = {}
        local carryR
        for _, r in ipairs(route) do
            if r[1] == nil and not r.k then carryR = carryR or r.r
            else
                if carryR and not r.r then r.r = carryR end
                carryR = nil
                out[#out + 1] = r
            end
        end
        for i = #route, 1, -1 do route[i] = nil end
        for i, r in ipairs(out) do route[i] = r end
        if not changed then break end
    end
    return moved
end
-- Route als Lua-Text (Format wie src/ONE_Leveling/Routes.lua)
local function Write(file, route, key)
    local fh = assert(io.open(file, "w"))
    if key then fh:write("GuildTripQuestRoutes = GuildTripQuestRoutes or {}\nGuildTripQuestRoutes[\"", key, "\"] = {\n") else fh:write("return {\n") end
    for _, r in ipairs(route) do
        local parts = {}
        if r[1] then parts[#parts + 1] = ("%q"):format(r[1]) end
        for _, k in ipairs({"k", "key", "n", "l", "z", "r", "inn", "fp", "to", "min", "m", "x", "y"}) do
            if r[k] ~= nil then parts[#parts + 1] = k .. "=" .. (type(r[k]) == "string" and ("%q"):format(r[k]) or tostring(r[k])) end
        end
        if r.p then parts[#parts + 1] = "p={" .. table.concat(r.p, ",") .. "}" end
        fh:write("{", table.concat(parts, ","), "},\n")
    end
    fh:write("}\n")
    fh:close()
end
-- harte Pruefung (scripts/check_route_areas.lua) auf dieser einen Route: Quests mit EINZEL/ZEIT
local KEY = RMASK .. ":" .. CMASK
local ABST_MAX, OHNE_MAX = 8, 17   -- etwas unter den Grenzen der Pruefung (10, 20)
local function HardCheck(route)
    local tmp = outFile .. ".pruef.lua"
    Write(tmp, route, KEY)
    local ph = assert(io.popen(("lua5.1 scripts/check_route_areas.lua %q %q -v %s 2>&1"):format(spf, tmp, KEY)))
    local bad = {}
    local abst, ohne, nAbst, nOhne = {}, {}, 0, 0
    local function Ids(toks, into) for id in (toks or ""):gmatch("%a(%d+)") do into[#into + 1] = tonumber(id) end end
    for line in ph:lines() do
        local tok = line:match("^  EINZEL Schritt %d+ (%S+):")
        if tok then bad[#bad + 1] = tonumber(tok:match("^%a(%d+)")) end
        local zq = line:match("^  ZEIT Schritt %d+ q(%d+):")
        if zq then bad[#bad + 1] = tonumber(zq) end
        local rq = line:match("^  REGEL Schritt %d+ %a(%d+)")
        if rq then bad[#bad + 1] = tonumber(rq) io.stderr:write(line, "\n") end
        if line:match("^  OHNEABG") then io.stderr:write(line, "\n") end
        local at = line:match("^  ABST Schritte %d+%-%d+ %(([^)]*)%)")
        if at then abst[#abst + 1] = at end
        local dt = line:match("^  DOPP Schritt %d+ %(([^,]*), St %d+%).*OHNE GRUND")
        if dt then ohne[#ohne + 1] = dt end
        local a, o = line:match("ABST +(%d+) +DOPP +%d+ %(ohne Grund +(%d+)%)")
        if a then nAbst, nOhne = tonumber(a), tonumber(o) end
    end
    ph:close()
    -- ueber den Grenzen der Pruefung (ABST 10, ohne Grund 20): die ueberzaehligen (frueheste zuerst) weglassen
    for k = 1, math.max(0, nAbst - ABST_MAX) do Ids(abst[k], bad) end
    for k = 1, math.max(0, nOhne - OHNE_MAX) do Ids(ohne[k], bad) end
    os.remove(tmp)
    return bad
end
-- Durchgaenge: was offen bleibt, zu lange im Log liegt oder die harte Pruefung bricht, kommt beim naechsten Mal
-- nicht in die Route
local banned, noMid, noCarry = {}, {}, {}
local route, stats
for pass = 1, 30 do
    route, stats = Build(banned, noMid, noCarry, pass)
    stats.polished = Polish(route)
    local soft = #stats.open + #stats.late + #stats.noMid + #stats.noCarry
    stats.hard = HardCheck(route)
    if verbose or true then
        io.stderr:write(("Durchgang %d: %d Quests, %d Runden, St %d, %.0f min, Hauen %d (%d min), Dungeons %d, offen %d, zu lange im Log %d, Pruefung %d, nicht mitnehmen %d, nicht liegen lassen %d\n"):format(pass,
            stats.quests, stats.rounds, stats.level, stats.t, stats.grind, stats.grindMin, stats.dungeons, #stats.open, #stats.late, #stats.hard, #stats.noMid, #stats.noCarry))
    end
    if soft + #stats.hard == 0 or pass == 30 then break end
    for _, id in ipairs(stats.noCarry) do noCarry[id] = true end
    for _, id in ipairs(stats.noMid) do noMid[id] = true end
    for _, id in ipairs(stats.open) do banned[id] = true end
    for _, id in ipairs(stats.late) do banned[id] = true end
    for _, id in ipairs(stats.hard) do banned[id] = true end
end
-- Quests aus der Route nehmen, samt Folgequests, deren Vorquest dann fehlt (Spielregeln bleiben heil)
local function RemoveQuests(route, set)
    local removed = 0
    while next(set) do
        for i = #route, 1, -1 do
            local r = route[i]
            if type(r[1]) == "string" then
                local keep = {}
                for tok in r[1]:gmatch("%S+") do
                    local id = tonumber(tok:match("^%a(%d+)"))
                    if set[id] then removed = removed + 1 else keep[#keep + 1] = tok end
                end
                if #keep == 0 then
                    if r.r and route[i + 1] and not route[i + 1].r then route[i + 1].r = r.r end
                    table.remove(route, i)
                else r[1] = table.concat(keep, " ") end
            end
        end
        -- Folgequests pruefen
        set = {}
        local turnAt = {}
        for i, r in ipairs(route) do
            for k, id in (type(r[1]) == "string" and r[1] or ""):gmatch("(%a)(%d+)") do
                id = tonumber(id)
                if k == "t" then turnAt[id] = i end
            end
        end
        for i, r in ipairs(route) do
            for k, id in (type(r[1]) == "string" and r[1] or ""):gmatch("(%a)(%d+)") do
                id = tonumber(id)
                local e = Q.q[id]
                if k == "a" and e then
                    local ok = true
                    -- Abgabe der Vorquest im selben Schritt davor zaehlt (Annahme steht dort hinten)
                    if type(e[9]) == "table" then for _, p in ipairs(e[9]) do if not (turnAt[p] and turnAt[p] <= i) then ok = false end end end
                    if type(e[5]) == "table" and #e[5] > 0 then
                        local any = false
                        for _, p in ipairs(e[5]) do if turnAt[p] and turnAt[p] <= i then any = true end end
                        if not any then ok = false end
                    end
                    if not ok then set[id] = true end
                end
            end
        end
    end
    return removed
end
-- Reste (letzter Durchgang): angenommen, aber nie abgegeben -> aus der Route; danach harte Pruefung bis sauber
do
    local open = {}
    for _, list in ipairs({stats.open, stats.tail, stats.noMid, stats.noCarry, stats.hard or {}}) do
        for _, id in ipairs(list) do open[id] = true end
    end
    RemoveQuests(route, open)
    Polish(route)
    for round = 1, 6 do
        local bad = HardCheck(route)
        if #bad == 0 then break end
        local set = {}
        for _, id in ipairs(bad) do set[id] = true end
        RemoveQuests(route, set)
        io.stderr:write(("Nacharbeit %d: %d Quests aus der Route (harte Pruefung)\n"):format(round, #bad))
    end
end
Write(outFile, route)
local final = 0
for _, r in ipairs(route) do for k in (type(r[1]) == "string" and r[1] or ""):gmatch("(%a)%d+") do if k == "t" then final = final + 1 end end end
stats.quests = final
print(("ERGEBNIS %d Schritte, %d Quests, %d Runden, St %d, %.0f min, Hauen %d (%d min), Dungeons %d, Fluege %d, Sammelrunden %d, bis 60 %.0f min"):format(#route, stats.quests,
    stats.rounds, stats.level, stats.t, stats.grind, stats.grindMin, stats.dungeons, stats.flights, stats.sammel or 0, stats.t60 or 0))
